package com.poopedyet.app.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import com.poopedyet.app.MainActivity
import com.poopedyet.app.R
import org.json.JSONObject

/**
 * 屙了么 · 手帐周历中号组件 (4×2)
 *
 * 支持：
 * 1. 独立绑定屙屎人与专属统计数据
 * 2. 点击左侧成员头像/姓名区域原地轮换切换屙屎人（无缝换人）
 * 3. 动态映射成员真实头像 Emoji（彻底消除硬编码小狗🐶）
 */
class MediumWidgetProvider : AppWidgetProvider() {

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
        const val ACTION_SWITCH_POOPER = "com.poopedyet.app.widget.ACTION_SWITCH_POOPER_MEDIUM"

        fun updateWidgets(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
            val snapshot = WidgetDataProvider.getSnapshot(context)
            for (widgetId in appWidgetIds) {
                val views = buildRemoteViews(context, snapshot, widgetId)
                appWidgetManager.updateAppWidget(widgetId, views)
            }
        }

        private fun buildRemoteViews(context: Context, snapshot: JSONObject?, widgetId: Int): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_medium)

            val isIncognito = snapshot?.optBoolean("isIncognito", false) ?: false
            val streak = snapshot?.optInt("weekStreakDays", 0) ?: 0
            val liveSession = snapshot?.optJSONObject("liveSession")
            val isLive = liveSession?.optBoolean("isLive", false) ?: false
            val recordId = liveSession?.optString("recordId", "") ?: ""

            val defaultPooper = snapshot?.optJSONObject("defaultPooper")
            val familyMembers = snapshot?.optJSONArray("familyMembers")

            // 1. 读取当前中号小组件独立绑定的成员；未特别绑定则回退到默认成员
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

            val todaySummary = snapshot?.optJSONObject("todaySummary")
            val totalToday = currentMember?.optInt("todayCount", todaySummary?.optInt("totalCount", 0) ?: 0)
                ?: (todaySummary?.optInt("totalCount", 0) ?: 0)
            val hoursSinceLast = currentMember?.optInt("hoursSinceLast", todaySummary?.optInt("hoursSinceLast", -1) ?: -1)
                ?: (todaySummary?.optInt("hoursSinceLast", -1) ?: -1)
            val lastRemark = WidgetDataProvider.optNullableString(currentMember, "lastRemark")
                ?: WidgetDataProvider.optNullableString(todaySummary, "lastRemark")

            // 1. 顶部标题与连续顺畅天数
            val titleText = if (isIncognito) "PoopedYet · 日常轻体" else "屙了么 · 便签手帐"
            views.setTextViewText(R.id.tv_medium_title, titleText)

            val streakText = if (isIncognito) "身心轻盈 ${streak} 天" else "连续顺畅 ${streak} 天"
            views.setTextViewText(R.id.tv_medium_streak, streakText)

            // 2. 左侧行动舱：展示真实头像（照片/首字色彩徽章）与绑定成员姓名（彻底消除 Emoji 狗）
            val avatarBitmap = WidgetAvatarHelper.createAvatarBitmap(context, targetMember, 22)
            views.setImageViewBitmap(R.id.iv_m_avatar, avatarBitmap)
            views.setTextViewText(R.id.tv_m_name, targetName)

            // 绑定点击左侧成员头像区域：原地轮换切换绑定的屙屎人
            val switchIntent = Intent(context, MediumWidgetProvider::class.java).apply {
                action = ACTION_SWITCH_POOPER
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            }
            val switchPendingIntent = PendingIntent.getBroadcast(
                context, 20000 + widgetId, switchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.iv_m_avatar, switchPendingIntent)
            views.setOnClickPendingIntent(R.id.tv_m_name, switchPendingIntent)

            val myStatusText = if (totalToday > 0) {
                if (isIncognito) "已完成放空" else "今日已打卡"
            } else {
                if (isIncognito) "待放空减负" else "今天尚未记录"
            }
            views.setTextViewText(R.id.tv_m_status, myStatusText)

            val lastHourText = if (hoursSinceLast >= 0) "距上次: ${hoursSinceLast}h" else "距上次: 暂无"
            views.setTextViewText(R.id.tv_m_last_hours, lastHourText)

            val remarkText = if (!lastRemark.isNullOrBlank()) {
                "状态: $lastRemark"
            } else {
                if (isIncognito) "状态: 轻松无压力" else "状态: 顺畅无痛"
            }
            views.setTextViewText(R.id.tv_m_remark, remarkText)

            // 卡片整体点击（打开主页）
            val openAppIntent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                data = Uri.parse("poopedyet://main")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            val openAppPendingIntent = PendingIntent.getActivity(
                context, 2000, openAppIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_medium_root, openAppPendingIntent)

            // 按钮状态与交互
            if (isLive) {
                val finishText = if (isIncognito) "放空达成" else "完成打卡"
                views.setTextViewText(R.id.tv_btn_m_action_text, finishText)
                views.setImageViewResource(R.id.iv_btn_m_action_icon, R.drawable.ic_widget_action_finish)
                views.setInt(R.id.btn_m_action, "setBackgroundResource", R.drawable.bg_btn_live)

                val finishIntent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    data = Uri.parse("poopedyet://action/finish?recordId=$recordId")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                }
                val finishPendingIntent = PendingIntent.getActivity(
                    context, 2001, finishIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.btn_m_action, finishPendingIntent)
            } else {
                val startText = if (isIncognito) "减负放空" else "现在开屙"
                views.setTextViewText(R.id.tv_btn_m_action_text, startText)
                views.setImageViewResource(R.id.iv_btn_m_action_icon, R.drawable.ic_widget_action_start)
                views.setInt(R.id.btn_m_action, "setBackgroundResource", R.drawable.bg_btn_brand)

                val startUri = if (targetId.isNotEmpty()) "poopedyet://action/start?pooperId=$targetId" else "poopedyet://action/start"
                val startIntent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    data = Uri.parse(startUri)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                }
                val startPendingIntent = PendingIntent.getActivity(
                    context, 2002, startIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.btn_m_action, startPendingIntent)
            }

            // 3. 右侧迷你 7 天周历
            val weekDays = snapshot?.optJSONArray("weekDays")
            val numViewIds = intArrayOf(
                R.id.tv_cell_num_0, R.id.tv_cell_num_1, R.id.tv_cell_num_2,
                R.id.tv_cell_num_3, R.id.tv_cell_num_4, R.id.tv_cell_num_5, R.id.tv_cell_num_6
            )
            val dotViewIds = intArrayOf(
                R.id.dot_cell_0, R.id.dot_cell_1, R.id.dot_cell_2,
                R.id.dot_cell_3, R.id.dot_cell_4, R.id.dot_cell_5, R.id.dot_cell_6
            )
            val cellViewIds = intArrayOf(
                R.id.cell_0, R.id.cell_1, R.id.cell_2,
                R.id.cell_3, R.id.cell_4, R.id.cell_5, R.id.cell_6
            )

            if (weekDays != null) {
                for (i in 0 until 7) {
                    if (i < weekDays.length()) {
                        val dayObj = weekDays.optJSONObject(i)
                        val dayNum = dayObj?.optInt("dayNum", 1) ?: (i + 1)
                        val isToday = dayObj?.optBoolean("isToday", false) ?: false
                        val count = dayObj?.optInt("count", 0) ?: 0
                        val dateStr = dayObj?.optString("dateStr", "") ?: ""

                        views.setTextViewText(numViewIds[i], dayNum.toString())
                        views.setViewVisibility(dotViewIds[i], if (count > 0) View.VISIBLE else View.INVISIBLE)

                        if (isToday) {
                            views.setInt(cellViewIds[i], "setBackgroundResource", R.drawable.bg_cell_today)
                        } else {
                            views.setInt(cellViewIds[i], "setBackgroundResource", R.drawable.bg_cell_normal)
                        }

                        // 点击日期格跳转定位该天
                        val dayIntent = Intent(context, MainActivity::class.java).apply {
                            action = Intent.ACTION_VIEW
                            data = Uri.parse("poopedyet://calendar?date=$dateStr")
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                        }
                        val dayPendingIntent = PendingIntent.getActivity(
                            context, 3000 + i, dayIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        views.setOnClickPendingIntent(cellViewIds[i], dayPendingIntent)
                    }
                }
            }

            // 底部动态提示条
            val tipText = if (isIncognito) "今日动态：全员生活作息良好" else "今日动态：全员排便节奏规律"
            views.setTextViewText(R.id.tv_medium_tip, tipText)

            return views
        }
    }
}
