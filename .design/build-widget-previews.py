# -*- coding: utf-8 -*-
"""生成桌面小组件选择器预览图（previewImage 位图）。

Android 12+ 会用 `android:previewLayout` 把真实布局静态渲染成预览，不需要位图；
本脚本产出的 PNG 专门兜底 Android 11 及以下（以及部分不读 previewLayout 的启动器）。

**因此这里必须严格复刻三个布局里的尺寸、间距、字号与配色** ——
改布局就得同步改这里，否则低版本系统上看到的预览和真实小组件对不上。

用法：
    python .design/build-widget-previews.py
"""

from __future__ import annotations

import os

from PIL import Image, ImageDraw, ImageFont

# 每 dp 对应多少像素。3× 足够清晰，又不至于让 APK 体积失控。
SCALE = 3.0

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# 同一张图出两份：
#  · res/drawable-nodpi → Android 11 及以下的 previewImage 位图兜底
#  · assets/widget_previews → App 内「桌面小组件」管理页的预览卡片
RES_DIR = os.path.join(ROOT, "android", "app", "src", "main", "res", "drawable-nodpi")
ASSET_DIR = os.path.join(ROOT, "assets", "widget_previews")

# ── 配色：与 android/app/src/main/res/values/colors.xml 严格同源 ──
PAPER = "#FFFFFF"
SURFACE_2 = "#F5F2EF"
LINE = "#ECE6E0"
INK = "#1A1613"
INK_2 = "#5F5852"
INK_3 = "#8A817A"
BRAND_FILL = "#A85F29"
BRAND_INK = "#8F4A15"
BRAND_SOFT = "#FDF0E4"
WHITE = "#FFFFFF"
LIVE = "#2F7A4F"

# 头像色板（与 tokens.dart 的 kAvatarPalette 前三位一致）
AVATARS = [
    ("#F7E5D2", "#B4662F"),  # 焦糖
    ("#E1EDE5", "#3F7A57"),  # 苔绿
    ("#EFE4F1", "#8A5FA8"),  # 淡紫
]

FONT_CN = "C:/Windows/Fonts/msyh.ttc"
FONT_CN_BOLD = "C:/Windows/Fonts/msyhbd.ttc"
FONT_DISPLAY = os.path.join(ROOT, ".design", "fonts", "smiley", "SmileySans-Oblique.ttf")

_fonts: dict[tuple[str, int], ImageFont.FreeTypeFont] = {}


def font(path: str, dp: float) -> ImageFont.FreeTypeFont:
    key = (path, int(round(dp)))
    if key not in _fonts:
        _fonts[key] = ImageFont.truetype(path, max(1, int(round(dp * SCALE))))
    return _fonts[key]


def cn(dp: float, bold: bool = False) -> ImageFont.FreeTypeFont:
    return font(FONT_CN_BOLD if bold else FONT_CN, dp)


def display(dp: float) -> ImageFont.FreeTypeFont:
    """得意黑：主 App 的大数字都用它，小组件保持一致。"""
    return font(FONT_DISPLAY, dp)


def px(dp: float) -> float:
    return dp * SCALE


def stroke(dp: float) -> int:
    return max(1, int(round(dp * SCALE)))


class Canvas:
    """按 dp 坐标作画的薄封装，避免到处手写 px() 转换。"""

    def __init__(self, width_dp: float, height_dp: float):
        self.w = width_dp
        self.h = height_dp
        # 背景必须**不透明**。
        #
        # 之前用的是 RGBA 全透明 + save() 时 convert("RGB")，透明区在转换里
        # 被压成了纯黑 —— 于是启动器组件列表里每张预览图四角都是黑边。
        # 直接铺成卡片底色，让启动器自己去裁圆角（Android 12+ 会裁）。
        self.img = Image.new("RGB", (int(px(width_dp)), int(px(height_dp))), (255, 255, 255))
        self.d = ImageDraw.Draw(self.img)

    def card(self, x, y, w, h, radius, fill=PAPER, outline=None, width=1.0):
        self.d.rounded_rectangle(
            [px(x), px(y), px(x + w), px(y + h)],
            radius=px(radius),
            fill=fill,
            outline=outline,
            width=stroke(width) if outline else 0,
        )

    def text(self, x, y, s, f, fill, anchor="lm"):
        self.d.text((px(x), px(y)), s, font=f, fill=fill, anchor=anchor)

    def text_w(self, s, f) -> float:
        return self.d.textlength(s, font=f) / SCALE

    def avatar(self, x, y, size, initial, palette_index=0):
        bg, fg = AVATARS[palette_index % len(AVATARS)]
        self.card(x, y, size, size, size / 2.6, fill=bg)
        self.text(x + size / 2, y + size / 2 + 0.5, initial, cn(size * 0.46, True), fg, anchor="mm")

    def pill(self, x, y, label, f, fg, bg, pad_x=7.0, height=18.0, centered_text=True):
        w = self.text_w(label, f) + pad_x * 2
        self.card(x, y, w, height, 99, fill=bg)
        self.text(
            x + w / 2 if centered_text else x + pad_x,
            y + height / 2 + 0.5,
            label,
            f,
            fg,
            anchor="mm" if centered_text else "lm",
        )
        return w

    def chevron(self, cx, cy, color=INK_3, arm=4.0):
        self.d.line(
            [px(cx - arm), px(cy - arm / 2), px(cx), px(cy + arm / 2), px(cx + arm), px(cy - arm / 2)],
            fill=color,
            width=stroke(2.4),
            joint="curve",
        )

    def plus(self, cx, cy, arm, color=WHITE, width=2.0):
        self.d.line([px(cx - arm), px(cy), px(cx + arm), px(cy)], fill=color, width=stroke(width))
        self.d.line([px(cx), px(cy - arm), px(cx), px(cy + arm)], fill=color, width=stroke(width))

    def dot(self, cx, cy, r, color=BRAND_FILL):
        self.d.ellipse([px(cx - r), px(cy - r), px(cx + r), px(cy + r)], fill=color)

    def save(self, name: str):
        rgb = self.img.convert("RGB")
        for out_dir in (RES_DIR, ASSET_DIR):
            os.makedirs(out_dir, exist_ok=True)
            rgb.save(os.path.join(out_dir, name), "PNG", optimize=True)
        rel = os.path.relpath(os.path.join(RES_DIR, name), ROOT)
        print(f"  [ok] {rel}  ({rgb.width}x{rgb.height})  + assets/widget_previews/")


# ══════════════════════════════════════════════════════════════════
# 小号 2×2：155×155dp
# ══════════════════════════════════════════════════════════════════
def build_small() -> None:
    W, H = 155.0, 155.0
    pad = 14.0
    c = Canvas(W, H)
    c.card(0, 0, W, H, 0, fill=PAPER, outline=LINE, width=1)

    # ① 成员区。2×2 内容宽只有 127dp，放不下「姓名 + 次数胶囊 + 切换箭头」，
    #     所以布局里把次数与「多久之前」合并成成员区的第二行。
    #     下拉线紧跟姓名 —— 三款组件的换人暗示必须一致。
    c.avatar(pad, pad, 40, "我", 0)
    name_x = pad + 40 + 10
    name_f = cn(15, True)
    c.text(name_x, pad + 11, "我", name_f, INK)
    c.chevron(name_x + c.text_w("我", name_f) + 9, pad + 11, arm=3.5)
    c.text(name_x, pad + 30, "今日 2 次 · 4h前", cn(11), INK_3)

    # ② 日期区（中部弹性）
    mid_y = 155 - pad - 42 - 6  # 按钮顶边
    center_y = (pad + 40 + 4 + mid_y) / 2
    c.text(pad, center_y, "18", display(32), INK)
    c.text(pad + 42, center_y, "10月 · 周六", cn(12.5, True), INK_2)

    # ③ 主按钮
    btn_y = H - pad - 42
    c.card(pad, btn_y, W - pad * 2, 42, 99, fill=BRAND_FILL)
    btn_f = cn(13.5, True)
    label = "现在开屙"
    icon, gap = 17.0, 6.0
    total = icon + gap + c.text_w(label, btn_f)
    start_x = pad + (W - pad * 2 - total) / 2
    c.plus(start_x + icon / 2, btn_y + 21, 4.5)
    c.text(start_x + icon + gap, btn_y + 21, label, btn_f, WHITE)

    c.save("widget_preview_small.png")


# ══════════════════════════════════════════════════════════════════
# 中号 4×2：320×155dp
# ══════════════════════════════════════════════════════════════════
def build_medium() -> None:
    W, H = 320.0, 155.0
    pad = 12.0
    c = Canvas(W, H)
    c.card(0, 0, W, H, 0, fill=PAPER, outline=LINE, width=1)

    # ② 成员通栏：姓名紧跟一条下拉线，明确「点这里换人」
    c.avatar(pad, pad, 36, "我", 0)
    name_x = pad + 36 + 10
    name_f = cn(15, True)
    c.text(name_x, pad + 10, "我", name_f, INK)
    c.chevron(name_x + c.text_w("我", name_f) + 10, pad + 10, arm=3.5)
    c.text(name_x, pad + 28, "今日 2 次 · 上次 08:30 · 顺畅", cn(11), INK_3)

    streak_f = cn(10.5, True)
    streak_label = "连续顺畅 5 天"
    streak_w = c.text_w(streak_label, streak_f) + 16
    c.pill(W - pad - streak_w, pad + (36 - 18) / 2, streak_label, streak_f, BRAND_INK, BRAND_SOFT)

    # ② 分隔线
    divider_y = pad + 36 + 10
    c.d.line([px(pad), px(divider_y), px(W - pad), px(divider_y)], fill=LINE, width=stroke(1))

    body_top = divider_y + 1 + 8
    body_bottom = H - pad

    # ③ 左行动舱
    action_w = 104.0
    big = "4h"
    big_f = display(24)
    c.text(pad, body_top + 17, big, big_f, INK)
    c.text(pad + c.text_w(big, big_f) + 5, body_top + 17, "距上次", cn(10.5), INK_3)

    btn_h = 36.0
    btn_y = body_bottom - btn_h
    c.card(pad, btn_y, action_w, btn_h, 99, fill=BRAND_FILL)
    btn_f = cn(11.5, True)
    label = "现在开屙"
    total = 15.0 + 5.0 + c.text_w(label, btn_f)
    sx = pad + (action_w - total) / 2
    c.plus(sx + 7.5, btn_y + btn_h / 2, 4.0)
    c.text(sx + 20, btn_y + btn_h / 2, label, btn_f, WHITE)

    # ④ 竖分隔线
    sep_x = pad + action_w + 11
    c.d.line([px(sep_x), px(body_top), px(sep_x), px(body_bottom)], fill=LINE, width=stroke(1))

    # ⑤ 右侧 7 天周历
    cal_x = sep_x + 1 + 11
    cal_w = W - pad - cal_x
    col_w = cal_w / 7
    week_labels = ["一", "二", "三", "四", "五", "六", "日"]
    days = [12, 13, 14, 15, 16, 17, 18]
    marked = [True, True, True, True, False, False, True]

    label_y = body_top + 6
    cell_top = body_top + 14
    cell_h = body_bottom - cell_top
    for i in range(7):
        cx = cal_x + i * col_w
        is_today = i == 6
        if is_today:
            c.text(cx + col_w / 2, label_y, week_labels[i], cn(9, True), BRAND_INK, anchor="mm")
            c.card(cx + 1, cell_top, col_w - 2, cell_h, 12, fill=BRAND_SOFT, outline=BRAND_FILL, width=1.5)
        else:
            c.text(cx + col_w / 2, label_y, week_labels[i], cn(9), INK_3, anchor="mm")
            c.card(cx + 1, cell_top, col_w - 2, cell_h, 12, fill=SURFACE_2)

        num_f = display(11.5) if is_today else cn(11.5, True)
        num_color = BRAND_FILL if is_today else INK
        c.text(cx + col_w / 2, cell_top + cell_h / 2 - 3, str(days[i]), num_f, num_color, anchor="mm")
        if marked[i]:
            c.dot(cx + col_w / 2, cell_top + cell_h - 8, 2.5)

    c.save("widget_preview_medium.png")


# ══════════════════════════════════════════════════════════════════
# 大号 4×4：320×320dp
# ══════════════════════════════════════════════════════════════════
def build_large() -> None:
    W, H = 320.0, 320.0
    pad = 12.0
    c = Canvas(W, H)
    c.card(0, 0, W, H, 0, fill=PAPER, outline=LINE, width=1)

    # ① 标题栏：标题 + 成员胶囊 + 日期
    #
    # 标题行被 24dp 高的成员胶囊撑起来，所以行心在 pad + 12。
    header_center = pad + 12
    c.text(pad, header_center, "屙了么 · 家庭看板", cn(12.5, True), INK)

    date_label = "10月18日 周六"
    date_f = cn(10.5)
    date_w = c.text_w(date_label, date_f)
    c.text(W - pad - date_w, header_center, date_label, date_f, INK_3)

    # 成员胶囊（与 2×2 / 4×2 同款换人入口）
    cap_name = "我"
    cap_name_f = cn(11, True)
    cap_h = 24.0
    cap_w = 3 + 20 + 5 + c.text_w(cap_name, cap_name_f) + 14 + 7
    cap_x = W - pad - date_w - 8 - cap_w
    cap_y = header_center - cap_h / 2
    c.card(cap_x, cap_y, cap_w, cap_h, 99, fill=SURFACE_2)
    c.avatar(cap_x + 3, cap_y + 2, 20, cap_name, 0)
    c.text(cap_x + 3 + 20 + 5, header_center, cap_name, cap_name_f, INK)
    c.chevron(cap_x + cap_w - 7 - 7, header_center, arm=3.5)

    # ② 三行成员
    rows = [
        ("我", "今日 2 次 · 上次 14:15", "记一次", 0),
        ("咪", "今日 1 次 · 上次 07:20", "帮记", 1),
        ("宝", "昨天 19:40", "帮记", 2),
    ]
    # 高度预算很紧：4×4 标准只有 320dp 见方，要装下「标题 + 3 行成员 +
    # 小结卡 + 按钮」，所以成员行压到 40dp、头像 32dp。
    row_h = 40.0
    row_y = pad + cap_h + 8
    for name, status, btn, palette in rows:
        c.card(pad, row_y, W - pad * 2, row_h, 14, fill=SURFACE_2)
        c.avatar(pad + 8, row_y + (row_h - 32) / 2, 32, name, palette)
        text_x = pad + 8 + 32 + 9
        c.text(text_x, row_y + 8, name, cn(13.5, True), INK)
        c.text(text_x, row_y + 24, status, cn(10.5), INK_3)

        btn_f = cn(10.5, True)
        btn_w = c.text_w(btn, btn_f) + 20
        c.pill(W - pad - 8 - btn_w, row_y + (row_h - 21) / 2, btn, btn_f, BRAND_INK, BRAND_SOFT, pad_x=10, height=21)
        row_y += row_h + 5

    # ③ 本周小结 + 本周节律 + 一行便签
    #
    # 这里原来是一整块「最新便签速记」，占了近四成高度却常年空白。
    # 便签本身有用，但它是低频内容、还只读，不该占着最贵的位置。
    sum_top = row_y + 6
    sum_h = 13 + 4 + 17 + 4 + 12 + 14  # 小结行 + 节律带 + 便签行 + 内边距
    c.card(pad, sum_top, W - pad * 2, sum_h, 14, fill=SURFACE_2)

    inner_x = pad + 10
    inner_w = W - pad * 2 - 20
    cy = sum_top + 7

    c.text(inner_x, cy, "本周 12 次 · 6 天有记录 · 最勤 xiaojie", cn(11, True), INK)
    cy += 13 + 4

    # 本周节律：一格一天，「一3」= 周一 3 次，今天那格用品牌浅色高亮
    labels = ["一", "二", "三", "四", "五", "六", "日"]
    counts = [3, 5, 2, 4, 1, 6, 2]
    cell_gap = 3.0
    cell_w = (inner_w - cell_gap * 6) / 7
    for i, (lab, num) in enumerate(zip(labels, counts)):
        x = inner_x + i * (cell_w + cell_gap)
        is_today = i == len(labels) - 1
        c.card(x, cy, cell_w, 17, 6, fill=BRAND_SOFT if is_today else WHITE)
        c.text(
            x + cell_w / 2,
            cy + 8.5,
            f"{lab}{num}",
            cn(9, is_today),
            BRAND_INK if is_today else INK_3,
            anchor="mm",
        )
    cy += 17 + 4

    c.text(inner_x, cy, "我 · 14:15 · 喝完温水后排空，非常舒适顺畅。", cn(10.5), INK_2)
    c.text(W - pad - 10, cy + 2, "#顺畅", cn(9.5, True), BRAND_INK, anchor="rm")

    # ④ 底部三动作
    btn_h = 40.0
    btn_y = H - pad - btn_h
    inner = W - pad * 2
    gap = 7.0
    w1 = (inner - gap * 2) * 1.35 / 3.45
    w2 = (inner - gap * 2) * 1.0 / 3.45
    w3 = (inner - gap * 2) * 1.1 / 3.45

    c.card(pad, btn_y, w1, btn_h, 99, fill=BRAND_FILL)
    btn_f = cn(12, True)
    label = "极速开屙"
    total = 16.0 + 5.0 + c.text_w(label, btn_f)
    sx = pad + (w1 - total) / 2
    c.plus(sx + 8, btn_y + btn_h / 2, 4.0)
    c.text(sx + 21, btn_y + btn_h / 2, label, btn_f, WHITE)

    ghost_f = cn(11.5, True)
    x2 = pad + w1 + gap
    c.card(x2, btn_y, w2, btn_h, 99, fill=SURFACE_2)
    c.text(x2 + w2 / 2, btn_y + btn_h / 2, "补录便签", ghost_f, INK, anchor="mm")

    x3 = x2 + w2 + gap
    c.card(x3, btn_y, w3, btn_h, 99, fill=SURFACE_2)
    c.text(x3 + w3 / 2, btn_y + btn_h / 2, "打开日历", ghost_f, INK, anchor="mm")

    c.save("widget_preview_large.png")


def main() -> None:
    for path in (FONT_CN, FONT_CN_BOLD, FONT_DISPLAY):
        if not os.path.exists(path):
            raise SystemExit(f"缺少字体文件：{path}")

    print("Building widget picker previews...")
    build_small()
    build_medium()
    build_large()
    print(
        "Done. Android 11 and below use these bitmaps; "
        "Android 12+ renders the real layouts via android:previewLayout."
    )


if __name__ == "__main__":
    main()
