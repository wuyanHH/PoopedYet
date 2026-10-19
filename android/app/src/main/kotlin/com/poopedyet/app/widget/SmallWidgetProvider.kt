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
import com.poopedyet.app.R
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 屙了么 · 桌面小号组件 (2×2) —— 现代卡片风「成员打卡卡」。
 *
 * 交互设计：
 * 1. 顶部成员区（40dp 真实头像 + 15sp 姓名）整块可点，原地拉起成员选择浮层，
 *    每个组件实例独立绑定自己的屙屎人，互不干扰；
 * 2. **整张卡只反映绑定这一位的状态**：TA 没在屙，哪怕别人正开着计时，
 *    这张卡也依然是常态 —— 否则点「完成打卡」会结束别人的记录；
 * 3. 点「现在开屙 / 完成打卡」在后台直接写库，**不把用户拽进 App**
 *    （见 [WidgetActionReceiver]）；
 * 4. 进行中状态由系统级原生 Chronometer 驱动跳秒，静态快照不会导致计时停摆。
 */
class SmallWidgetProvider : AppWidgetProvider() {

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
            val views = RemoteViews(context.packageName, R.layout.widget_small)

            val isIncognito = snapshot?.optBoolean("isIncognito", false) ?: false
            val todaySummary = snapshot?.optJSONObject("todaySummary")
            val defaultPooper = snapshot?.optJSONObject("defaultPooper")
            val familyMembers = snapshot?.optJSONArray("familyMembers")

            // ① 读取当前实例独立绑定的成员；未绑定则回退到 App 的默认成员
            val boundPooperId = WidgetDataProvider.getWidgetPooperId(context, widgetId)
            val currentMember = findMember(familyMembers, boundPooperId)
            val targetMember = currentMember ?: defaultPooper
            val targetId = targetMember?.optString("id", "") ?: ""
            val targetName = targetMember?.optString("name", "我") ?: "我"

            // ② 只看「当前这位」在不在屙。
            //
            // 以前读的是顶层 liveSession（全家最新的一条进行中记录），于是家里
            // 任何一个人开屙，这张只显示我自己的卡片也会切成「完成打卡」——
            // 点下去结束的是别人的计时。
            val live = liveStateOf(familyMembers, targetId)
            val isLive = live.isLive
            val recordId = live.recordId
            val startedAtMillis = live.startedAtMillis

            // ③ 成员头像（与主 App 的 PooperAvatar 同源：照片 / 内置图标 / 姓名首字）
            views.setImageViewBitmap(
                R.id.iv_small_avatar,
                WidgetAvatarHelper.createAvatarBitmap(context, targetMember, 40),
            )
            views.setTextViewText(R.id.tv_pooper_name, targetName)

            // ④ 成员区整块点击 → 原地换人（无需删掉再重新添加）。
            //    三款组件统一成「点成员区 + 右侧一条下拉线」这一套暗示，
            //    不能有的能点、有的连提示都没有。
            val switchPendingIntent = buildConfigPendingIntent(context, widgetId, 10000)
            views.setOnClickPendingIntent(R.id.btn_switch_pooper, switchPendingIntent)
            views.setOnClickPendingIntent(R.id.iv_small_chevron, switchPendingIntent)

            // ⑤ 卡片整体点击（打开主页）—— 只有这一处是有意进 App 的
            views.setOnClickPendingIntent(
                R.id.widget_root,
                buildOpenAppPendingIntent(context, "poopedyet://main", 1001),
            )

            if (isLive) {
                // ── 进行中态 ──
                views.setInt(R.id.widget_root, "setBackgroundResource", R.drawable.bg_widget_live)
                views.setViewVisibility(R.id.layout_normal, View.GONE)
                views.setViewVisibility(R.id.layout_live, View.VISIBLE)

                views.setTextViewText(
                    R.id.tv_live_title,
                    if (isIncognito) "正在深度放空中…" else "正在屙…",
                )

                val elapsed = (System.currentTimeMillis() - startedAtMillis).coerceAtLeast(0)
                views.setChronometer(
                    R.id.chrono_timer,
                    SystemClock.elapsedRealtime() - elapsed,
                    "%s",
                    true,
                )
                views.setTextViewText(
                    R.id.tv_elapsed,
                    if (isIncognito) "深度放空中" else "如厕实时计时中",
                )

                views.setTextViewText(
                    R.id.tv_btn_action_text,
                    if (isIncognito) "放空达成" else "完成打卡",
                )
                views.setImageViewResource(R.id.iv_btn_action_icon, R.drawable.ic_widget_action_finish)
                views.setInt(R.id.btn_action, "setBackgroundResource", R.drawable.bg_btn_live)

                views.setOnClickPendingIntent(
                    R.id.btn_action,
                    buildFinishPendingIntent(context, recordId, widgetId, 1002),
                )
            } else {
                // ── 常态 ──
                views.setChronometer(R.id.chrono_timer, SystemClock.elapsedRealtime(), "%s", false)
                views.setInt(R.id.widget_root, "setBackgroundResource", R.drawable.bg_widget_paper)
                views.setViewVisibility(R.id.layout_normal, View.VISIBLE)
                views.setViewVisibility(R.id.layout_live, View.GONE)

                val dayNum = todaySummary?.optInt("dayNum", 1) ?: 1
                val weekdayName = todaySummary?.optString("weekdayName", "周一") ?: "周一"
                val monthLabel = SimpleDateFormat("M月", Locale.CHINA).format(Date())

                views.setTextViewText(R.id.tv_day_num, dayNum.toString())
                views.setTextViewText(R.id.tv_weekday, "$monthLabel · $weekdayName")

                // 统计一律取**这位成员自己的**。
                //
                // 不能因为「TA 今天没记录」就退回全家汇总 —— 那会让绑定 haohao 的
                // 组件显示 xiaojie 的次数，正是「信息没跟着人走」的老毛病。
                // 注意数据要从 familyMembers 里按 id 查：未绑定时 targetMember 是
                // 顶层的 defaultPooper，那个对象身上并没有统计字段。
                val memberData = findMember(familyMembers, targetId)
                val totalCount = memberData?.optInt("todayCount", 0) ?: 0
                val hoursSinceLast = memberData?.optInt("hoursSinceLast", -1) ?: -1

                // 成员区副行：2×2 宽度只有 127dp，放不下「姓名 + 次数胶囊 +
                // 切换箭头」三件套，所以把次数与「多久之前」合并成一行。
                val lastText = if (totalCount > 0) {
                    val base = if (isIncognito) "今日放空 $totalCount 次" else "今日 $totalCount 次"
                    val ago = relativeHoursText(hoursSinceLast)
                    if (ago != null) "$base · $ago" else base
                } else {
                    if (isIncognito) "今天待放空" else "今天还没记录"
                }
                views.setTextViewText(R.id.tv_last_time, lastText)

                views.setTextViewText(
                    R.id.tv_btn_action_text,
                    if (isIncognito) "减负放空" else "现在开屙",
                )
                views.setImageViewResource(R.id.iv_btn_action_icon, R.drawable.ic_widget_action_start)
                views.setInt(R.id.btn_action, "setBackgroundResource", R.drawable.bg_btn_brand)

                views.setOnClickPendingIntent(
                    R.id.btn_action,
                    buildStartPendingIntent(context, targetId, widgetId, 1003),
                )
            }

            return views
        }

        /** 把「多久之前」渲染成紧凑人话；未知时返回 null，由调用方决定省略。 */
        internal fun relativeHoursText(hours: Int): String? = when {
            hours < 0 -> null
            hours == 0 -> "刚刚"
            hours < 24 -> "${hours}h前"
            else -> "${hours / 24}天前"
        }

        /** 打开 App 内的某个 Deep Link 路由（只有「点卡片空白处」走这里）。 */
        internal fun buildOpenAppPendingIntent(context: Context, uri: String, requestCode: Int): PendingIntent {
            val intent = Intent(context, com.poopedyet.app.MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                data = Uri.parse(uri)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            return PendingIntent.getActivity(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        /**
         * 「换人浮层」的独立任务别名。
         *
         * 它和 [WidgetConfigActivity] 是同一个实现，只是被声明在
         * `AndroidManifest.xml` 里、带 `taskAffinity=""`，因此跑在自己的任务里。
         *
         * **为什么非要绕这一下**：`PendingIntent.getActivity` 必须带
         * `FLAG_ACTIVITY_NEW_TASK`，而目标 Activity 的默认 taskAffinity 就是包名 ——
         * 于是系统会复用 App 自己的任务栈，把整个 App 连同 MainActivity 一起
         * 顶到前台。用户看到的就不是「弹个浮层换人」，而是「换个成员怎么把软件打开了」，
         * 而且浮层关掉之后 App 还赖在屏幕上。
         *
         * 不能直接给真实 Activity 加 `taskAffinity=""`：系统添加组件走的是
         * `startActivityForResult`，目标被挪进另一个任务时 Android 会立刻按
         * `RESULT_CANCELED` 回传（"Activity is launching as a new task"），
         * 结果就是组件永远放不上桌面。所以「添加」走真实 Activity、「换人」走别名。
         */
        private val FLOAT_CONFIG_ACTIVITY: String =
            WidgetConfigActivity::class.java.name.substringBeforeLast('.') +
                ".WidgetConfigFloatActivity"

        /** 原地拉起「选择屙屎人」浮层，requestCode 以 offset+widgetId 保证多实例互不覆盖。 */
        internal fun buildConfigPendingIntent(context: Context, widgetId: Int, offset: Int): PendingIntent {
            val intent = Intent().apply {
                setClassName(context.packageName, FLOAT_CONFIG_ACTIVITY)
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            // 别名万一被某个定制 ROM 的清单合并吃掉，就退回真实 Activity：
            // 至少换人还能用，代价只是会把 App 一并带到前台。
            if (context.packageManager.resolveActivity(intent, 0) == null) {
                intent.setClass(context, WidgetConfigActivity::class.java)
            }
            return PendingIntent.getActivity(
                context,
                offset + widgetId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        /**
         * 「开屙」：**广播给 [WidgetActionReceiver] 在后台写库**，不打开 App。
         *
         * requestCode 用 `offset + widgetId` 区分不同组件实例；同一实例重复
         * 设置时靠 FLAG_UPDATE_CURRENT 覆盖 extras。
         */
        internal fun buildStartPendingIntent(
            context: Context,
            pooperId: String,
            widgetId: Int,
            offset: Int,
        ): PendingIntent {
            val intent = Intent(context, WidgetActionReceiver::class.java).apply {
                action = WidgetActionReceiver.ACTION_START
                putExtra(WidgetActionReceiver.EXTRA_POOPER_ID, pooperId)
            }
            return PendingIntent.getBroadcast(
                context,
                offset + widgetId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        /** 「完成」：同样走后台写库。 */
        internal fun buildFinishPendingIntent(
            context: Context,
            recordId: String,
            widgetId: Int,
            offset: Int,
        ): PendingIntent {
            val intent = Intent(context, WidgetActionReceiver::class.java).apply {
                action = WidgetActionReceiver.ACTION_FINISH
                putExtra(WidgetActionReceiver.EXTRA_RECORD_ID, recordId)
            }
            return PendingIntent.getBroadcast(
                context,
                offset + widgetId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
    }
}

// ─────────────────────────────────────────────────────────────────────
// 「每位成员各自的进行中状态」是三个尺寸都要用的公共查询，
// 所以放在文件顶层（而不是 companion 里）—— companion 内嵌套的类
// 没法用 `SmallWidgetProvider.LiveState` 这种简写从别的文件引用。
// ─────────────────────────────────────────────────────────────────────

/** 某位成员此刻的「进行中」状态。 */
internal data class LiveState(
    val isLive: Boolean,
    val recordId: String,
    val startedAtMillis: Long,
)

/**
 * 取出指定成员**自己的**进行中状态。
 *
 * 不要用顶层 `liveSession` —— 那是「全家最新的一条进行中记录」，
 * 拿它渲染单个成员的卡片，就会出现「别人在屙，我的组件按钮变成完成」，
 * 一点下去结束的是别人的计时。
 */
internal fun liveStateOf(familyMembers: JSONArray?, pooperId: String): LiveState {
    if (pooperId.isEmpty()) return LiveState(false, "", 0L)
    val member = findMember(familyMembers, pooperId) ?: return LiveState(false, "", 0L)
    return LiveState(
        isLive = member.optBoolean("isLive", false),
        recordId = member.optString("liveRecordId", ""),
        startedAtMillis = member.optLong("liveStartedAtMillis", 0L),
    )
}

/** 在成员数组里按 id 找人；找不到返回 null。 */
internal fun findMember(familyMembers: JSONArray?, pooperId: String?): JSONObject? {
    if (familyMembers == null || pooperId.isNullOrEmpty()) return null
    for (i in 0 until familyMembers.length()) {
        val member = familyMembers.optJSONObject(i) ?: continue
        if (member.optString("id", "") == pooperId) return member
    }
    return null
}

/** 「已经屙了多久」的紧凑描述，用于 4×4 里每行各自的进行中提示。 */
internal fun elapsedMinutesText(startedAtMillis: Long, isIncognito: Boolean): String {
    val minutes = ((System.currentTimeMillis() - startedAtMillis) / 60_000L).coerceAtLeast(0L)
    val verb = if (isIncognito) "正在放空" else "正在屙"
    return if (minutes <= 0) "$verb · 刚开始" else "$verb · 已用 $minutes 分钟"
}
