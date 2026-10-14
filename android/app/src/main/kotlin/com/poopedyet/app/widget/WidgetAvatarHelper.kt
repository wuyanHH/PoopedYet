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
 * 彻底消除桌面小组件上成员头像展示为硬编码彩色 Emoji（如 🐶）的瑕疵，
 * 与 Flutter 端 [PooperAvatar] 的渲染逻辑 100% 对齐：
 *   1. 优先渲染用户上传的自定义真实头像照片（Base64 缩略图圆角裁剪）；
 *   2. 兜底渲染基于成员 ID 稳定推导的专属背景色 + 姓名首字（首字加粗居中），温润手帐质感。
 */
object WidgetAvatarHelper {

    /**
     * 生成与 Flutter 端 [PooperAvatar] 完全同源的圆角头像 Bitmap
     *
     * @param context 上下文
     * @param member 成员 JSON 数据（包含 avatarBase64, initial, colorBg, colorFg）
     * @param sizeDp 期望的输出尺寸（dp）
     */
    fun createAvatarBitmap(context: Context, member: JSONObject?, sizeDp: Int): Bitmap {
        val density = context.resources.displayMetrics.density
        val sizePx = (sizeDp * density).toInt().coerceAtLeast(24)
        val cornerRadius = sizePx / 2.6f

        val avatarBase64 = member?.optString("avatarBase64", "")?.takeIf { it.isNotBlank() && it != "null" }
        if (avatarBase64 != null) {
            try {
                val bytes = Base64.decode(avatarBase64, Base64.DEFAULT)
                val rawBitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                if (rawBitmap != null) {
                    return getRoundedBitmap(rawBitmap, sizePx, cornerRadius)
                }
            } catch (_: Exception) {}
        }

        // 兜底渲染：专属底色 + 姓名首字
        val initial = member?.optString("initial", "我")?.takeIf { it.isNotBlank() && it != "null" } ?: "我"
        val bgHex = member?.optString("colorBg", "#E8E2D9")?.takeIf { it.isNotBlank() && it != "null" } ?: "#E8E2D9"
        val fgHex = member?.optString("colorFg", "#5C4033")?.takeIf { it.isNotBlank() && it != "null" } ?: "#5C4033"

        val bgColor = safeParseColor(bgHex, Color.parseColor("#E8E2D9"))
        val fgColor = safeParseColor(fgHex, Color.parseColor("#5C4033"))

        val output = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)

        // 1. 绘制背景圆角
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = bgColor
            style = Paint.Style.FILL
        }
        val rectF = RectF(0f, 0f, sizePx.toFloat(), sizePx.toFloat())
        canvas.drawRoundRect(rectF, cornerRadius, cornerRadius, paint)

        // 2. 绘制微细边框
        val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#1F5E422A")
            style = Paint.Style.STROKE
            strokeWidth = density * 0.8f
        }
        canvas.drawRoundRect(rectF, cornerRadius, cornerRadius, strokePaint)

        // 3. 绘制居中首字
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
