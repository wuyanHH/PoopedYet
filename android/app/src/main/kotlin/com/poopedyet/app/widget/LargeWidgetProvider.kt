package com.poopedyet.app.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import com.poopedyet.app.R
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 屙了么 · 桌面大号组件 (4×4) —— 现代卡片风「家庭健康看板」。
 *
 * ## 多人组件的分工（这块最容易做乱）
 *
 * 4×4 同时显示好几个人，所以「进行中」不能只有一个全局状态：
 *
 * | 位置 | 反映谁的状态 | 点它做什么 |
 * |---|---|---|
 * | 每一行 | **该行那一位**自己的计时 | 在屙 → 结束 TA 的计时；否则 → 为 TA 开屙 |
 * | 顶部成员胶囊 | 本组件绑定的那一位 | 拉起成员选择浮层 |
 * | 底部主按钮 | **绑定那一位**（胶囊上的人） | 在屙 → 结束；否则 → 开屙 |
 *
 * 这样「谁在屙」是逐行呈现的：xiaojie 开着计时，haohao 那一行照样是常态，
 * 底部按钮也只看绑定成员 —— 不会出现「随便谁在屙，整块卡都变成完成」。
 *
 * ## 其他
 *
 * - 已归档成员不占看板位置；
 * - 所有开屙 / 完成都在后台写库（[WidgetActionReceiver]），不打开 App；
 * - 便签卡是弹性区，成员多、便签长时自动让位，底部按钮永远贴底。
 */
class LargeWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        updateWidgets(context, appWidgetManager, appWidgetIds)
    }

    companion object {

        /** 大号组件最多直排展示的成员数，超出部分在第 3 行汇总。 */
        private const val MAX_ROWS = 3

        fun updateWidgets(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
            val snapshot = WidgetDataProvider.getSnapshot(context)
            for (widgetId in appWidgetIds) {
                val views = buildRemoteViews(context, snapshot, widgetId)
                appWidgetManager.updateAppWidget(widgetId, views)
            }
        }

        private fun buildRemoteViews(context: Context, snapshot: JSONObject?, widgetId: Int): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_large)

            val isIncognito = snapshot?.optBoolean("isIncognito", false) ?: false
            val todaySummary = snapshot?.optJSONObject("todaySummary")
            val familyMembers = snapshot?.optJSONArray("familyMembers")
            val weekdayName = todaySummary?.optString("weekdayName", "周一") ?: "周一"
            val dateLabel = "${SimpleDateFormat("M月d日", Locale.CHINA).format(Date())} $weekdayName"

            val liveColor = ContextCompat.getColor(context, R.color.widget_live)
            val mutedColor = ContextCompat.getColor(context, R.color.widget_ink_3)

            // ① 当前实例绑定的成员；没有绑定则跟随 App 的默认成员
            val boundPooperId = WidgetDataProvider.getWidgetPooperId(context, widgetId)
            val members = collectActiveMembers(snapshot, boundPooperId)
            val capsuleMember = members.firstOrNull { it.optString("id", "") == boundPooperId }
                ?: snapshot?.optJSONObject("defaultPooper")

            val primaryId = capsuleMember?.optString("id", "") ?: ""
            val primaryLive = liveStateOf(familyMembers, primaryId)

            // ② 顶部标题 + 成员胶囊 + 日期
            views.setTextViewText(
                R.id.tv_large_title,
                if (isIncognito) "PoopedYet · 日常轻体" else "屙了么 · 家庭看板",
            )
            views.setTextViewText(R.id.tv_large_date, dateLabel)

            views.setImageViewBitmap(
                R.id.iv_large_avatar,
                WidgetAvatarHelper.createAvatarBitmap(context, capsuleMember, 20),
            )
            views.setTextViewText(
                R.id.tv_large_pooper_name,
                capsuleMember?.optString("name", "我") ?: "我",
            )

            val switchPendingIntent = SmallWidgetProvider.buildConfigPendingIntent(context, widgetId, 4500)
            views.setOnClickPendingIntent(R.id.btn_large_switch_pooper, switchPendingIntent)
            views.setOnClickPendingIntent(R.id.iv_large_chevron, switchPendingIntent)

            // ③ 卡片整体点击（打开主页）—— 只有这一处是有意进 App 的
            views.setOnClickPendingIntent(
                R.id.widget_large_root,
                SmallWidgetProvider.buildOpenAppPendingIntent(context, "poopedyet://main", 4000),
            )

            // ④ 家庭成员行（绑定的那位已置顶）
            val memberCount = members.size
            val rowIds = intArrayOf(R.id.row_f_0, R.id.row_f_1, R.id.row_f_2)
            val avatarIds = intArrayOf(R.id.iv_f_avatar_0, R.id.iv_f_avatar_1, R.id.iv_f_avatar_2)
            val nameIds = intArrayOf(R.id.tv_f_name_0, R.id.tv_f_name_1, R.id.tv_f_name_2)
            val statusIds = intArrayOf(R.id.tv_f_time_0, R.id.tv_f_time_1, R.id.tv_f_time_2)
            val buttonIds = intArrayOf(R.id.btn_f_0, R.id.btn_f_1, R.id.btn_f_2)

            for (i in 0 until MAX_ROWS) {
                // 前 MAX_ROWS 位正常展示；如果还有更多人，最后一行变成「还有 N 位」入口。
                val isOverflowRow = i == MAX_ROWS - 1 && memberCount > MAX_ROWS
                val member = if (!isOverflowRow && i < memberCount) members.getOrNull(i) else null

                if (member == null && !isOverflowRow) {
                    views.setViewVisibility(rowIds[i], View.GONE)
                    continue
                }

                views.setViewVisibility(rowIds[i], View.VISIBLE)

                if (isOverflowRow) {
                    val more = memberCount - (MAX_ROWS - 1)
                    views.setImageViewResource(avatarIds[i], R.drawable.ic_widget_avatar_placeholder)
                    views.setTextViewText(nameIds[i], "还有 $more 位家庭成员")
                    views.setTextColor(statusIds[i], mutedColor)
                    views.setTextViewText(
                        statusIds[i],
                        if (isIncognito) "打开屙了么查看全员" else "打开屙了么查看全员记录",
                    )
                    views.setTextViewText(buttonIds[i], "查看全部")
                    views.setOnClickPendingIntent(
                        rowIds[i],
                        SmallWidgetProvider.buildOpenAppPendingIntent(context, "poopedyet://main", 4100 + i),
                    )
                    views.setOnClickPendingIntent(
                        buttonIds[i],
                        SmallWidgetProvider.buildOpenAppPendingIntent(context, "poopedyet://main", 4200 + i),
                    )
                    continue
                }

                val id = member!!.optString("id", "")
                val name = member.optString("name", "我")
                val todayCount = member.optInt("todayCount", 0)
                val lastTimeDesc = WidgetDataProvider.optNullableString(member, "lastTimeDesc")
                val lastTimeStr = WidgetDataProvider.optNullableString(member, "lastTimeStr")

                // 这一位**自己**在不在屙 —— 逐行独立判断，互不影响
                val memberLive = liveStateOf(familyMembers, id)

                views.setImageViewBitmap(
                    avatarIds[i],
                    WidgetAvatarHelper.createAvatarBitmap(context, member, 32),
                )
                views.setTextViewText(nameIds[i], name)

                if (memberLive.isLive) {
                    views.setTextViewText(
                        statusIds[i],
                        elapsedMinutesText(memberLive.startedAtMillis, isIncognito),
                    )
                    views.setTextColor(statusIds[i], liveColor)
                    views.setTextViewText(buttonIds[i], if (isIncognito) "结束" else "完成")

                    val finishIntent = SmallWidgetProvider.buildFinishPendingIntent(
                        context, memberLive.recordId, widgetId, 4400 + i,
                    )
                    views.setOnClickPendingIntent(rowIds[i], finishIntent)
                    views.setOnClickPendingIntent(buttonIds[i], finishIntent)
                } else {
                    views.setTextViewText(
                        statusIds[i],
                        buildStatusText(todayCount, lastTimeDesc, lastTimeStr, isIncognito),
                    )
                    views.setTextColor(statusIds[i], mutedColor)
                    views.setTextViewText(
                        buttonIds[i],
                        if (isIncognito) "放空" else if (i == 0) "记一次" else "帮记",
                    )

                    // 行点击与按钮点击都落到「为这位成员开屙」，一次点击即达。
                    val startIntent = SmallWidgetProvider.buildStartPendingIntent(
                        context, id, widgetId, 4300 + i,
                    )
                    views.setOnClickPendingIntent(rowIds[i], startIntent)
                    views.setOnClickPendingIntent(buttonIds[i], startIntent)
                }
            }

            // ⑤ 本周小结 + 本周节律 + 最近一条便签
            //
            // 这块原来是「最新便签速记」，占着整卡最贵的位置却常年空白。
            // 便签本身没问题，问题在于它是低频内容、还只读 —— 不该占近四成高度。
            // 现在主信息换成真正有参考价值的本周统计与节律，便签退成一行。
            val weekly = snapshot?.optJSONObject("weeklySummary")
            val weeklyTotal = weekly?.optInt("totalCount", 0) ?: 0
            val weeklyActiveDays = weekly?.optInt("activeDays", 0) ?: 0
            val topName = WidgetDataProvider.optNullableString(weekly, "mostActiveName")

            views.setTextViewText(
                R.id.tv_week_summary,
                when {
                    weeklyTotal <= 0 ->
                        if (isIncognito) "本周还没有轻体记录" else "本周还没有记录"
                    topName != null ->
                        "本周 ${if (isIncognito) "轻体 " else ""}$weeklyTotal 次 · $weeklyActiveDays 天有记录 · 最勤 $topName"
                    else -> "本周 $weeklyTotal 次 · $weeklyActiveDays 天有记录"
                },
            )

            // 本周节律：一格一天，「一3」= 周一 3 次；没记录显示成「一·」，今天那格高亮。
            // 一眼就能看出这周哪几天断了、哪天最集中，比一段便签有用得多。
            val weekDaysJson = snapshot?.optJSONArray("weekDays")
            val weekCellIds = intArrayOf(
                R.id.tv_wd_0, R.id.tv_wd_1, R.id.tv_wd_2, R.id.tv_wd_3,
                R.id.tv_wd_4, R.id.tv_wd_5, R.id.tv_wd_6,
            )
            val countColor = ContextCompat.getColor(context, R.color.widget_brand_ink)
            for (i in weekCellIds.indices) {
                val day = weekDaysJson?.optJSONObject(i)
                val label = day?.optString("weekdayLabel", "") ?: ""
                val count = day?.optInt("count", 0) ?: 0
                val isToday = day?.optBoolean("isToday", false) ?: false

                views.setTextViewText(
                    weekCellIds[i],
                    if (count > 0) "$label$count" else "$label·",
                )
                views.setTextColor(weekCellIds[i], if (count > 0) countColor else mutedColor)
                views.setInt(
                    weekCellIds[i],
                    "setBackgroundResource",
                    if (isToday) R.drawable.bg_cell_today else R.drawable.bg_cell_normal,
                )
            }

            val recentNote = snapshot?.optJSONObject("recentNote")
            if (recentNote != null) {
                val pooperName = recentNote.optString("pooperName", "我")
                val timeStr = recentNote.optString("timeStr", "")
                val text = recentNote.optString("text", "")

                views.setViewVisibility(R.id.layout_recent_note, View.VISIBLE)
                views.setTextViewText(R.id.tv_note_content, "$pooperName · $timeStr · $text")
                views.setTextViewText(R.id.tv_note_tag, if (isIncognito) "#轻松" else "#顺畅")
            } else {
                // 没便签就把整行收起来，不再留一句「暂无便签」占地方
                views.setViewVisibility(R.id.layout_recent_note, View.GONE)
            }

            // ⑥ 底部主按钮：跟随**胶囊上这一位**
            //
            // 其余成员各自的进度已经显示在各自那一行上；大按钮不该被
            // 「随便谁在屙」牵着走，否则用户点「完成打卡」结束的是别人的计时。
            if (primaryLive.isLive) {
                views.setTextViewText(
                    R.id.tv_btn_large_start_text,
                    if (isIncognito) "放空达成" else "完成打卡",
                )
                views.setImageViewResource(R.id.iv_btn_large_start_icon, R.drawable.ic_widget_action_finish)
                views.setInt(R.id.btn_large_start, "setBackgroundResource", R.drawable.bg_btn_live)

                views.setOnClickPendingIntent(
                    R.id.btn_large_start,
                    SmallWidgetProvider.buildFinishPendingIntent(
                        context, primaryLive.recordId, widgetId, 4001,
                    ),
                )
            } else {
                views.setTextViewText(
                    R.id.tv_btn_large_start_text,
                    if (isIncognito) "减负放空" else "极速开屙",
                )
                views.setImageViewResource(R.id.iv_btn_large_start_icon, R.drawable.ic_widget_action_start)
                views.setInt(R.id.btn_large_start, "setBackgroundResource", R.drawable.bg_btn_brand)

                views.setOnClickPendingIntent(
                    R.id.btn_large_start,
                    SmallWidgetProvider.buildStartPendingIntent(context, primaryId, widgetId, 4002),
                )
            }

            // 补录便签与打开月历都需要见到完整界面，这两处保留进 App。
            views.setOnClickPendingIntent(
                R.id.btn_large_backfill,
                SmallWidgetProvider.buildOpenAppPendingIntent(context, "poopedyet://action/create_manual", 4003),
            )
            views.setOnClickPendingIntent(
                R.id.btn_large_calendar,
                SmallWidgetProvider.buildOpenAppPendingIntent(context, "poopedyet://calendar", 4004),
            )

            return views
        }

        /**
         * 取出可以上「家庭看板」的成员：**归档的不算**，绑定的那位**置顶**。
         *
         * 置顶而不是加高亮边框，是因为 4×4 的每一行都已经被填满，
         * 再加边框会和「记一次」按钮抢注意力；顺序本身就是最好的强调。
         */
        private fun collectActiveMembers(snapshot: JSONObject?, boundPooperId: String?): List<JSONObject> {
            val familyMembers = snapshot?.optJSONArray("familyMembers") ?: return emptyList()

            val active = mutableListOf<JSONObject>()
            for (i in 0 until familyMembers.length()) {
                val member = familyMembers.optJSONObject(i) ?: continue
                if (member.optBoolean("isArchived", false)) continue
                active.add(member)
            }

            if (boundPooperId != null) {
                val index = active.indexOfFirst { it.optString("id", "") == boundPooperId }
                if (index > 0) {
                    active.add(0, active.removeAt(index))
                }
            }
            return active
        }

        /** 成员状态行：「今日 2 次 · 上次 14:15」/「昨天 19:40」/「还没有记录」。 */
        private fun buildStatusText(
            todayCount: Int,
            lastTimeDesc: String?,
            lastTimeStr: String?,
            isIncognito: Boolean,
        ): String {
            val verb = if (isIncognito) "放空" else "记录"
            return when {
                todayCount > 0 && lastTimeStr != null ->
                    "今日 $todayCount 次 · 上次 $lastTimeStr"
                todayCount > 0 -> "今日 $todayCount 次"
                lastTimeDesc != null && lastTimeStr != null -> "$lastTimeDesc $lastTimeStr"
                lastTimeDesc != null -> lastTimeDesc
                else -> "还没有$verb"
            }
        }
    }
}
