# -*- coding: utf-8 -*-
"""把 Lucide SVG 转成 Android VectorDrawable，供桌面小组件绘制成员内置图标头像。

## 为什么要做这一步

主 App 的头像是**三层兜底**（见 `pooper_avatar.dart`）：

    用户上传的照片  →  内置 Lucide 图标（iconKey）  →  姓名首字

而桌面小组件是 Kotlin 画的，之前只实现了「照片 → 首字」两层 ——
于是给成员设了小狗图标的用户，桌面上看到的是一个「X」色块。
这正是「小组件头像不对」的根因。

## 为什么不干脆在 Flutter 侧渲染成 PNG

那样快照会膨胀（每位成员一张 base64），而且每次改头像都要走一遍
Flutter 渲染管线。Lucide 本来就是矢量，转成 VectorDrawable 交给
系统绘制更清晰、更省、也离得开 Flutter 引擎。

用法：
    python .design/build-widget-avatar-icons.py
"""

from __future__ import annotations

import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SVG_DIR = os.path.join(ROOT, ".design", "icons", "svg")
OUT_DIR = os.path.join(ROOT, "android", "app", "src", "main", "res", "drawable")

# iconKey（与 lib/src/theme/pooper_icons.dart 完全一致）→ Lucide SVG 文件名
ICON_MAP = {
    # ---- 精选：角色与家庭 ----
    "user": "user",
    "users": "users",
    "heart": "heart",
    "crown": "crown",
    # ---- 精选：萌宠与动物 ----
    "dog": "dog",
    "cat": "cat",
    "rabbit": "rabbit",
    "bird": "bird",
    "fish": "fish",
    # ---- 精选：治愈与生活符号 ----
    "sun": "sun",
    "moon": "moon",
    "star": "star",
    "coffee": "coffee",
    "flame": "flame",
    "leaf": "leaf",
    # ---- 历史兼容（老用户可能存过这些 key）----
    "turtle": "turtle",
    "snail": "snail",
    "squirrel": "squirrel",
    "bug": "bug",
    "ghost": "ghost",
    "rocket": "rocket",
    "droplet": "droplet",
    "zap": "zap",
    "milk": "milk",
    "pizza": "pizza",
    "utensils": "utensils",
    "partyPopper": "party-popper",
    "briefcase": "briefcase",
    "graduationCap": "graduation-cap",
    "plane": "plane",
    "home": "home",
    "mapPin": "map-pin",
    "stickyNote": "sticky-note",
    "play": "play",
    "square": "square",
    "wind": "wind",
    "bed": "bed",
    "bath": "bath",
    "smartphone": "smartphone",
    "palette": "palette",
}

PATH_RE = re.compile(r'<path[^>]*\sd="([^"]+)"', re.S)
RECT_RE = re.compile(r"<rect[^>]*/>", re.S)
# Lucide 统一的描边风格（见任一 svg 的根节点属性）。
STROKE_WIDTH = "2"


def camel_to_snake(name: str) -> str:
    """partyPopper → party_popper，与 Kotlin 侧 getIdentifier 的查找规则一致。"""
    return re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", name).lower()


def _rect_attr(tag: str, name: str) -> float | None:
    match = re.search(rf'\b{name}="([^"]+)"', tag)
    return float(match.group(1)) if match else None


def rect_to_path(tag: str) -> str | None:
    """把 `<rect>` 转成等价的 path。

    只有 `square` 这个图标用了 rect（Lucide 里其他图标都是 path）。
    直角近似 —— 圆角 rx 在 24dp 的描边风格下肉眼分不出来。
    """
    width = _rect_attr(tag, "width")
    height = _rect_attr(tag, "height")
    if width is None or height is None:
        return None
    x = _rect_attr(tag, "x") or 0.0
    y = _rect_attr(tag, "y") or 0.0
    return f"M{x},{y}h{width}v{height}h{-width}z"


def build_vector(svg_text: str) -> list[str]:
    """抽出 SVG 里所有 path 的 d 属性（rect 会先被转成 path）。"""
    paths = PATH_RE.findall(svg_text)
    for tag in RECT_RE.findall(svg_text):
        converted = rect_to_path(tag)
        if converted:
            paths.append(converted)
    return paths


def render_vector_xml(icon_key: str, paths: list[str]) -> str:
    """拼出 VectorDrawable。

    描边色写死成黑色，运行时用 `Drawable.setTint(fg)` 染成该成员的专属前景色 ——
    这样一份资源能被所有配色复用，不必为每个成员生成一张图。
    """
    body = "\n".join(
        "    <path\n"
        '        android:fillColor="#00000000"\n'
        f'        android:pathData="{d}"\n'
        '        android:strokeColor="#FF000000"\n'
        '        android:strokeLineCap="round"\n'
        '        android:strokeLineJoin="round"\n'
        f'        android:strokeWidth="{STROKE_WIDTH}" />'
        for d in paths
    )
    return (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        "<!-- 由 .design/build-widget-avatar-icons.py 从 Lucide SVG 生成，请勿手改。\n"
        f"     源：.design/icons/svg/{ICON_MAP[icon_key]}.svg（lucide-static，ISC 许可）。\n"
        "     桌面小组件用它绘制成员的内置图标头像；描边色由 setTint 在运行时决定。 -->\n"
        '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
        '    android:width="24dp"\n'
        '    android:height="24dp"\n'
        '    android:viewportWidth="24"\n'
        '    android:viewportHeight="24">\n'
        f"{body}\n"
        "</vector>\n"
    )


def main() -> None:
    if not os.path.isdir(SVG_DIR):
        raise SystemExit(f"缺少 Lucide SVG 目录：{SVG_DIR}")

    os.makedirs(OUT_DIR, exist_ok=True)

    written = 0
    skipped: list[str] = []
    for icon_key, svg_name in sorted(ICON_MAP.items()):
        svg_path = os.path.join(SVG_DIR, f"{svg_name}.svg")
        if not os.path.exists(svg_path):
            skipped.append(f"{icon_key}（缺 {svg_name}.svg）")
            continue

        with open(svg_path, encoding="utf-8") as f:
            paths = build_vector(f.read())
        if not paths:
            skipped.append(f"{icon_key}（没有解析到 path）")
            continue

        out_name = f"ic_pooper_{camel_to_snake(icon_key)}.xml"
        with open(os.path.join(OUT_DIR, out_name), "w", encoding="utf-8") as f:
            f.write(render_vector_xml(icon_key, paths))
        written += 1

    print(f"生成 {written} 个成员头像矢量图 -> android/app/src/main/res/drawable/ic_pooper_*.xml")
    if skipped:
        print("跳过：")
        for item in skipped:
            print("  -", item)


if __name__ == "__main__":
    main()
