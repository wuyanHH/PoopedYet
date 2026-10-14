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
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 屙了么 · 健康工作台大号组件 (4×4)
 */
class LargeWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        updateWidgets(context, appWidgetManager, appWidgetIds)
    }

    companion object {
        fun updateWidgets(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
            val snapshot = WidgetDataProvider.getSnapshot(context)
            for (widgetId in appWidgetIds) {
                val views = buildRemoteViews(context, snapshot)
                appWidgetManager.updateAppWidget(widgetId, views)
            }
        }

        private fun buildRemoteViews(context: Context, snapshot: JSONObject?): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_large)

            val isIncognito = snapshot?.optBoolean("isIncognito", false) ?: false
            val liveSession = snapshot?.optJSONObject("liveSession")
            val isLive = liveSession?.optBoolean("isLive", false) ?: false
            val recordId = liveSession?.optString("recordId", "") ?: ""

            val todaySummary = snapshot?.optJSONObject("todaySummary")
            val weekdayName = todaySummary?.optString("weekdayName", "周一") ?: "周一"
            val monthFormat = SimpleDateFormat("M月d日", Locale.CHINA)
            val dateStr = "${monthFormat.format(Date())} $weekdayName"

            // 1. 顶部标题与日期
            val titleText = if (isIncognito) "PoopedYet · 日常轻体" else "屙了么 · 家庭健康手帐"
            views.setTextViewText(R.id.tv_large_title, titleText)
            views.setTextViewText(R.id.tv_large_date, dateStr)

            // 卡片整体点击（打开主页）
            val openAppIntent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                data = Uri.parse("poopedyet://main")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            val openAppPendingIntent = PendingIntent.getActivity(
                context, 4000, openAppIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_large_root, openAppPendingIntent)

            // 2. 全家成员卡片行（最多前 3 位）
            val familyMembers = snapshot?.optJSONArray("familyMembers")
            val cardIds = intArrayOf(R.id.card_f_0, R.id.card_f_1, R.id.card_f_2)
            val avatarIds = intArrayOf(R.id.iv_f_avatar_0, R.id.iv_f_avatar_1, R.id.iv_f_avatar_2)
            val nameIds = intArrayOf(R.id.tv_f_name_0, R.id.tv_f_name_1, R.id.tv_f_name_2)
            val timeIds = intArrayOf(R.id.tv_f_time_0, R.id.tv_f_time_1, R.id.tv_f_time_2)
            val btnIds = intArrayOf(R.id.btn_f_0, R.id.btn_f_1, R.id.btn_f_2)

            val memberCount = familyMembers?.length() ?: 0
            for (i in 0 until 3) {
                if (i < memberCount) {
                    val m = familyMembers!!.optJSONObject(i)
                    val id = WidgetDataProvider.optNullableString(m, "id") ?: ""
                    val name = WidgetDataProvider.optNullableString(m, "name") ?: "我"
                    val todayCount = m?.optInt("todayCount", 0) ?: 0
                    val lastDesc = WidgetDataProvider.optNullableString(m, "lastTimeDesc") ?: "尚未排便"

                    // 使用与主 App PooperAvatar 像素级对齐的真实头像（照片/姓名首字色彩徽章），杜绝硬编码 Emoji 狗
                    val avatarBitmap = WidgetAvatarHelper.createAvatarBitmap(context, m, 22)

                    views.setViewVisibility(cardIds[i], View.VISIBLE)
                    views.setImageViewBitmap(avatarIds[i], avatarBitmap)
                    views.setTextViewText(nameIds[i], name)

                    val statusText = if (isIncognito) {
                        if (todayCount > 0) "已放空 ${todayCount}次" else "待减负"
                    } else {
                        if (todayCount > 0) "今日 ${todayCount}次" else lastDesc
                    }
                    views.setTextViewText(timeIds[i], statusText)

                    val btnText = if (isIncognito) "放空" else (if (i == 0) "记一次" else "帮记")
                    views.setTextViewText(btnIds[i], btnText)

                    // 针对该成员快捷记一次
                    val memberIntent = Intent(context, MainActivity::class.java).apply {
                        action = Intent.ACTION_VIEW
                        data = Uri.parse("poopedyet://action/start?pooperId=$id")
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                    }
                    val memberPendingIntent = PendingIntent.getActivity(
                        context, 4100 + i, memberIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(btnIds[i], memberPendingIntent)
                } else {
                    views.setViewVisibility(cardIds[i], View.GONE)
                }
            }

            // 3. 最新便签速记
            val recentNote = snapshot?.optJSONObject("recentNote")
            if (recentNote != null) {
                val pName = recentNote.optString("pooperName", "我")
                val tStr = recentNote.optString("timeStr", "")
                val dur = recentNote.optInt("durationMinutes", 0)
                val text = recentNote.optString("text", "")

                val noteHeader = if (dur > 0) "$pName · $tStr (用时 ${dur}m)" else "$pName · $tStr"
                views.setTextViewText(R.id.tv_note_header, noteHeader)
                views.setTextViewText(R.id.tv_note_content, "\"$text\"")
                views.setTextViewText(R.id.tv_note_tag, if (isIncognito) "#轻松" else "#顺畅")
            } else {
                views.setTextViewText(R.id.tv_note_header, if (isIncognito) "暂无近期轻体便签" else "暂无近期便签速记")
                views.setTextViewText(R.id.tv_note_content, "点击下方“补录”添加第一条如厕心得备注。")
                views.setTextViewText(R.id.tv_note_tag, "#手帐")
            }

            // 4. 底部三按钮
            // 按钮 1：极速开屙（包含统一开屙/完成卷纸图标）
            if (isLive) {
                val finishText = if (isIncognito) "放空达成" else "完成打卡"
                views.setTextViewText(R.id.tv_btn_large_start_text, finishText)
                views.setImageViewResource(R.id.iv_btn_large_start_icon, R.drawable.ic_widget_action_finish)
                views.setInt(R.id.btn_large_start, "setBackgroundResource", R.drawable.bg_btn_live)

                val finishIntent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    data = Uri.parse("poopedyet://action/finish?recordId=$recordId")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                }
                val finishPendingIntent = PendingIntent.getActivity(
                    context, 4001, finishIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.btn_large_start, finishPendingIntent)
            } else {
                val startText = if (isIncognito) "减负放空" else "极速开屙"
                views.setTextViewText(R.id.tv_btn_large_start_text, startText)
                views.setImageViewResource(R.id.iv_btn_large_start_icon, R.drawable.ic_widget_action_start)
                views.setInt(R.id.btn_large_start, "setBackgroundResource", R.drawable.bg_btn_brand)

                val startIntent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    data = Uri.parse("poopedyet://action/start")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                }
                val startPendingIntent = PendingIntent.getActivity(
                    context, 4002, startIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.btn_large_start, startPendingIntent)
            }

            // 按钮 2：补录便签
            val backfillIntent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                data = Uri.parse("poopedyet://action/create_manual")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            val backfillPendingIntent = PendingIntent.getActivity(
                context, 4003, backfillIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.btn_large_backfill, backfillPendingIntent)

            // 按钮 3：打开月历
            val calIntent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                data = Uri.parse("poopedyet://calendar")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            val calPendingIntent = PendingIntent.getActivity(
                context, 4004, calIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.btn_large_calendar, calPendingIntent)

            return views
        }
    }
}
