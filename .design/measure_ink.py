"""测量一块区域里"墨迹"（深色像素）的包围盒。

用途：验证字体/字号改动**真的生效了**。

为什么需要：Flutter 画在 canvas 上，`uiautomator` 读不到文字，
而我（agent）看不了图。改字体前后各截一张、量同一块区域的墨迹宽度，
就能用数字确认字形变了 —— 而不是"编译过了应该没问题"。

用法：
    python measure_ink.py <png> <x0> <y0> <x1> <y1> [像素阈值]

阈值默认 128（0=黑，255=白）：亮度低于它就当墨迹。
"""
import sys

from PIL import Image


def main():
    path = sys.argv[1]
    x0, y0, x1, y1 = (int(v) for v in sys.argv[2:6])
    thresh = int(sys.argv[6]) if len(sys.argv) > 6 else 128

    img = Image.open(path).convert('RGB')
    w, h = img.size
    x0, y0 = max(0, x0), max(0, y0)
    x1, y1 = min(w, x1), min(h, y1)
    px = img.load()

    minx = miny = 10 ** 9
    maxx = maxy = -1
    count = 0

    for y in range(y0, y1):
        for x in range(x0, x1):
            r, g, b = px[x, y]
            # 用感知亮度，避免把彩色抗锯齿边缘算成墨
            if 0.299 * r + 0.587 * g + 0.114 * b < thresh:
                count += 1
                minx, maxx = min(minx, x), max(maxx, x)
                miny, maxy = min(miny, y), max(maxy, y)

    if count == 0:
        print(f'{path}  区域=({x0},{y0})-({x1},{y1})  没有墨迹')
        return

    print(f'{path}')
    print(f'  区域     ({x0},{y0})-({x1},{y1})')
    print(f'  墨迹 bbox ({minx},{miny})-({maxx},{maxy})')
    print(f'  墨迹尺寸 {maxx - minx + 1} x {maxy - miny + 1}')
    print(f'  墨迹像素 {count}')
    # 这个数最有用：固定文案在不同字体下的宽度不同
    print(f'  宽度     {maxx - minx + 1}')


if __name__ == '__main__':
    main()
