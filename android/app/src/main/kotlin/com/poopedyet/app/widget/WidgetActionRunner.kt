package com.poopedyet.app.widget

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * 后台执行小组件动作：临时拉一个**没有界面**的 FlutterEngine，
 * 跑 `widgetActionMain` 入口（见 `lib/src/widget/widget_action_entry.dart`），
 * 用它复用主 App 完全相同的 drift 数据访问代码写库，写完刷新桌面并销毁引擎。
 *
 * ## 为什么不图省事让原生直接写 SQLite
 *
 * 那样要复刻一整套业务契约：drift 的 DateTime 编码、`ux_active_record`
 * 唯一索引（一个人同时只能挂一条进行中记录）、外键约束，以及各种边界
 * （重复开屙、记录已被别处结束……）。在 Kotlin 里复刻一份，迟早会在某次
 * schema 变更后**悄悄写坏用户数据**。这个 App 的全部价值就是那些记录。
 *
 * ## ⚠ 为什么整个启动过程都必须在主线程（v1.1.2 修）
 *
 * 这里曾经把「加载 native 库 + 初始化 Dart 快照」放在后台线程，
 * 只在最后 `post` 一下去创建引擎。结果是：
 *
 * ```
 * App 进程还活着  → FlutterLoader.settings != null / initialized == true
 *                  → 两个初始化方法都提前 return，侥幸不报错，动作正常
 * App 进程被回收  → initialized == false → 走到线程断言
 *                  → IllegalStateException("ensureInitializationComplete
 *                     must be called on the main thread")
 *                  → 被 catch 吞掉 → 动作直接丢弃
 * ```
 *
 * 表现就是「App 没在后台时，点小组件的开屙/完成毫无反应」——
 * 而 App 只要还活着就一切正常，所以极难复现。
 *
 * Flutter 引擎的 `FlutterLoader.startInitialization` / `ensureInitializationComplete`
 * 都带 `@UiThread` 断言（见 engine 源码），`FlutterJNI` 的初始化同样只能在主线程。
 * 既然 `FlutterActivity` 内部也是这么做的，这里就照办：**全部放主线程**。
 *
 * ## 引擎生命周期
 *
 * 用完即毁：小组件点击是低频操作，没必要为它常驻十几 MB 内存。
 * 代价是每次约 0.5~1.5s 的准备时间。期间连点会排队，一个接一个执行。
 */
object WidgetActionRunner {

    private const val TAG = "WidgetAction"
    private const val CHANNEL = "com.poopedyet.app/widget_action"
    private const val ENTRYPOINT = "widgetActionMain"

    /**
     * 单次动作的兜底超时。
     *
     * Dart 侧无论成败都会回报 `finished`，但万一引擎起来了、入口却没解析成功
     * （比如 AOT 瘦身把 `widgetActionMain` 摇掉），就会一直没人回报，
     * 而 receiver 那边还攥着 `goAsync()` 的 PendingResult 等我们 ——
     * 拖过系统给的广播时限就是一次 ANR。这里主动收尾，宁可丢一次动作也不卡用户。
     */
    private const val WATCHDOG_MS = 8_000L

    private val lock = Any()
    private val queue = ArrayDeque<QueuedAction>()
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var engine: FlutterEngine? = null

    /** 是否已有一轮「启动引擎 → 执行 → 销毁」在进行中。 */
    private var running = false

    /**
     * 轮次令牌。
     *
     * 用来丢弃「迟到」的回调：超时兜底先收尾、Dart 随后才回报 `finished`
     * 是完全可能的，没有这个令牌的话，那次迟到回报会把**下一个**动作
     * 当成已完成而悄悄吞掉。
     */
    private var roundToken = 0

    private var watchdog: Runnable? = null

    /** 队列里的一格：动作本身 + 执行完毕后要通知的回调（receiver 用它结束 goAsync）。 */
    private class QueuedAction(
        val action: PendingWidgetAction,
        val onDone: (() -> Unit)?,
    )

    /**
     * 入队一个动作；如果当前没有引擎在跑，顺手拉起一个。
     *
     * [onDone] 会在这一格动作**确定收尾**（成功、失败或超时）后于主线程回调一次，
     * [WidgetActionReceiver] 用它来 `PendingResult.finish()`。
     */
    fun enqueue(context: Context, action: PendingWidgetAction, onDone: (() -> Unit)? = null) {
        val appContext = context.applicationContext
        val shouldBoot: Boolean
        synchronized(lock) {
            queue.addLast(QueuedAction(action, onDone))
            shouldBoot = !running
            if (shouldBoot) running = true
        }
        if (!shouldBoot) return
        mainHandler.post { bootEngine(appContext) }
    }

    /**
     * 起引擎。**调用方必须已经在主线程**（目前只有 `mainHandler.post` 一条路径）。
     */
    private fun bootEngine(context: Context) {
        val token = ++roundToken
        try {
            // 顺序不能颠倒：先 startInitialization 拿到 ApplicationInfo，
            // 再 ensureInitializationComplete 才能真正把 native 库与 Dart 快照挂上去。
            // 两者都是幂等的，App 自己已经打开过时这里等于空转。
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(context)
            loader.ensureInitializationComplete(context, null)
            val bundlePath = loader.findAppBundlePath()

            val flutterEngine = FlutterEngine(context)
            engine = flutterEngine
            registerChannels(context, flutterEngine, token)
            flutterEngine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(bundlePath, ENTRYPOINT),
            )

            armWatchdog(context, token)
        } catch (e: Exception) {
            Log.e(TAG, "后台引擎启动失败", e)
            finish(context, token)
        }
    }

    private fun registerChannels(context: Context, flutterEngine: FlutterEngine, token: Int) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Dart 侧主动来取要干什么（拉取式握手，避开时序问题）
                    "getPendingAction" -> result.success(nextAction())
                    "finished" -> {
                        result.success(true)
                        finish(context, token)
                    }
                    else -> result.notImplemented()
                }
            }

        // Dart 侧写完库会把新快照推回主通道，这里必须接得住
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WidgetChannelHandler.CHANNEL)
            .setMethodCallHandler { call, result ->
                if (!WidgetChannelHandler.handle(context, call, result)) {
                    result.notImplemented()
                }
            }
    }

    private fun nextAction(): Map<String, Any?>? {
        val action = synchronized(lock) { queue.firstOrNull() } ?: return null
        return when (val pending = action.action) {
            is PendingWidgetAction.Start -> mapOf(
                "action" to "start",
                "pooperId" to pending.pooperId,
            )
            is PendingWidgetAction.Finish -> mapOf(
                "action" to "finish",
                "recordId" to pending.recordId,
            )
        }
    }

    /** 一个动作执行完毕（或超时）：出队、销毁引擎、刷新桌面、通知接收端；还有排队就再来一轮。 */
    private fun finish(context: Context, token: Int) {
        if (token != roundToken) {
            // 上一轮的迟到回调，本轮已经不由它负责了。
            Log.i(TAG, "忽略过期的动作回调 (token=$token, current=$roundToken)")
            return
        }
        cancelWatchdog()

        val onDone: (() -> Unit)?
        val hasMore: Boolean
        synchronized(lock) {
            onDone = queue.removeFirstOrNull()?.onDone
            hasMore = queue.isNotEmpty()
            if (!hasMore) running = false
        }

        // 先摘引用再排队销毁：
        //  · 摘引用必须在当下完成，否则后面 bootEngine 赋的新引擎会被这里的
        //    收尾逻辑（晚一个消息循环才跑）连带清掉；
        //  · destroy 本身排到下一个消息循环 —— 这条路径可能正处在
        //    MethodChannel 回调里，当帧析构引擎容易踩到引擎自己的线程约束。
        //    post 的先后顺序天然保证「先销毁旧引擎、再启新引擎」。
        val dying = engine
        engine = null
        if (dying != null) {
            mainHandler.post { runCatching { dying.destroy() } }
        }

        // 先放接收端走：冷启动场景下它攥着 goAsync 的 PendingResult，
        // 而系统的广播时限不会等我们把桌面刷完。
        runCatching { onDone?.invoke() }

        WidgetDataProvider.triggerUpdateAll(context)

        if (hasMore) {
            mainHandler.post { bootEngine(context) }
        }
    }

    private fun armWatchdog(context: Context, token: Int) {
        cancelWatchdog()
        val runnable = Runnable {
            watchdog = null
            Log.w(TAG, "后台动作超时未回报，强制收尾 (token=$token)")
            finish(context, token)
        }
        watchdog = runnable
        mainHandler.postDelayed(runnable, WATCHDOG_MS)
    }

    private fun cancelWatchdog() {
        watchdog?.let { mainHandler.removeCallbacks(it) }
        watchdog = null
    }
}
