"""从截图里找出特定颜色的区域，反推 UI 元素的位置。

用途：设备端自动化验证时，`adb shell input tap` 需要精确坐标，
而 Flutter 画在 canvas 上、uiautomator 读不到界面结构。
靠猜坐标既慢又不可靠（我已经猜错过好几次）。

思路：品牌色 #A85F29 在界面上只出现在几个填充按钮上（完成 / 添加这条备注 / FAB），
把它们找出来取包围盒，就能反推整个布局。

用法：
    python find_regions.py <png> [RRGGBB ...]
"""
import sys
from collections import deque

from PIL import Image

# 容差：截图有缩放和抗锯齿，不会正好是 #A85F29
TOL = 14


def close(px, target):
    return all(abs(px[i] - target[i]) <= TOL for i in range(3))


def regions(img, target, min_area=200):
    """找出所有连通区域（4 邻域），返回包围盒。"""
    w, h = img.size
    pixels = img.load()
    seen = bytearray(w * h)
    out = []

    for y0 in range(h):
        for x0 in range(w):
            idx = y0 * w + x0
            if seen[idx]:
                continue
            if not close(pixels[x0, y0], target):
                continue

            # BFS
            q = deque([(x0, y0)])
            seen[idx] = 1
            minx = maxx = x0
            miny = maxy = y0
            n = 0
            while q:
                x, y = q.popleft()
                n += 1
                minx, maxx = min(minx, x), max(maxx, x)
                miny, maxy = min(miny, y), max(maxy, y)
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h:
                        ni = ny * w + nx
                        if not seen[ni] and close(pixels[nx, ny], target):
                            seen[ni] = 1
                            q.append((nx, ny))

            if n >= min_area:
                out.append((minx, miny, maxx, maxy, n))

    out.sort(key=lambda r: -r[4])
    return out


def main():
    path = sys.argv[1]
    targets = [tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
               for h in (sys.argv[2:] or ['A85F29'])]

    img = Image.open(path).convert('RGB')
    print(f'image {img.size[0]}x{img.size[1]}')

    for t in targets:
        hexc = '#%02X%02X%02X' % t
        rs = regions(img, t)
        print(f'\ncolor {hexc}: {len(rs)} regions (top 8 by area)')
        for minx, miny, maxx, maxy, n in rs[:8]:
            cx, cy = (minx + maxx) // 2, (miny + maxy) // 2
            print(f'  bbox=({minx},{miny})-({maxx},{maxy})  center=({cx},{cy})  size={maxx-minx+1}x{maxy-miny+1}  area={n}')


if __name__ == '__main__':
    main()
