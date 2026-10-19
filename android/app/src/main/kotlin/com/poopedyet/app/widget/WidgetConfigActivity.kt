package com.poopedyet.app.widget

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.animation.DecelerateInterpolator
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.poopedyet.app.R
import org.json.JSONObject

/**
 * 屙了么 · 桌面小组件「选择屙屎人」浮层。
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
 * 由 `WidgetConfigFloatActivity` 这个 **activity-alias** 拉起，跑在独立的空
 * affinity 任务里。为什么必须隔离，见 `AndroidManifest.xml` 里那段注释：
 * 不隔离的话换人会把整个 App 一起拽到前台。
 *
 * 「跟随默认成员」这一项**永远可用**：即便 App 从未启动过、跨进程快照还是空的，
 * 也能先把小组件放到桌面上，等 App 跑起来再回来细化。
 *
 * ## 观感上的三条硬要求（v1.1.2 重做）
 *
 * 1. **有动画**：整窗遮罩由主题里的 `windowAnimationStyle` 淡入，
 *    卡片再由 [playEnterAnimation] 从下方 26dp 处上滑淡入 —— 两段叠加成
 *    「桌面渐暗 + 卡片浮上来」的现代 bottom sheet 手感。
 * 2. **不卡**：成员头像走 [WidgetAvatarHelper.loadAvatarAsync]，
 *    列表首帧不再被十几次 base64 解码堵住。
 * 3. **不抖**：列表高度交给 `MaxHeightScrollView` 在 `onMeasure` 里一次算完，
 *    去掉了旧实现那句 `post { layoutParams.height = ... }` —— 那会让浮层
 *    先铺满再缩回去，看起来就是「弹出来还跳一下」。
 */
class WidgetConfigActivity : Activity() {

    /** 当前正在配置的小组件实例 ID。 */
    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    /** 入场动画只播一次：onNewIntent 换人时不该再滑一遍。 */
    private var enterAnimationPlayed = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 系统约定：配置未成功前一律按「取消」处理，避免留下未配置的空组件。
        setResult(RESULT_CANCELED)

        val id = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        if (id == AppWidgetManager.INVALID_APPWIDGET_ID) {
            // 极少数启动器不传 appWidgetId，此时无法绑定，直接退出并提示。
            Toast.makeText(this, "无法识别小组件实例，请重新添加", Toast.LENGTH_SHORT).show()
            finish()
            return
        }
        appWidgetId = id

        setContentView(R.layout.widget_config)
        applySystemBarInsets()

        findViewById<TextView>(R.id.config_btn_cancel).setOnClickListener { finish() }
        // 点遮罩空白处等同于取消 —— 不这样的话用户只能去找那颗「取消」按钮。
        findViewById<View>(R.id.config_scrim_touch).setOnClickListener { finish() }

        renderMemberList()
    }

    override fun onResume() {
        super.onResume()
        // 入场动画放在 onResume 才播：onCreate 时窗口往往还没真正可见，
        // 在那里 start 动画会白白跑掉大半段，用户看到的就是"没有动画"。
        playEnterAnimation()
    }

    /**
     * 浮层已经在屏幕上时，用户又点了另一个组件的成员区。
     *
     * 别名声明成 `singleInstance`，所以系统会复用这个实例并回调到这里；
     * 换掉目标实例、重画列表即可，不新建 Activity、不重播入场动画。
     */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        val id = intent.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID
        if (id == AppWidgetManager.INVALID_APPWIDGET_ID) return

        appWidgetId = id
        renderMemberList()
    }

    /**
     * 让卡片避开状态栏 / 导航栏。
     *
     * 遮罩是刻意铺满整屏的（包括状态栏区域），但卡片不能贴到导航栏底下 ——
     * 三键导航的机型上「取消」按钮会被系统手势条压住，点都点不到。
     *
     * 用 `systemWindowInsetBottom` 而不是 `WindowInsetsCompat.Type.systemBars()`：
     * 后者要 androidx.core 1.5+，而本工程的 androidx 版本是从各 Flutter 插件
     * 传递上来的、并没有在 build.gradle 里钉死。这两个读数在所有 API 上等价，
     * 没必要为一个 inset 去绑定库版本。
     */
    @Suppress("DEPRECATION")
    private fun applySystemBarInsets() {
        val root = findViewById<View>(R.id.config_root) ?: return
        val card = findViewById<View>(R.id.config_card) ?: return
        val baseBottomMargin = (card.layoutParams as? FrameLayout.LayoutParams)?.bottomMargin ?: 0

        ViewCompat.setOnApplyWindowInsetsListener(root) { _, insets ->
            val lp = card.layoutParams as? FrameLayout.LayoutParams
            if (lp != null) {
                val target = baseBottomMargin + insets.systemWindowInsetBottom
                if (lp.bottomMargin != target) {
                    lp.bottomMargin = target
                    card.layoutParams = lp
                }
            }
            insets
        }
        ViewCompat.requestApplyInsets(root)
    }

    /** 卡片从下方 26dp 处上滑 + 淡入；遮罩的淡入由主题转场负责。 */
    private fun playEnterAnimation() {
        if (enterAnimationPlayed) return
        enterAnimationPlayed = true

        val card = findViewById<View>(R.id.config_card) ?: return
        card.translationY = 26f * resources.displayMetrics.density
        card.alpha = 0f
        card.animate()
            .translationY(0f)
            .alpha(1f)
            .setStartDelay(40L)
            .setDuration(280L)
            .setInterpolator(DecelerateInterpolator(1.8f))
            .start()
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

        // singleInstance 复用时会重画，先把上一轮的行清掉。
        listContainer.removeAllViews()

        // 高度上限提前交给 ScrollView 的 onMeasure，避免第二次布局导致的跳动。
        findViewById<MaxHeightScrollView>(R.id.config_scroll)?.maxHeightPx =
            (resources.displayMetrics.heightPixels * 0.40f).toInt()

        val snapshot = WidgetDataProvider.getSnapshot(this)
        val familyMembers = snapshot?.optJSONArray("familyMembers")
        val defaultPooper = snapshot?.optJSONObject("defaultPooper")
        val boundPooperId = WidgetDataProvider.getWidgetPooperId(this, appWidgetId)

        val hint = findViewById<TextView>(R.id.config_hint)

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
        var rendered = 0
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
                rendered++
            }
        }

        if (rendered == 0) {
            // 空快照、或者成员全被归档、或者只剩一个「跟随默认」可选项时，
            // 给一句人话解释，而不是让用户对着一个孤零零的列表发愣。
            hint.visibility = View.VISIBLE
            hint.text = "还没读到可用的家庭成员。先选「跟随默认成员」也能正常用；" +
                "打开一次屙了么之后，这里就会列出全部成员。"
        } else {
            hint.visibility = View.GONE
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
            bindAvatar(avatar, member)
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

    /**
     * 头像异步填充。
     *
     * 主线程只做「查缓存 → 命中就换上、没命中先挂占位图」，
     * 真正的 base64 解码 + 圆角裁剪全在后台线程做完再回主线程 setImageBitmap。
     * 成员一多时，这一条就是「打开换人弹窗不再卡一下」的关键。
     */
    private fun bindAvatar(avatar: ImageView, member: JSONObject) {
        avatar.setImageResource(R.drawable.ic_widget_avatar_placeholder)
        WidgetAvatarHelper.loadAvatarAsync(this, member, 44) { bitmap ->
            if (isFinishing || isDestroyed) return@loadAvatarAsync
            avatar.setImageBitmap(bitmap)
        }
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
