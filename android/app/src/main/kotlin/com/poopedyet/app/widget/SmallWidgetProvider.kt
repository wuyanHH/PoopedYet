package com.poopedyet.app.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import com.poopedyet.app.MainActivity
import com.poopedyet.app.R
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 屙了么 · 桌面撕历小号组件 (2×2)
 *
 * 支持：
 * 1. 原生 Chronometer 实时秒表跳动（解决一直显示0分钟）
 * 2. 独立绑定与点击右上角头像胶囊原地轮换切换屙屎人（支持多成员、多组件各自独立绑定）
 * 3. 动态识别成员真实头像 Emoji（彻底消除硬编码小狗🐶）
 */
class SmallWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        updateWidgets(context, appWidgetManager, appWidgetIds)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_SWITCH_POOPER) {
            val widgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
            if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                // 原地切换到下一个家庭成员并立即局部刷新
                WidgetDataProvider.cycleNextPooper(context, widgetId)
                val appWidgetManager = AppWidgetManager.getInstance(context)
                updateWidgets(context, appWidgetManager, intArrayOf(widgetId))
            }
        }
    }

    companion object {
        const val ACTION_SWITCH_POOPER = "com.poopedyet.app.widget.ACTION_SWITCH_POOPER_SMALL"

        fun updateWidgets(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
            val snapshot = WidgetDataProvider.getSnapshot(context)
            for (widgetId in appWidgetIds) {
                val views = buildRemoteViews(context, snapshot, widgetId)
                appWidgetManager.updateAppWidget(widgetId, views)
            }
        }

        private fun buildRemoteViews(context: Context, snapshot: JSONObject?, widgetId: Int): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_small)

            val isIncognito = snapshot?.optBoolean("isIncognito", false) ?: false
            val liveSession = snapshot?.optJSONObject("liveSession")
            val isLive = liveSession?.optBoolean("isLive", false) ?: false
            val recordId = liveSession?.optString("recordId", "") ?: ""
            val startedAtMillis = liveSession?.optLong("startedAtMillis", 0L) ?: 0L

            val todaySummary = snapshot?.optJSONObject("todaySummary")
            val defaultPooper = snapshot?.optJSONObject("defaultPooper")
            val familyMembers = snapshot?.optJSONArray("familyMembers")

            // 1. 读取当前小组件独立绑定的成员；未特别绑定则回退到默认成员
            val boundPooperId = WidgetDataProvider.getWidgetPooperId(context, widgetId)
            var currentMember: JSONObject? = null
            if (familyMembers != null && boundPooperId != null) {
                for (i in 0 until familyMembers.length()) {
                    val m = familyMembers.optJSONObject(i)
                    if (m?.optString("id") == boundPooperId) {
                        currentMember = m
                        break
                    }
                }
            }

            val targetMember = currentMember ?: defaultPooper
            val targetId = targetMember?.optString("id", "") ?: ""
            val targetName = targetMember?.optString("name", "我") ?: "我"

            // 成员头像标签：使用与 Flutter 端 PooperAvatar 完全一致的真实头像（照片/首字色彩徽章），彻底告别 Emoji 狗
            val avatarBitmap = WidgetAvatarHelper.createAvatarBitmap(context, targetMember, 14)
            views.setImageViewBitmap(R.id.iv_small_avatar, avatarBitmap)
            views.setTextViewText(R.id.tv_pooper_badge, targetName)

            // 绑定点击右上角头像胶囊：原地轮换切换屙屎人
            val switchIntent = Intent(context, SmallWidgetProvider::class.java).apply {
                action = ACTION_SWITCH_POOPER
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            }
            val switchPendingIntent = PendingIntent.getBroadcast(
                context, 10000 + widgetId, switchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.btn_switch_pooper, switchPendingIntent)
            views.setOnClickPendingIntent(R.id.tv_pooper_badge, switchPendingIntent)

            // 月份标签
            val monthFormat = SimpleDateFormat("M月", Locale.CHINA)
            val monthStr = if (isIncognito) "${monthFormat.format(Date())} JOURNAL" else "${monthFormat.format(Date())} MARCH"
            views.setTextViewText(R.id.tv_month, monthStr)

            // 卡片整体点击（打开主页）
            val openAppIntent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                data = Uri.parse("poopedyet://main")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            val openAppPendingIntent = PendingIntent.getActivity(
                context, 1001, openAppIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, openAppPendingIntent)

            if (isLive) {
                // 进行中状态：抹茶绿微光边框与动态秒表
                views.setInt(R.id.widget_root, "setBackgroundResource", R.drawable.bg_widget_live)
                views.setViewVisibility(R.id.layout_normal, View.GONE)
                views.setViewVisibility(R.id.layout_live, View.VISIBLE)

                val liveTitle = if (isIncognito) "正在深度放空中..." else "正在屙..."
                views.setTextViewText(R.id.tv_live_title, liveTitle)

                // 使用系统级 Chronometer 驱动原生动态跳秒，彻底根治静态文本导致“一直显示0分钟”的问题
                val durationAlready = (System.currentTimeMillis() - startedAtMillis).coerceAtLeast(0)
                val baseChronometerTime = SystemClock.elapsedRealtime() - durationAlready
                views.setChronometer(R.id.chrono_timer, baseChronometerTime, "%s", true)
                views.setTextViewText(R.id.tv_elapsed, if (isIncognito) "深度放空中" else "如厕实时计时中")

                val finishText = if (isIncognito) "放空达成" else "完成打卡"
                views.setTextViewText(R.id.tv_btn_action_text, finishText)
                views.setImageViewResource(R.id.iv_btn_action_icon, R.drawable.ic_widget_action_finish)
                views.setInt(R.id.btn_action, "setBackgroundResource", R.drawable.bg_btn_live)

                // 完成按钮动作
                val finishIntent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    data = Uri.parse("poopedyet://action/finish?recordId=$recordId")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                }
                val finishPendingIntent = PendingIntent.getActivity(
                    context, 1002, finishIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.btn_action, finishPendingIntent)

            } else {
                // 常态布局：停止 Chronometer 并恢复撕历印章
                views.setChronometer(R.id.chrono_timer, SystemClock.elapsedRealtime(), "%s", false)
                views.setInt(R.id.widget_root, "setBackgroundResource", R.drawable.bg_widget_paper)
                views.setViewVisibility(R.id.layout_normal, View.VISIBLE)
                views.setViewVisibility(R.id.layout_live, View.GONE)

                val dayNum = todaySummary?.optInt("dayNum", 1) ?: 1
                val weekdayName = todaySummary?.optString("weekdayName", "周一") ?: "周一"

                // 提取专属该成员的今日次数与上次时间
                val totalCount = currentMember?.optInt("todayCount", todaySummary?.optInt("totalCount", 0) ?: 0)
                    ?: (todaySummary?.optInt("totalCount", 0) ?: 0)
                val lastTimeStr = WidgetDataProvider.optNullableString(currentMember, "lastTimeStr")
                    ?: WidgetDataProvider.optNullableString(todaySummary, "lastTimeStr")

                views.setTextViewText(R.id.tv_day_num, dayNum.toString())
                views.setTextViewText(R.id.tv_weekday, weekdayName)

                val countText = if (isIncognito) "已放空 $totalCount 次" else "今日 $totalCount 次"
                views.setTextViewText(R.id.tv_today_count, countText)

                val lastText = if (lastTimeStr != null) {
                    if (isIncognito) "上次放空 $lastTimeStr" else "上次 $lastTimeStr"
                } else {
                    if (isIncognito) "今天待放空" else "今天尚未记录"
                }
                views.setTextViewText(R.id.tv_last_time, lastText)

                val startText = if (isIncognito) "减负放空" else "现在开屙"
                views.setTextViewText(R.id.tv_btn_action_text, startText)
                views.setImageViewResource(R.id.iv_btn_action_icon, R.drawable.ic_widget_action_start)
                views.setInt(R.id.btn_action, "setBackgroundResource", R.drawable.bg_btn_brand)

                // 开屙按钮动作：带上指定成员 ID，支持直接记给当前绑定的屙屎人
                val startUri = if (targetId.isNotEmpty()) "poopedyet://action/start?pooperId=$targetId" else "poopedyet://action/start"
                val startIntent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    data = Uri.parse(startUri)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                }
                val startPendingIntent = PendingIntent.getActivity(
                    context, 1003, startIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.btn_action, startPendingIntent)
            }

            return views
        }
    }
}
