package com.poopedyet.app.widget

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

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
 * ## 引擎生命周期
 *
 * 用完即毁：小组件点击是低频操作，没必要为它常驻十几 MB 内存。
 * 代价是每次约 0.5~1s 的准备时间，用户点完稍等一下就能看到组件变化。
 * 如果期间连点多次，动作会排队，一个接一个执行。
 */
object WidgetActionRunner {

    private const val TAG = "WidgetAction"
    private const val CHANNEL = "com.poopedyet.app/widget_action"
    private const val ENTRYPOINT = "widgetActionMain"

    private val lock = Any()
    private val queue = ArrayDeque<PendingWidgetAction>()

    /** 加载 native 库 + Dart VM 快照都很重，统一扔到后台线程。 */
    private val worker = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "widget-action").apply { isDaemon = true }
    }

    @Volatile
    private var engine: FlutterEngine? = null

    /** 是否已有一轮「启动引擎 → 执行 → 销毁」在进行中。 */
    @Volatile
    private var running = false

    /** 入队一个动作；如果当前没有引擎在跑，顺手拉起一个。 */
    fun enqueue(context: Context, action: PendingWidgetAction) {
        val appContext = context.applicationContext
        synchronized(lock) {
            queue.addLast(action)
            if (running) return
            running = true
        }
        worker.execute { bootEngine(appContext) }
    }

    private fun bootEngine(context: Context) {
        try {
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(context)
            loader.ensureInitializationComplete(context, null)
            val bundlePath = loader.findAppBundlePath()

            // 引擎的创建与入口执行都必须在主线程。
            Handler(Looper.getMainLooper()).post {
                try {
                    val flutterEngine = FlutterEngine(context)
                    engine = flutterEngine
                    registerChannels(context, flutterEngine)
                    flutterEngine.dartExecutor.executeDartEntrypoint(
                        DartExecutor.DartEntrypoint(bundlePath, ENTRYPOINT),
                    )
                } catch (e: Exception) {
                    Log.e(TAG, "后台引擎启动失败", e)
                    finish(context)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Flutter 运行时初始化失败", e)
            finish(context)
        }
    }

    private fun registerChannels(context: Context, flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Dart 侧主动来取要干什么（拉取式握手，避开时序问题）
                    "getPendingAction" -> result.success(nextAction())
                    "finished" -> {
                        result.success(true)
                        finish(context)
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
        return when (action) {
            is PendingWidgetAction.Start -> mapOf(
                "action" to "start",
                "pooperId" to action.pooperId,
            )
            is PendingWidgetAction.Finish -> mapOf(
                "action" to "finish",
                "recordId" to action.recordId,
            )
        }
    }

    /** 一个动作执行完毕：出队、销毁引擎、刷新桌面；还有排队就再来一轮。 */
    private fun finish(context: Context) {
        val hasMore: Boolean
        synchronized(lock) {
            queue.removeFirstOrNull()
            hasMore = queue.isNotEmpty()
            if (!hasMore) running = false
        }

        Handler(Looper.getMainLooper()).post {
            engine?.destroy()
            engine = null
        }

        WidgetDataProvider.triggerUpdateAll(context)

        if (hasMore) {
            worker.execute { bootEngine(context) }
        }
    }
}
