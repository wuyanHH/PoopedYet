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
 * 广播是「发射后不管」的，所以 onReceive 里只做入队，立刻返回 ——
 * 真正的引擎启动在后台线程，不占主线程。
 */
class WidgetActionReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        Log.i(TAG, "收到小组件动作: ${intent.action}")
        when (intent.action) {
            ACTION_START -> {
                val pooperId = intent.getStringExtra(EXTRA_POOPER_ID).orEmpty()
                WidgetActionRunner.enqueue(context, PendingWidgetAction.Start(pooperId))
            }

            ACTION_FINISH -> {
                val recordId = intent.getStringExtra(EXTRA_RECORD_ID).orEmpty()
                if (recordId.isNotEmpty()) {
                    WidgetActionRunner.enqueue(context, PendingWidgetAction.Finish(recordId))
                }
            }
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
