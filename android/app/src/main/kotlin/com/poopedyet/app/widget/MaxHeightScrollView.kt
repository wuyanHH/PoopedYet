package com.poopedyet.app.widget

import android.content.Context
import android.util.AttributeSet
import android.widget.ScrollView

/**
 * 可以限制最大高度、超出后内部滚动的 [ScrollView]。
 *
 * ## 为什么需要它
 *
 * 换人浮层的成员列表要「人少时自适应收缩、人多时封顶滚动」。
 * 平台 [ScrollView] 没有 `maxHeight` 这种属性，常见的绕法是：
 *
 * ```kotlin
 * list.post { scroll.layoutParams.height = min(contentHeight, maxHeight) }
 * ```
 *
 * 但那是**第二次布局**：第一帧先按内容铺满（可能比屏幕还高），
 * 紧接着 `post` 回来把它压回去 —— 用户看到的就是浮层"弹出来还抖一下"，
 * 在低端机上尤其明显，正是「打开换人弹窗很卡」的一部分来源。
 *
 * 这里把上限交给 `onMeasure`，一次测量就得到最终高度，
 * 中间不存在会被看见的中间态。
 */
class MaxHeightScrollView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0,
) : ScrollView(context, attrs, defStyleAttr) {

    /** 高度上限（px）。<= 0 表示不限制，按内容自适应。 */
    var maxHeightPx: Int = 0
        set(value) {
            if (field == value) return
            field = value
            requestLayout()
        }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        if (maxHeightPx <= 0) {
            super.onMeasure(widthMeasureSpec, heightMeasureSpec)
            return
        }
        val capped = MeasureSpec.makeMeasureSpec(maxHeightPx, MeasureSpec.AT_MOST)
        super.onMeasure(widthMeasureSpec, capped)
    }
}
