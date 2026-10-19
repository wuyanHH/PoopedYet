package com.poopedyet.app.widget

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

/**
 * 桌面小组件跨进程数据与持久化管理（带内存级高速快照缓存）。
 *
 * 职责有两块：
 *  1. **快照存取** —— Flutter 侧算好的轻量 JSON 存进 SharedPreferences 并缓存到内存；
 *  2. **成员绑定** —— 每个已放置的小组件实例各自绑定一个屙屎人（可为空 = 跟随默认成员）。
 */
object WidgetDataProvider {
    private const val PREFS_NAME = "pooped_yet_widget_pref"
    private const val KEY_SNAPSHOT = "key_snapshot"

    /** 单个小组件实例的成员绑定键前缀，后接 appWidgetId。 */
    private const val KEY_PREFIX_WIDGET_POOPER = "widget_pooper_"

    @Volatile
    private var cachedSnapshot: JSONObject? = null

    @Volatile
    private var cachedRawJson: String? = null

    // ───────────────────────────── 快照 ─────────────────────────────

    fun saveSnapshot(context: Context, jsonStr: String) {
        // 先快速更新内存缓存，消除多组件并发读取时的 I/O 与反序列化开销
        try {
            cachedSnapshot = JSONObject(jsonStr)
            cachedRawJson = jsonStr
        } catch (_: Exception) {
        }

        val sp: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        sp.edit().putString(KEY_SNAPSHOT, jsonStr).apply()

        // 触发所有已安装小组件的主动刷新
        triggerUpdateAll(context)
    }

    fun getSnapshot(context: Context): JSONObject? {
        val memoryCache = cachedSnapshot
        if (memoryCache != null) {
            return memoryCache
        }

        val sp: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val raw = sp.getString(KEY_SNAPSHOT, null) ?: return null
        return try {
            val parsed = JSONObject(raw)
            cachedSnapshot = parsed
            cachedRawJson = raw
            parsed
        } catch (e: Exception) {
            null
        }
    }

    fun triggerUpdateAll(context: Context) {
        val appWidgetManager = AppWidgetManager.getInstance(context)

        val smallComponent = ComponentName(context, SmallWidgetProvider::class.java)
        val smallIds = appWidgetManager.getAppWidgetIds(smallComponent)
        if (smallIds.isNotEmpty()) {
            SmallWidgetProvider.updateWidgets(context, appWidgetManager, smallIds)
        }

        val mediumComponent = ComponentName(context, MediumWidgetProvider::class.java)
        val mediumIds = appWidgetManager.getAppWidgetIds(mediumComponent)
        if (mediumIds.isNotEmpty()) {
            MediumWidgetProvider.updateWidgets(context, appWidgetManager, mediumIds)
        }

        val largeComponent = ComponentName(context, LargeWidgetProvider::class.java)
        val largeIds = appWidgetManager.getAppWidgetIds(largeComponent)
        if (largeIds.isNotEmpty()) {
            LargeWidgetProvider.updateWidgets(context, appWidgetManager, largeIds)
        }
    }

    /**
     * 安全提取 JSONObject 中的可空字符串，彻底规避 JSONObject.NULL 返回字面量 "null" 的问题
     */
    fun optNullableString(json: JSONObject?, key: String): String? {
        if (json == null || json.isNull(key)) return null
        val v = json.optString(key, "")
        return if (v.isEmpty() || v.equals("null", ignoreCase = true)) null else v
    }

    // ───────────────────────── 成员绑定读写 ─────────────────────────

    /**
     * 获取指定小组件独立绑定的屙屎人 ID。
     *
     * 返回 `null` 表示「跟随默认成员」—— 这是新装小组件的初始状态。
     */
    fun getWidgetPooperId(context: Context, appWidgetId: Int): String? {
        val sp = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val raw = sp.getString(KEY_PREFIX_WIDGET_POOPER + appWidgetId, null)
        return if (raw.isNullOrBlank() || raw.equals("null", ignoreCase = true)) null else raw
    }

    /** 为特定小组件绑定指定的屙屎人。 */
    fun setWidgetPooperId(context: Context, appWidgetId: Int, pooperId: String) {
        val sp = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        sp.edit().putString(KEY_PREFIX_WIDGET_POOPER + appWidgetId, pooperId).apply()
    }

    /** 清除绑定，让该小组件回退到「跟随默认成员」。 */
    fun clearWidgetPooperId(context: Context, appWidgetId: Int) {
        val sp = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        sp.edit().remove(KEY_PREFIX_WIDGET_POOPER + appWidgetId).apply()
    }

    /** 小组件尺寸类型标识，与 Flutter 侧管理页展示一一对应。 */
    private fun typeOf(provider: ComponentName): Pair<String, String> = when (provider.className) {
        SmallWidgetProvider::class.java.name -> "small" to "撕历打卡 (2×2)"
        MediumWidgetProvider::class.java.name -> "medium" to "手帐周历 (4×2)"
        else -> "large" to "家庭看板 (4×4)"
    }

    /**
     * 枚举桌面上所有已放置的小组件实例及其成员绑定。
     *
     * 供 Flutter 侧「桌面小组件」管理页使用 —— 用户不必删掉组件重加就能换人。
     */
    fun buildBindingsJson(context: Context): JSONArray {
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val snapshot = getSnapshot(context)
        val familyMembers = snapshot?.optJSONArray("familyMembers")
        val defaultPooper = snapshot?.optJSONObject("defaultPooper")

        val providers = listOf(
            ComponentName(context, SmallWidgetProvider::class.java),
            ComponentName(context, MediumWidgetProvider::class.java),
            ComponentName(context, LargeWidgetProvider::class.java),
        )

        val result = JSONArray()
        for (provider in providers) {
            val (type, label) = typeOf(provider)
            val ids = appWidgetManager.getAppWidgetIds(provider)
            for (id in ids) {
                val boundId = getWidgetPooperId(context, id)
                val boundMember = findMember(familyMembers, boundId)
                val effective = boundMember ?: defaultPooper

                result.put(
                    JSONObject().apply {
                        put("widgetId", id)
                        put("type", type)
                        put("typeLabel", label)
                        put("pooperId", boundId ?: JSONObject.NULL)
                        put("pooperName", effective?.optString("name", "我") ?: "我")
                        put("isFollowingDefault", boundId == null)
                    },
                )
            }
        }
        return result
    }

    private fun findMember(familyMembers: JSONArray?, id: String?): JSONObject? {
        if (familyMembers == null || id == null) return null
        for (i in 0 until familyMembers.length()) {
            val m = familyMembers.optJSONObject(i) ?: continue
            if (m.optString("id", "") == id) return m
        }
        return null
    }
}
