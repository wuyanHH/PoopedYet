package com.poopedyet.app.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import com.poopedyet.app.R
import org.json.JSONObject

/**
 * 屙了么 · 桌面中号组件 (4×2) —— 现代卡片风「行动舱 + 7 天周历」。
 *
 * 交互设计：
 * 1. 顶部成员通栏（40dp 头像 + 15sp 姓名 + 一行状态）整块可点，原地换人；
 * 2. 左侧行动舱只承担「距上次多久 / 实时计时 + 主按钮」，避免与顶部信息重复；
 * 3. 右侧周历高亮的是**当前绑定成员**本周的打卡，而不是全家汇总。
 */
class MediumWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        updateWidgets(context, appWidgetManager, appWidgetIds)
    }

    companion object {

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
            val todaySummary = snapshot?.optJSONObject("todaySummary")
            val defaultPooper = snapshot?.optJSONObject("defaultPooper")
            val familyMembers = snapshot?.optJSONArray("familyMembers")

            // ① 当前实例绑定的成员（未绑定 → 回退 App 默认成员）
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

            // 只看**绑定的这一位**在不在屙。以前读顶层 liveSession（全家最新一条），
            // 于是别人开屙时，这张只显示自己的卡也会切成「完成打卡」。
            val live = liveStateOf(familyMembers, targetId)
            val isLive = live.isLive
            val recordId = live.recordId
            val startedAtMillis = live.startedAtMillis

            // 统计一律取**这位成员自己的**，不退回全家汇总：
            // 绑定 haohao 的组件不该显示 xiaojie 的次数。
            // 数据从 familyMembers 按 id 查 —— 未绑定时 targetMember 是顶层的
            // defaultPooper，那个对象身上并没有统计字段。
            val memberData = findMember(familyMembers, targetId)
            val totalToday = memberData?.optInt("todayCount", 0) ?: 0
            val hoursSinceLast = memberData?.optInt("hoursSinceLast", -1) ?: -1
            val lastTimeStr = WidgetDataProvider.optNullableString(memberData, "lastTimeStr")
            val lastRemark = WidgetDataProvider.optNullableString(memberData, "lastRemark")

            // ② 顶部成员通栏
            views.setImageViewBitmap(
                R.id.iv_m_avatar,
                WidgetAvatarHelper.createAvatarBitmap(context, targetMember, 36),
            )
            views.setTextViewText(R.id.tv_m_name, targetName)

            val statusParts = mutableListOf<String>()
            statusParts += if (totalToday > 0) {
                if (isIncognito) "今日放空 $totalToday 次" else "今日 $totalToday 次"
            } else {
                if (isIncognito) "今天还没放空" else "今天还没记录"
            }
            if (lastTimeStr != null) {
                statusParts += if (isIncognito) "上次放空 $lastTimeStr" else "上次 $lastTimeStr"
            }
            if (!lastRemark.isNullOrBlank()) {
                statusParts += lastRemark
            }
            views.setTextViewText(R.id.tv_m_status, statusParts.joinToString(" · "))

            val switchPendingIntent = SmallWidgetProvider.buildConfigPendingIntent(context, widgetId, 20000)
            views.setOnClickPendingIntent(R.id.btn_m_switch_pooper, switchPendingIntent)
            views.setOnClickPendingIntent(R.id.iv_m_chevron, switchPendingIntent)

            // 连续天数取**绑定这位**自己的。顶层的 weekStreakDays 是全家口径 ——
            // 一个人天天记、另一个人从没记过，两个人的组件却会显示同一个数字。
            val streak = memberData?.optInt("streakDays", 0) ?: 0
            views.setTextViewText(
                R.id.tv_medium_streak,
                if (isIncognito) "身心轻盈 $streak 天" else "连续顺畅 $streak 天",
            )
            // 0 天时整颗胶囊没什么信息量，收起来让顶部更干净
            views.setViewVisibility(
                R.id.tv_medium_streak,
                if (streak > 0) View.VISIBLE else View.GONE,
            )

            // ③ 卡片整体点击（打开主页）
            views.setOnClickPendingIntent(
                R.id.widget_medium_root,
                SmallWidgetProvider.buildOpenAppPendingIntent(context, "poopedyet://main", 2000),
            )

            // ④ 左侧行动舱：距上次多久 / 实时计时
            if (isLive) {
                views.setViewVisibility(R.id.layout_m_normal, View.GONE)
                views.setViewVisibility(R.id.layout_m_live, View.VISIBLE)

                val elapsed = (System.currentTimeMillis() - startedAtMillis).coerceAtLeast(0)
                views.setChronometer(
                    R.id.chrono_m_timer,
                    SystemClock.elapsedRealtime() - elapsed,
                    "%s",
                    true,
                )
                views.setTextViewText(
                    R.id.tv_m_elapsed,
                    if (isIncognito) "放空中" else "正在屙…",
                )

                views.setTextViewText(
                    R.id.tv_btn_m_action_text,
                    if (isIncognito) "放空达成" else "完成打卡",
                )
                views.setImageViewResource(R.id.iv_btn_m_action_icon, R.drawable.ic_widget_action_finish)
                views.setInt(R.id.btn_m_action, "setBackgroundResource", R.drawable.bg_btn_live)

                views.setOnClickPendingIntent(
                    R.id.btn_m_action,
                    SmallWidgetProvider.buildFinishPendingIntent(context, recordId, widgetId, 2001),
                )
            } else {
                views.setChronometer(R.id.chrono_m_timer, SystemClock.elapsedRealtime(), "%s", false)
                views.setViewVisibility(R.id.layout_m_normal, View.VISIBLE)
                views.setViewVisibility(R.id.layout_m_live, View.GONE)

                val bigNum: String
                val bigLabel: String
                when {
                    hoursSinceLast < 0 -> {
                        bigNum = "—"
                        bigLabel = if (isIncognito) "还没记录" else "暂无记录"
                    }
                    hoursSinceLast < 24 -> {
                        bigNum = "${hoursSinceLast}h"
                        bigLabel = if (isIncognito) "距上次放空" else "距上次"
                    }
                    else -> {
                        bigNum = "${hoursSinceLast / 24}天"
                        bigLabel = if (isIncognito) "距上次放空" else "距上次"
                    }
                }
                views.setTextViewText(R.id.tv_m_big_num, bigNum)
                views.setTextViewText(R.id.tv_m_big_label, bigLabel)

                views.setTextViewText(
                    R.id.tv_btn_m_action_text,
                    if (isIncognito) "减负放空" else "现在开屙",
                )
                views.setImageViewResource(R.id.iv_btn_m_action_icon, R.drawable.ic_widget_action_start)
                views.setInt(R.id.btn_m_action, "setBackgroundResource", R.drawable.bg_btn_brand)

                views.setOnClickPendingIntent(
                    R.id.btn_m_action,
                    SmallWidgetProvider.buildStartPendingIntent(context, targetId, widgetId, 2002),
                )
            }

            // ⑤ 右侧 7 天周历（只点亮当前成员自己的打卡）
            renderWeekStrip(views, context, snapshot, widgetId, targetId, isIncognito, targetName)

            return views
        }

        private fun renderWeekStrip(
            views: RemoteViews,
            context: Context,
            snapshot: JSONObject?,
            widgetId: Int,
            targetPooperId: String,
            isIncognito: Boolean,
            targetName: String,
        ) {
            val weekDays = snapshot?.optJSONArray("weekDays") ?: return

            val numViewIds = intArrayOf(
                R.id.tv_cell_num_0, R.id.tv_cell_num_1, R.id.tv_cell_num_2,
                R.id.tv_cell_num_3, R.id.tv_cell_num_4, R.id.tv_cell_num_5,
                R.id.tv_cell_num_6,
            )
            val dotViewIds = intArrayOf(
                R.id.dot_cell_0, R.id.dot_cell_1, R.id.dot_cell_2,
                R.id.dot_cell_3, R.id.dot_cell_4, R.id.dot_cell_5,
                R.id.dot_cell_6,
            )
            val cellViewIds = intArrayOf(
                R.id.cell_0, R.id.cell_1, R.id.cell_2,
                R.id.cell_3, R.id.cell_4, R.id.cell_5,
                R.id.cell_6,
            )

            for (i in 0 until 7) {
                if (i >= weekDays.length()) break
                val dayObj = weekDays.optJSONObject(i) ?: continue

                val dayNum = dayObj.optInt("dayNum", i + 1)
                val isToday = dayObj.optBoolean("isToday", false)
                val dateStr = dayObj.optString("dateStr", "")

                // 优先用「该成员在这一天的次数」；快照缺失时退回全家汇总计数。
                val pooperCounts = dayObj.optJSONObject("pooperCounts")
                val ownCount = if (targetPooperId.isNotEmpty()) {
                    pooperCounts?.optInt(targetPooperId, 0) ?: 0
                } else {
                    dayObj.optInt("count", 0)
                }

                views.setTextViewText(numViewIds[i], dayNum.toString())
                views.setViewVisibility(dotViewIds[i], if (ownCount > 0) View.VISIBLE else View.INVISIBLE)
                views.setInt(
                    cellViewIds[i],
                    "setBackgroundResource",
                    if (isToday) R.drawable.bg_cell_today else R.drawable.bg_cell_normal,
                )

                val label = if (isIncognito) {
                    "$targetName $dateStr 放空 $ownCount 次，点击查看当天详情"
                } else {
                    "$targetName $dateStr 打卡 $ownCount 次，点击查看当天详情"
                }
                views.setContentDescription(cellViewIds[i], label)

                if (dateStr.isNotEmpty()) {
                    views.setOnClickPendingIntent(
                        cellViewIds[i],
                        SmallWidgetProvider.buildOpenAppPendingIntent(
                            context,
                            "poopedyet://calendar?date=$dateStr",
                            30000 + widgetId * 10 + i,
                        ),
                    )
                }
            }
        }
    }
}
