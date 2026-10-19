package com.poopedyet.app.widget

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import com.poopedyet.app.R
import org.json.JSONObject

/**
 * 屙了么 · 桌面小组件「选择屙屎人」配置向导。
 *
 * 同一套界面服务两个入口：
 *
 * **① 添加到桌面时的系统配置流程**
 * 由 `android:configure` 声明拉起（系统会带上 `EXTRA_APPWIDGET_ID`）。
 * 系统约定：只要没有 `setResult(RESULT_OK)`，这次添加就作废，
 * 所以 [onCreate] 第一件事就是把自己标成 `RESULT_CANCELED` ——
 * 用户中途按返回键时，桌面上不会留下一个「没配好的」空组件。
 *
 * **② 点击已放置小组件的成员区**
 * 由小组件的 `PendingIntent` 原地拉起（同样带 `EXTRA_APPWIDGET_ID`），
 * 选完即刻刷新，用户不需要「删掉再重新添加」。
 *
 * 「跟随默认成员」这一项**永远可用**：即便 App 从未启动过、跨进程快照还是空的，
 * 也能先把小组件放到桌面上，等 App 跑起来再回来细化。
 */
class WidgetConfigActivity : Activity() {

    /** 当前正在配置的小组件实例 ID。 */
    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 系统约定：配置未成功前一律按「取消」处理，避免留下未配置的空组件。
        setResult(RESULT_CANCELED)

        appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            // 极少数启动器不传 appWidgetId，此时无法绑定，直接退出并提示。
            Toast.makeText(this, "无法识别小组件实例，请重新添加", Toast.LENGTH_SHORT).show()
            finish()
            return
        }

        setContentView(R.layout.widget_config)
        findViewById<TextView>(R.id.config_btn_cancel).setOnClickListener { finish() }
        renderMemberList()
    }

    /**
     * 渲染成员选择列表。
     *
     * 数据来自 Flutter 侧同步过来的跨进程快照（`familyMembers`）；
     * 快照为空时不报错、不阻塞，只把「跟随默认成员」这条路留通。
     */
    private fun renderMemberList() {
        val listContainer = findViewById<LinearLayout>(R.id.config_member_list)
        val inflater = LayoutInflater.from(this)

        val snapshot = WidgetDataProvider.getSnapshot(this)
        val familyMembers = snapshot?.optJSONArray("familyMembers")
        val defaultPooper = snapshot?.optJSONObject("defaultPooper")
        val boundPooperId = WidgetDataProvider.getWidgetPooperId(this, appWidgetId)

        // ① 「跟随默认成员」—— 绑定为 null，运行时回退到 App 里的默认屙屎人。
        val defaultName = defaultPooper?.optString("name", "")?.takeIf { it.isNotBlank() }
        val followDesc = if (defaultName != null) {
            "跟随 App 设置 · 当前是「$defaultName」"
        } else {
            "跟随 App 里设置的默认成员"
        }
        listContainer.addView(
            buildMemberRow(
                inflater = inflater,
                parent = listContainer,
                member = null,
                name = "跟随默认成员",
                desc = followDesc,
                selected = boundPooperId == null,
            ) {
                WidgetDataProvider.clearWidgetPooperId(this, appWidgetId)
                finishWithSuccess()
            },
        )

        // ② 具体的家庭成员。
        //
        // 归档的人不再出现在可选项里 —— 唯一例外是「当前正绑着他」：
        // 那种情况必须显式展示并置灰，否则用户会看到一个没有任何选中项的
        // 列表，只会以为界面坏了。
        if (familyMembers != null && familyMembers.length() > 0) {
            for (i in 0 until familyMembers.length()) {
                val member = familyMembers.optJSONObject(i) ?: continue
                val id = member.optString("id", "")
                if (id.isEmpty()) continue

                val isArchived = member.optBoolean("isArchived", false)
                if (isArchived && id != boundPooperId) continue

                val todayCount = member.optInt("todayCount", 0)
                val lastTime = WidgetDataProvider.optNullableString(member, "lastTimeStr")
                val desc = if (isArchived) {
                    "已归档 · 换选下面任意一位即可替换"
                } else {
                    when {
                        todayCount > 0 && lastTime != null -> "今日 $todayCount 次 · 上次 $lastTime"
                        todayCount > 0 -> "今日 $todayCount 次"
                        lastTime != null -> "今天还没有 · 上次 $lastTime"
                        else -> "还没有任何记录"
                    }
                }

                listContainer.addView(
                    buildMemberRow(
                        inflater = inflater,
                        parent = listContainer,
                        member = member,
                        name = member.optString("name", "我"),
                        desc = desc,
                        selected = id == boundPooperId,
                        archived = isArchived,
                    ) {
                        WidgetDataProvider.setWidgetPooperId(this, appWidgetId, id)
                        finishWithSuccess()
                    },
                )
            }
        } else {
            findViewById<TextView>(R.id.config_hint).apply {
                visibility = View.VISIBLE
                text = "还没读到家庭成员数据。先选「跟随默认成员」也能正常用；" +
                    "打开一次屙了么之后，这里就会列出全部成员。"
            }
        }

        // 成员不多时让浮层自适应收缩，成员多时限制最大高度并内部滚动。
        val scroll = findViewById<ScrollView>(R.id.config_scroll)
        listContainer.post {
            val maxHeight = (resources.displayMetrics.heightPixels * 0.46f).toInt()
            val contentHeight = listContainer.height
            scroll.layoutParams = scroll.layoutParams.apply {
                height = if (contentHeight > maxHeight) maxHeight else ViewGroup.LayoutParams.WRAP_CONTENT
            }
        }
    }

    /** 构建一行成员选择项（含头像、姓名、今日状态、选中勾）。 */
    private fun buildMemberRow(
        inflater: LayoutInflater,
        parent: ViewGroup,
        member: JSONObject?,
        name: String,
        desc: String,
        selected: Boolean,
        archived: Boolean = false,
        onClick: () -> Unit,
    ): View {
        val row = inflater.inflate(R.layout.item_widget_config_member, parent, false)

        row.setBackgroundResource(
            if (selected) R.drawable.bg_member_row_selected else R.drawable.bg_member_row,
        )

        val avatar = row.findViewById<ImageView>(R.id.item_member_avatar)
        if (member != null) {
            avatar.setImageBitmap(WidgetAvatarHelper.createAvatarBitmap(this, member, 44))
        } else {
            // 「跟随默认成员」用中性人形图标，避免误以为是某个具体成员。
            avatar.setImageResource(R.drawable.ic_widget_avatar_placeholder)
        }

        row.findViewById<TextView>(R.id.item_member_name).text = name
        row.findViewById<TextView>(R.id.item_member_desc).text = desc
        row.findViewById<ImageView>(R.id.item_member_check).visibility =
            if (selected) View.VISIBLE else View.INVISIBLE

        // 已归档却仍被绑着的那一项置灰：能看见、能认清是谁，但不该显得可选。
        if (archived) {
            row.alpha = 0.45f
        }

        row.setOnClickListener { onClick() }
        return row
    }

    /** 保存完成：刷新桌面上所有小组件，并按系统约定回传 `RESULT_OK`。 */
    private fun finishWithSuccess() {
        WidgetDataProvider.triggerUpdateAll(this)
        setResult(
            RESULT_OK,
            Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId),
        )
        finish()
    }
}
