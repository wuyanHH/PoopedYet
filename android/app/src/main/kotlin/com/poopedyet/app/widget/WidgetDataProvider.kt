package com.poopedyet.app.widget

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.SharedPreferences
import org.json.JSONObject

/**
 * 桌面小组件跨进程数据与持久化管理 (带内存级高速快照缓存)
 */
object WidgetDataProvider {
    private const val PREFS_NAME = "pooped_yet_widget_pref"
    private const val KEY_SNAPSHOT = "key_snapshot"

    @Volatile
    private var cachedSnapshot: JSONObject? = null
    @Volatile
    private var cachedRawJson: String? = null

    fun saveSnapshot(context: Context, jsonStr: String) {
        // 先快速更新内存缓存，消除多组件并发读取时的 I/O 与反序列化开销
        try {
            cachedSnapshot = JSONObject(jsonStr)
            cachedRawJson = jsonStr
        } catch (_: Exception) {}

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

        // 刷新小号组件
        val smallComponent = ComponentName(context, SmallWidgetProvider::class.java)
        val smallIds = appWidgetManager.getAppWidgetIds(smallComponent)
        if (smallIds.isNotEmpty()) {
            SmallWidgetProvider.updateWidgets(context, appWidgetManager, smallIds)
        }

        // 刷新中号组件
        val mediumComponent = ComponentName(context, MediumWidgetProvider::class.java)
        val mediumIds = appWidgetManager.getAppWidgetIds(mediumComponent)
        if (mediumIds.isNotEmpty()) {
            MediumWidgetProvider.updateWidgets(context, appWidgetManager, mediumIds)
        }

        // 刷新大号组件 (4×4)
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

    /**
     * 根据成员的 iconKey 精确映射对应的头像 Emoji 字符，彻底杜绝小狗写死
     */
    fun getPooperEmoji(iconKey: String?): String {
        return when (iconKey?.lowercase()) {
            "cat" -> "🐱"
            "dog" -> "🐶"
            "rabbit" -> "🐰"
            "bird" -> "🐦"
            "turtle" -> "🐢"
            "fish" -> "🐟"
            "ghost" -> "👻"
            "star" -> "⭐"
            "crown" -> "👑"
            "rocket" -> "🚀"
            "leaf" -> "🍃"
            "zap" -> "⚡"
            "heart" -> "💖"
            "sun" -> "☀️"
            "moon" -> "🌙"
            "baby" -> "👶"
            "user" -> "👤"
            "smile" -> "😊"
            "sparkles" -> "✨"
            else -> "👤"
        }
    }

    private const val KEY_PREFIX_WIDGET_POOPER = "widget_pooper_"

    /**
     * 获取指定小组件独立绑定的屙屎人 ID（未特别绑定则返回 null，回退使用默认成员）
     */
    fun getWidgetPooperId(context: Context, appWidgetId: Int): String? {
        val sp = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return optNullableString(JSONObject().apply {
            put("id", sp.getString(KEY_PREFIX_WIDGET_POOPER + appWidgetId, null))
        }, "id")
    }

    /**
     * 为特定小组件绑定指定的屙屎人 ID
     */
    fun setWidgetPooperId(context: Context, appWidgetId: Int, pooperId: String) {
        val sp = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        sp.edit().putString(KEY_PREFIX_WIDGET_POOPER + appWidgetId, pooperId).apply()
    }

    /**
     * 原地轮换切换该小组件绑定的下一个屙屎人
     */
    fun cycleNextPooper(context: Context, appWidgetId: Int): String? {
        val snapshot = getSnapshot(context) ?: return null
        val familyMembers = snapshot.optJSONArray("familyMembers") ?: return null
        if (familyMembers.length() == 0) return null

        val currentPooperId = getWidgetPooperId(context, appWidgetId)
            ?: snapshot.optJSONObject("defaultPooper")?.optString("id", "")

        var currentIndex = -1
        for (i in 0 until familyMembers.length()) {
            val m = familyMembers.optJSONObject(i)
            if (m?.optString("id", "") == currentPooperId) {
                currentIndex = i
                break
            }
        }

        val nextIndex = (currentIndex + 1) % familyMembers.length()
        val nextMember = familyMembers.optJSONObject(nextIndex)
        val nextId = nextMember?.optString("id", "") ?: return null

        setWidgetPooperId(context, appWidgetId, nextId)
        return nextId
    }
}
