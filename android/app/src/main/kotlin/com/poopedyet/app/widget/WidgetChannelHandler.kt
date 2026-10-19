package com.poopedyet.app.widget

import android.content.Context
import com.poopedyet.app.service.PoopLiveService
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/**
 * `com.poopedyet.app/widget` 通道里几个「任何宿主都必须会处理」的方法。
 *
 * 抽出来的原因：这条通道现在有两个宿主 ——
 *  1. 主 App 的 `MainActivity`；
 *  2. 点小组件按钮时临时拉起的**无界面 FlutterEngine**（见 [WidgetActionRunner]）。
 *
 * 两边都必须能接收 `updateSnapshot` / 读写绑定，否则「后台点一下开屙」之后
 * 快照推不出去，桌面上那个组件会一直停在旧状态。
 */
object WidgetChannelHandler {

    /** 小组件主通道名，两个宿主共用。 */
    const val CHANNEL = "com.poopedyet.app/widget"

    /**
     * 尝试处理一个调用。
     *
     * @return `true` 表示已被处理，宿主不必再走自己的分支。
     */
    fun handle(context: Context, call: MethodCall, result: MethodChannel.Result): Boolean {
        when (call.method) {
            "updateSnapshot" -> {
                val jsonStr = call.argument<String>("snapshotJson")
                if (jsonStr == null) {
                    result.error("INVALID_ARG", "snapshotJson is null", null)
                    return true
                }
                WidgetDataProvider.saveSnapshot(context, jsonStr)
                syncLiveService(context, jsonStr)
                result.success(true)
                return true
            }

            "listWidgetBindings" -> {
                result.success(WidgetDataProvider.buildBindingsJson(context).toString())
                return true
            }

            "setWidgetPooper" -> {
                val widgetId = call.argument<Int>("widgetId")
                if (widgetId == null) {
                    result.error("INVALID_ARG", "widgetId is null", null)
                    return true
                }
                val pooperId = call.argument<String>("pooperId")
                if (pooperId.isNullOrBlank()) {
                    WidgetDataProvider.clearWidgetPooperId(context, widgetId)
                } else {
                    WidgetDataProvider.setWidgetPooperId(context, widgetId, pooperId)
                }
                WidgetDataProvider.triggerUpdateAll(context)
                result.success(true)
                return true
            }

            else -> return false
        }
    }

    /**
     * 按快照里的进行中状态，起停前台计时服务（状态栏胶囊 / 锁屏计时）。
     *
     * 名字取的是**实际开屙的那位**，不是默认成员 —— 家里两个人都可能开着计时，
     * 通知栏显示成默认成员会让人以为记错了人。
     */
    private fun syncLiveService(context: Context, jsonStr: String) {
        try {
            val json = JSONObject(jsonStr)
            val liveSession = json.optJSONObject("liveSession")
            val isLive = liveSession?.optBoolean("isLive", false) ?: false

            if (!isLive) {
                PoopLiveService.stop(context)
                return
            }

            val recordId = liveSession?.optString("recordId", "") ?: ""
            val startedAt = liveSession?.optLong("startedAtMillis", System.currentTimeMillis())
                ?: System.currentTimeMillis()
            val pooperName = WidgetDataProvider.optNullableString(liveSession, "pooperName")
                ?: WidgetDataProvider.optNullableString(json.optJSONObject("defaultPooper"), "name")
                ?: "我"
            val isIncognito = json.optBoolean("isIncognito", false)

            PoopLiveService.start(context, recordId, pooperName, startedAt, isIncognito)
        } catch (_: Exception) {
            // 快照已经落库了，前台服务起不来不影响数据。
        }
    }
}
