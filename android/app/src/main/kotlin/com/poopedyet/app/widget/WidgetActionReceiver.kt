package com.poopedyet.app.widget

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * 小组件上「现在开屙 / 完成打卡」按钮的接收端。
 *
 * 这两个动作**不需要用户进 App**：收到广播后转交给 [WidgetActionRunner]，
 * 由它拉一个没有界面的 FlutterEngine 直接写库。用户点完就留在桌面，
 * 组件自己会刷新成新状态。
 *
 * ## 为什么要 `goAsync()`（v1.1.2 修）
 *
 * App 进程不在时，这个进程是**被这条广播临时拉起来**的。`onReceive` 一返回，
 * 系统立刻把它降级成"随时可回收"的空进程，而后面还有「加载 native 库 →
 * 起 Dart VM → 写库 → 回推快照」将近一秒的活要干。低内存机型（尤其是国内
 * 定制 ROM）完全可能在此之前就把进程清掉，用户看到的就是「点了没反应」。
 *
 * 攥住 `PendingResult` 能让系统在这段时间里把我们当"正在处理广播"对待。
 * native 的初始化已经前移到主线程（见 [WidgetActionRunner] 里那段说明），
 * 所以这段保活窗口足够覆盖整个动作。
 */
class WidgetActionReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        Log.i(TAG, "收到小组件动作: ${intent.action}")

        val action = when (intent.action) {
            ACTION_START -> PendingWidgetAction.Start(
                intent.getStringExtra(EXTRA_POOPER_ID).orEmpty(),
            )

            ACTION_FINISH -> {
                val recordId = intent.getStringExtra(EXTRA_RECORD_ID).orEmpty()
                if (recordId.isEmpty()) {
                    // 没有记录 id 就无从结束；打一条日志，别静默地什么都不做。
                    Log.w(TAG, "完成动作缺少 recordId，已忽略")
                    return
                }
                PendingWidgetAction.Finish(recordId)
            }

            else -> return
        }

        val pendingResult = goAsync()
        var reported = false
        WidgetActionRunner.enqueue(context, action) {
            if (reported) return@enqueue
            reported = true
            runCatching { pendingResult.finish() }
        }
    }

    companion object {
        const val TAG = "WidgetAction"
        const val ACTION_START = "com.poopedyet.app.widget.ACTION_START"
        const val ACTION_FINISH = "com.poopedyet.app.widget.ACTION_FINISH"
        const val EXTRA_POOPER_ID = "pooperId"
        const val EXTRA_RECORD_ID = "recordId"
    }
}

/** 排队等后台引擎执行的小组件动作。 */
sealed interface PendingWidgetAction {
    data class Start(val pooperId: String) : PendingWidgetAction
    data class Finish(val recordId: String) : PendingWidgetAction
}
