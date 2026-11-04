"""随想随记 · 应用图标生成器 v2

以 appicon/candidate-b-drop-ring-1024.svg（落定之珠）为母版，用 Pillow 几何重绘。

v2 视觉升级（相对 v1 的纯色平涂）：
1. 水滴轮廓改为「尖端 + 两条切线 + 整段底弧」的单闭合多边形 —— 消除 v1
   「多边形与底圆两次叠加」在 48px 下留下的接缝毛边。
2. 水滴填充改为垂直渐变（上浅下深），让珠子有一点体积感；
   平涂绿在纸底上太「贴纸」，渐变后更接近水滴材质。
3. 纸底版本加落影（模糊椭圆）+ 发丝内描边 —— 48px 图标在浅色桌面上
   没有投影会显得漂浮，内描边让纸面与桌面有一道分界。
4. 高光改为主层合成前高斯模糊，边缘不再生硬。

不变的约定：
- 母版坐标 1024×1024，圆环 r=298 / 线宽 56 / 75% 进度弧，水滴尖端 y=330、底圆 r=132
- 4x 超采样 + LANCZOS 下采样，48px 下仍保持干净
- 输出文件名与 v1 完全一致（Android 5 档 mipmap + adaptive XML + Windows ICO + 预览）

用法：python tool/gen_icons.py
本机无 cairosvg，故不走 SVG 栅格化。
"""

from __future__ import annotations

import math
import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# ---- 设计 Token（与 lib/theme/tokens.dart 对齐）--------------------------------
PAPER = (250, 247, 242, 255)      # #FAF7F2
BRAND = (76, 111, 255, 255)       # #4C6FFF 靛蓝
DROP_TOP = (98, 216, 178, 255)    # 渐变顶端（珠绿提亮）
DROP_BOT = (33, 163, 120, 255)    # 渐变底端（珠绿加深）
TRACK = (43, 47, 58, 20)          # #2B2F3A @ 8%
HILITE = (255, 255, 255, 150)     # 白 @ 59%（模糊前；模糊后实际更淡）
SHADOW = (43, 47, 58, 26)         # 落影 #2B2F3A @ 10%
EDGE = (43, 47, 58, 16)           # 发丝内描边 @ 6%

# ---- 母版几何 ----------------------------------------------------------------
BASE = 1024.0
C = BASE / 2.0          # 512
RING_R = 298.0
RING_W = 56.0
TIP_Y = 330.0
DROP_CY = TIP_Y + 251.0     # 581
DROP_R = 132.0
SWEEP = 270.0               # 75% 进度环
HILITE_C = (468.0, 560.0)
HILITE_R = (20.0, 34.0)
HILITE_ANGLE = -15.0

SS = 4                      # 超采样
ARC_SEGMENTS = 64           # 底弧采样密度


def _scale(k: float, n: float):
    """母版坐标 → 画布坐标的映射函数（画布中心恒为 n/2）。"""
    c = n / 2.0
    return lambda x, y: (c + (x - C) * k, c + (y - C) * k)


def teardrop_outline(k: float, n: float) -> list[tuple[float, float]]:
    """水滴整条轮廓：尖端 → 左切点 → 底弧（长弧，经过正下方）→ 右切点 → 回尖端。

    切点由 acos(DROP_R / d) 解析求出（与 v1 相同），区别是底弧整段采样成
    多边形边而不是再叠一个圆 —— 48px 下不再有「多边形边穿透圆边」的毛刺。
    """
    s = _scale(k, n)
    d = DROP_CY - TIP_Y                         # 251
    theta = math.acos(DROP_R / d)               # 切点张角 ≈ 58.3°

    tangents = []  # 母版坐标
    for sign in (-1.0, 1.0):
        ux, uy = 0.0, -1.0                      # 指向尖端的单位向量（屏幕坐标 y 向下）
        ct, st = math.cos(sign * theta), math.sin(sign * theta)
        rx, ry = ux * ct - uy * st, ux * st + uy * ct
        tangents.append((C + DROP_R * rx, DROP_CY + DROP_R * ry))
    left, right = tangents  # left 在上偏左，right 在上偏右

    la = math.atan2(left[1] - DROP_CY, left[0] - C)    # ≈ -148.3°
    ra = math.atan2(right[1] - DROP_CY, right[0] - C)  # ≈ -31.7°
    # 长弧 = 从左切点经左侧→正下方→右侧到右切点（屏幕坐标里正下方是 +90°）
    sweep = (ra - la) % (2 * math.pi) - 2 * math.pi   # 负方向转 ≈ -243.4°，必经 +90°

    pts = [s(C, TIP_Y)]
    for i in range(ARC_SEGMENTS + 1):
        a = la + sweep * i / ARC_SEGMENTS
        pts.append(s(C + DROP_R * math.cos(a), DROP_CY + DROP_R * math.sin(a)))
    return [(x, y) for x, y in pts]


def _drop_mask(pts, n: int) -> Image.Image:
    """水滴形状的 alpha 蒙版（渐变与 mono 都从它出发）。"""
    m = Image.new("L", (n, n), 0)
    ImageDraw.Draw(m).polygon(pts, fill=255)
    return m


def _vertical_gradient(n: int, box, top, bot) -> Image.Image:
    """在 box 范围内铺一张垂直渐变 RGBA 层。"""
    x0, y0, x1, y1 = box
    layer = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    h = max(1, y1 - y0)
    for y in range(y0, y1 + 1):
        t = (y - y0) / h
        col = tuple(int(a + (b - a) * t) for a, b in zip(top[:3], bot[:3])) + (255,)
        ld.line((x0, y, x1, y), fill=col)
    return layer


def render(
    size: int,
    mark_scale: float = 1.0,
    bg: tuple[int, int, int, int] | None = PAPER,
    rounded: float = 0.0,
    circle: bool = False,
    mono: bool = False,
) -> Image.Image:
    """渲染图标。mark_scale 相对母版（1.0 = 母版原构图，四周留白）。"""
    n = size * SS
    c = n / 2.0
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    if bg is not None:
        if circle:
            d.ellipse((0, 0, n - 1, n - 1), fill=bg)
        elif rounded > 0:
            d.rounded_rectangle((0, 0, n - 1, n - 1), radius=int(n * rounded), fill=bg)
        else:
            d.rectangle((0, 0, n, n), fill=bg)

    k = (n / BASE) * mark_scale
    rr = RING_R * k
    rw = max(1.0, RING_W * k)
    box = (c - rr, c - rr, c + rr, c + rr)

    if not mono:
        d.arc(box, 0, 360, fill=TRACK, width=max(1, int(round(rw))))
        d.arc(box, -90, -90 + SWEEP, fill=BRAND, width=max(1, int(round(rw))))
        for ang in (-90.0, -90.0 + SWEEP):
            a = math.radians(ang)
            ex, ey = c + rr * math.cos(a), c + rr * math.sin(a)
            d.ellipse((ex - rw / 2, ey - rw / 2, ex + rw / 2, ey + rw / 2), fill=BRAND)

    pts = teardrop_outline(k, n)
    mask = _drop_mask(pts, n)
    bbox = mask.getbbox()

    if mono:
        white = Image.new("RGBA", (n, n), (255, 255, 255, 0))
        white.putalpha(mask)
        img = Image.alpha_composite(img, white)
    else:
        # 落影：珠子底下一点点的模糊椭圆，只在有纸底时画（透明前景不画，
        # 否则系统裁进任何形状遮罩里都会带一圈灰晕）
        if bg is not None:
            sx = (bbox[0] + bbox[2]) / 2
            sh = Image.new("RGBA", (n, n), (0, 0, 0, 0))
            sd = ImageDraw.Draw(sh)
            sd.ellipse((sx - DROP_R * k * 0.95, bbox[3] - DROP_R * k * 0.30,
                        sx + DROP_R * k * 0.95, bbox[3] + DROP_R * k * 0.42),
                       fill=SHADOW)
            sh = sh.filter(ImageFilter.GaussianBlur(radius=DROP_R * k * 0.22))
            img = Image.alpha_composite(img, sh)

        # 渐变珠身
        grad = _vertical_gradient(n, bbox, DROP_TOP, DROP_BOT)
        grad.putalpha(mask)
        img = Image.alpha_composite(img, grad)

        # 高光：模糊后合成，边缘柔化
        hx = c + (HILITE_C[0] - C) * k
        hy = c + (HILITE_C[1] - C) * k
        rx_, ry_ = HILITE_R[0] * k, HILITE_R[1] * k
        ov = Image.new("RGBA", (n, n), (0, 0, 0, 0))
        od = ImageDraw.Draw(ov)
        od.ellipse((hx - rx_, hy - ry_, hx + rx_, hy + ry_), fill=HILITE)
        ov = ov.rotate(HILITE_ANGLE, center=(hx, hy), resample=Image.BICUBIC)
        ov = ov.filter(ImageFilter.GaussianBlur(radius=max(1.0, n * 0.004)))
        img = Image.alpha_composite(img, ov)

        # 发丝内描边：只在圆角/圆底上画，把纸面从桌面上「托」出来
        if bg is not None:
            ew = max(1, int(round(n * 0.004)))
            if circle:
                d.ellipse((ew // 2, ew // 2, n - 1 - ew // 2, n - 1 - ew // 2),
                          outline=EDGE, width=ew)
            elif rounded > 0:
                d.rounded_rectangle((ew // 2, ew // 2, n - 1 - ew // 2, n - 1 - ew // 2),
                                    radius=int(n * rounded), outline=EDGE, width=ew)

    return img.resize((size, size), Image.LANCZOS)


# ---- Android ----------------------------------------------------------------

RES = os.path.join(ROOT, "android", "app", "src", "main", "res")
BUCKETS = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}

ADAPTIVE_V26 = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
"""

ADAPTIVE_V33 = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>
</adaptive-icon>
"""

COLORS = """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#FAF7F2</color>
    <color name="splash_background">#FAF7F2</color>
</resources>
"""

COLORS_NIGHT = """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- 只覆盖闪屏底色；启动图标底色保持纸感，避免深色模式下图标变暗 -->
    <color name="splash_background">#1C1E26</color>
</resources>
"""


def write_android() -> list[str]:
    out: list[str] = []
    for bucket, mult in BUCKETS.items():
        d = os.path.join(RES, f"mipmap-{bucket}")
        os.makedirs(d, exist_ok=True)

        legacy = int(round(48 * mult))
        p = os.path.join(d, "ic_launcher.png")
        render(legacy, 0.94, PAPER, rounded=0.22).save(p)
        out.append(p)

        p = os.path.join(d, "ic_launcher_round.png")
        render(legacy, 0.80, PAPER, circle=True).save(p)
        out.append(p)

        fg = int(round(108 * mult))
        p = os.path.join(d, "ic_launcher_foreground.png")
        render(fg, 0.82, None).save(p)
        out.append(p)

        # 单色层：系统按主题着色，前景只保留形状（这里给白形状+透明底）
        p = os.path.join(d, "ic_launcher_monochrome.png")
        render(fg, 0.74, None, mono=True).save(p)
        out.append(p)

    for ver, tpl in (("mipmap-anydpi-v26", ADAPTIVE_V26), ("mipmap-anydpi-v33", ADAPTIVE_V33)):
        d = os.path.join(RES, ver)
        os.makedirs(d, exist_ok=True)
        for name in ("ic_launcher.xml", "ic_launcher_round.xml"):
            p = os.path.join(d, name)
            with open(p, "w", encoding="utf-8", newline="\n") as f:
                f.write(tpl)
            out.append(p)

    p = os.path.join(RES, "values", "colors.xml")
    with open(p, "w", encoding="utf-8", newline="\n") as f:
        f.write(COLORS)
    out.append(p)

    d = os.path.join(RES, "values-night")
    os.makedirs(d, exist_ok=True)
    p = os.path.join(d, "colors.xml")
    with open(p, "w", encoding="utf-8", newline="\n") as f:
        f.write(COLORS_NIGHT)
    out.append(p)
    return out


def write_windows() -> list[str]:
    p = os.path.join(ROOT, "windows", "runner", "resources", "app_icon.ico")
    im = render(256, 0.94, PAPER, rounded=0.22)
    im.save(p, format="ICO",
            sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    return [p]


def _font(sz: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for cand in (r"C:\Windows\Fonts\msyh.ttc", r"C:\Windows\Fonts\segoeui.ttf"):
        if os.path.exists(cand):
            try:
                return ImageFont.truetype(cand, sz)
            except OSError:
                pass
    return ImageFont.load_default()


def write_preview() -> str:
    tiles = [
        ("48px 启动器实际", render(48, 0.94, PAPER, rounded=0.22), None),
        ("96px", render(96, 0.94, PAPER, rounded=0.22), None),
        ("192px", render(192, 0.94, PAPER, rounded=0.22), None),
        ("圆形遮罩", render(192, 0.80, PAPER, circle=True), None),
        ("自适应前景 · 全幅", render(192, 0.82, (232, 228, 220, 255)), None),
        ("自适应 · 裁切后", render(192, 0.82, PAPER, circle=True), None),
        ("单色主题（系统着色）", render(192, 0.74, None, mono=True), (44, 48, 58)),
    ]
    cell, pad, lab = 192, 26, 30
    W = pad + len(tiles) * (cell + pad)
    H = pad * 2 + cell + lab
    sheet = Image.new("RGB", (W, H), (238, 234, 227))
    d = ImageDraw.Draw(sheet)
    f = _font(13)
    for i, (label, im, backdrop) in enumerate(tiles):
        x = pad + i * (cell + pad)
        if backdrop is not None:
            d.rounded_rectangle((x, pad, x + cell, pad + cell), radius=40, fill=backdrop)
        sheet.paste(im.convert("RGB"), (x, pad), im.split()[3] if im.mode == "RGBA" else None)
        d.text((x + 2, pad + cell + 9), label, fill=(70, 74, 86), font=f)
    out = os.path.join(ROOT, "tool", "out", "icon_preview.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sheet.save(out)
    return out


if __name__ == "__main__":
    files = write_android() + write_windows()
    prev = write_preview()
    print(f"wrote {len(files)} files")
    for f in files:
        print("  ", os.path.relpath(f, ROOT).replace("\\", "/"), os.path.getsize(f), "B")
    print("preview:", os.path.relpath(prev, ROOT).replace("\\", "/"))
