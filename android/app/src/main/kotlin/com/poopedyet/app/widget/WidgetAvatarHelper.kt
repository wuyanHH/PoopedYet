package com.poopedyet.app.widget

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Typeface
import android.util.Base64
import org.json.JSONObject

/**
 * 桌面小组件真实头像生成辅助工具。
 *
 * 与 Flutter 端 `PooperAvatar` 的**三层兜底**逐层对齐：
 *
 *   1. 用户上传的照片（`avatarBase64`，96px 缩略图，圆角裁剪 + centerCrop）；
 *   2. **内置 Lucide 图标**（`iconKey` → `drawable/ic_pooper_*.xml` 矢量图，
 *      用 `setTint` 染成该成员的专属前景色）；
 *   3. 姓名首字 + 由成员 ID 稳定推导的专属背景色。
 *
 * ⚠ 第 2 层曾经是缺失的：小组件只做了「照片 → 首字」，
 * 于是给成员设了小狗图标的用户，在桌面上看到的是一个「X」色块。
 *
 * 图标资源由 `.design/build-widget-avatar-icons.py` 从 Lucide SVG 生成，
 * 与 `pooper_icons.dart` 的 key 一一对应（camelCase → snake_case）。
 */
object WidgetAvatarHelper {

    /** `iconKey` → drawable 资源 id 的缓存；0 表示找过但没有。 */
    private val iconResIdCache = HashMap<String, Int>()

    /**
     * 生成与 Flutter 端 `PooperAvatar` 同源的圆角头像 Bitmap。
     *
     * @param context 上下文
     * @param member 成员 JSON 数据（`avatarBase64` / `iconKey` / `initial` / `colorBg` / `colorFg`）
     * @param sizeDp 期望的输出尺寸（dp）
     */
    fun createAvatarBitmap(context: Context, member: JSONObject?, sizeDp: Int): Bitmap {
        val density = context.resources.displayMetrics.density
        val sizePx = (sizeDp * density).toInt().coerceAtLeast(24)
        val cornerRadius = sizePx / 2.6f

        // ── 第 1 层：用户上传的照片 ──
        val avatarBase64 = member?.optString("avatarBase64", "")
            ?.takeIf { it.isNotBlank() && it != "null" }
        if (avatarBase64 != null) {
            try {
                val bytes = Base64.decode(avatarBase64, Base64.DEFAULT)
                val rawBitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                if (rawBitmap != null) {
                    return getRoundedBitmap(rawBitmap, sizePx, cornerRadius)
                }
            } catch (_: Exception) {
                // 解码失败就继续往下走兜底，不要因为一张坏图整块空白
            }
        }

        val iconKey = member?.optString("iconKey", "")
            ?.takeIf { it.isNotBlank() && it != "null" }
        val initial = member?.optString("initial", "我")
            ?.takeIf { it.isNotBlank() && it != "null" } ?: "我"
        val bgHex = member?.optString("colorBg", "#E8E2D9")
            ?.takeIf { it.isNotBlank() && it != "null" } ?: "#E8E2D9"
        val fgHex = member?.optString("colorFg", "#5C4033")
            ?.takeIf { it.isNotBlank() && it != "null" } ?: "#5C4033"

        val bgColor = safeParseColor(bgHex, Color.parseColor("#E8E2D9"))
        val fgColor = safeParseColor(fgHex, Color.parseColor("#5C4033"))

        val output = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)

        // 底色圆角 + 微细边框（与 Flutter 端 0x145E422A 的描边同源）
        val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = bgColor
            style = Paint.Style.FILL
        }
        val rectF = RectF(0f, 0f, sizePx.toFloat(), sizePx.toFloat())
        canvas.drawRoundRect(rectF, cornerRadius, cornerRadius, fillPaint)

        val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#1F5E422A")
            style = Paint.Style.STROKE
            strokeWidth = density * 0.8f
        }
        canvas.drawRoundRect(rectF, cornerRadius, cornerRadius, strokePaint)

        // ── 第 2 层：内置 Lucide 图标 ──
        if (iconKey != null && drawPooperIcon(context, canvas, iconKey, sizePx, fgColor)) {
            return output
        }

        // ── 第 3 层：姓名首字 ──
        val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = fgColor
            textSize = sizePx * 0.48f
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            textAlign = Paint.Align.CENTER
        }
        val fontMetrics = textPaint.fontMetrics
        val baseline = (sizePx - fontMetrics.bottom - fontMetrics.top) / 2f
        canvas.drawText(initial.take(1), sizePx / 2f, baseline, textPaint)

        return output
    }

    /**
     * 把内置图标画进头像里。
     *
     * 返回 false 表示这个 iconKey 没有对应资源（老版本存过的奇怪 key、
     * 或者图标库升级删掉的图标），调用方应回退到姓名首字。
     */
    private fun drawPooperIcon(
        context: Context,
        canvas: Canvas,
        iconKey: String,
        sizePx: Int,
        color: Int,
    ): Boolean {
        val resId = pooperIconResId(context, iconKey)
        if (resId == 0) return false

        val drawable = context.getDrawable(resId) ?: return false
        // mutate 之后再染色：矢量图默认共享 ConstantState，
        // 不 mutate 会把颜色串到别处去。
        val tinted = drawable.mutate()
        tinted.setTint(color)

        val iconSize = (sizePx * 0.48f).toInt()
        val left = (sizePx - iconSize) / 2
        tinted.setBounds(left, left, left + iconSize, left + iconSize)
        tinted.draw(canvas)
        return true
    }

    /** 查 `ic_pooper_<snake_case>` 资源；查不到返回 0 并缓存，避免反复反射查找。 */
    private fun pooperIconResId(context: Context, iconKey: String): Int {
        iconResIdCache[iconKey]?.let { return it }
        val resId = context.resources.getIdentifier(
            "ic_pooper_${camelToSnake(iconKey)}",
            "drawable",
            context.packageName,
        )
        iconResIdCache[iconKey] = resId
        return resId
    }

    /** partyPopper → party_popper，与生成脚本的命名规则一致。 */
    private fun camelToSnake(value: String): String =
        value.replace(Regex("([a-z0-9])([A-Z])"), "$1_$2").lowercase()

    private fun getRoundedBitmap(source: Bitmap, targetSize: Int, cornerRadius: Float): Bitmap {
        val output = Bitmap.createBitmap(targetSize, targetSize, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)

        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        val rectF = RectF(0f, 0f, targetSize.toFloat(), targetSize.toFloat())
        canvas.drawRoundRect(rectF, cornerRadius, cornerRadius, paint)

        paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)

        // 居中按比例填满（Center Crop）
        val srcRect = Rect()
        if (source.width > source.height) {
            val offset = (source.width - source.height) / 2
            srcRect.set(offset, 0, offset + source.height, source.height)
        } else {
            val offset = (source.height - source.width) / 2
            srcRect.set(0, offset, source.width, offset + source.width)
        }
        val dstRect = Rect(0, 0, targetSize, targetSize)
        canvas.drawBitmap(source, srcRect, dstRect, paint)

        return output
    }

    private fun safeParseColor(hex: String, defaultColor: Int): Int {
        return try {
            Color.parseColor(if (hex.startsWith("#")) hex else "#$hex")
        } catch (_: Exception) {
            defaultColor
        }
    }
}
