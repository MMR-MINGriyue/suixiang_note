# -*- coding: utf-8 -*-
"""
随想随记 · 全新美术素材生成（悬浮水晶球 v2.6）
设计概念：「灵感水晶球」悬浮水晶球 × 现代渐变
  - 品牌符号 = 悬浮玻璃水晶球（白→淡冷蓝球身 + 玻璃双层描边 + 左上高光弧）
    + 球内琥珀半满液弦（积累） + 球内两颗白星
    + 右上白色坠星（灵感来了）+ 底下暖色悬浮光环
  - 图标底 = 三段对角渐变（深靛 #18246E → 品牌蓝 #4C6FFF → 亮青蓝 #6FA0FF）
  - 一图双义：坠星在闪 = 一次灵感来了；液弦高度 = 已经攒了多少
  - 启动图标取「半满球」态：随想随记，永远攒在半路上

v2.6 造型演进（用户逐轮确认：8 造型 → E 软木塞罐 → 弃（塞子不好看）→
             水晶球三变体 → V2 悬浮）：
  - 球身：淡白→淡冷蓝纵渐变 + 双层描边（深蓝外圈 + 亮蓝内圈）+ 左上高光弧 + 高光点
  - 琥珀液弦：下半球弦形，level ∈ [0,1] 液面从球底升到球心上方
  - 悬浮：球底下方暖色光环（GLOW blur），球体轻微上浮
  - 坠星：右上双层光晕 + 白主星 + 暖芯 + 伴星
  ★ 纯 Dart 侧 drop_shape.dart 几何未动（App 内徽章/FAB 保持既有形状），
    test/ 守卫不受影响。

本脚本自 v2.3 起是图标/插画/纸纹的唯一权威生成器；
tool/gen_icons.py 与 tool/gen_assets.py 保留为 v1/v2 历史设计档案，勿再执行。

用法：python tool/gen_visual.py   （仓库根目录执行）
输出：覆盖 android 5 档 mipmap / windows ico / assets/illus / assets/texture，
      并重建 tool/out/icon_preview.png（带标签的总览）。
"""
import os, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')
ILLUS = os.path.join(ROOT, 'assets', 'illus')
TEX = os.path.join(ROOT, 'assets', 'texture')
ICO = os.path.join(ROOT, 'windows', 'runner', 'resources', 'app_icon.ico')
PREVIEW = os.path.join(ROOT, 'tool', 'out', 'icon_preview.png')

# ---- 色板（语义色与 lib/theme/tokens.dart 一致）----
PAPER   = (250, 247, 242)   # #FAF7F2 纸底
BRAND   = (76, 111, 255)    # #4C6FFF 品牌蓝 / 推进中
BRAND_D = (61, 91, 224)     # #3D5BE0 按下/暗部（球描边）
BRAND_L = (123, 147, 255)   # #7B93FF 深色模式/亮部
MIST    = (168, 185, 230)   # #A8B9E6 灵感 / 线稿
CONT    = (232, 237, 255)   # #E8EDFF 品牌容器 / 光晕
DONE    = (47, 191, 143)    # #2FBF8F 完成
AMBER   = (255, 176, 59)    # #FFB03B 琥珀金 / 灵感闪星
AMBER_L = (255, 214, 140)   # 亮部 / 液面
AMBER_D = (222, 138, 22)    # #DE8A16 暗部 / 液体阴影
WHITE   = (255, 255, 255)

# ---- 渐变底配色（v2.5 定稿 P1）----
INK_DEEP    = (24, 36, 110)     # 渐变最深端（左上深靛）
CYAN_BRIGHT = (111, 160, 255)   # 渐变最亮端（右下亮青蓝）
GLOW_WARM   = (255, 227, 172)   # 暖色光斑
ORB_BODY_LO = (219, 228, 250)   # 球身底部淡冷蓝（白→淡蓝体积感）
STROKE_HI   = (150, 172, 255)   # 玻璃内圈亮蓝描边

SS = 4  # 超采样倍数（抗锯齿）


def lerp(a, b, t):
    return a + (b - a) * t


def diag_gradient(w, h, c0, c1, c2):
    """三段对角渐变：左上 c0 → 中心 c1 → 右下 c2。"""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    t = np.clip((xx + yy) / (w + h), 0, 1)
    c0a, c1a, c2a = map(np.array, (c0, c1, c2))
    rgb = np.where((t < 0.5)[..., None],
                   c0a + (c1a - c0a) * (t * 2)[..., None],
                   c1a + (c2a - c1a) * ((t - 0.5) * 2)[..., None])
    arr = np.zeros((h, w, 4), np.uint8)
    arr[..., :3] = rgb.astype(np.uint8)
    arr[..., 3] = 255
    return Image.fromarray(arr, 'RGBA')


def radial_glow(w, h, cx, cy, radius, color, peak):
    """径向淡光晕 RGBA（边缘完全透明，不会在启动器上露出方块）"""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    r2 = ((xx-cx)**2 + (yy-cy)**2) / (radius**2)
    al = (peak * np.exp(-2.4*r2)).clip(0, 1)
    arr = np.zeros((h, w, 4), np.float32)
    arr[..., 0] = color[0]; arr[..., 1] = color[1]; arr[..., 2] = color[2]
    arr[..., 3] = al * 255
    return Image.fromarray(arr.astype(np.uint8), 'RGBA')


def star4(d, cx, cy, R, ratio, color, rot=-math.pi/2):
    """四芒星（8 点多边形）。"""
    pts = []
    for i in range(8):
        r = R if i % 2 == 0 else R * ratio
        a = rot + i * math.pi / 4
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    d.polygon(pts, fill=color)


def star4_q(d, cx, cy, R, color, rot=-math.pi/2):
    """Q 版圆胖四芒星：内凹浅（ratio 0.55）。"""
    star4(d, cx, cy, R, 0.55, color, rot)


def star_trail(d, sx, sy, tx, ty, color=WHITE, w=3):
    """闪星坠落的曳尾：两条渐隐斜线（长 + 短）。坐标为像素。"""
    dx, dy = tx - sx, ty - sy
    L = math.hypot(dx, dy) or 1.0
    ux, uy = dx / L, dy / L
    px, py = -uy, ux
    for (t0, t1, ww, al) in [(0.0, 0.85, w, 190), (0.12, 0.62, w * 0.6, 120)]:
        d.line([(sx + ux*L*t0 + px*ww, sy + uy*L*t0 + py*ww),
                (sx + ux*L*t1 + px*ww*0.3, sy + uy*L*t1 + py*ww*0.3)],
               fill=color + (al,), width=max(1, int(ww)))
        d.line([(sx + ux*L*t0 - px*ww, sy + uy*L*t0 - py*ww),
                (sx + ux*L*t1 - px*ww*0.3, sy + uy*L*t1 - py*ww*0.3)],
               fill=color + (al,), width=max(1, int(ww)))


def star_dust(im, cx, cy, spread, n, color, seed=7):
    """在 (cx,cy) 附近撒 n 颗星尘微点。坐标为像素。"""
    rng = np.random.default_rng(seed)
    d = ImageDraw.Draw(im)
    for _ in range(n):
        x = cx + rng.normal(0, spread * 0.55)
        y = cy + rng.normal(0, spread * 0.45)
        rr = rng.uniform(0.004, 0.012) * spread
        al = int(rng.uniform(90, 200))
        d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=color + (al,))


# ---------------- 悬浮水晶球几何 ----------------
def orb_geometry(H):
    """悬浮水晶球几何（单位坐标，×H + 中心）。
    球半径 0.235 / 球心相对给定中心上移 0.04
    液面区间：ly ∈ [cy_orb + 0.75r(空), cy_orb - 0.05r(满)]
    悬浮光环：球底下 0.75r 处，半宽 0.26H。"""
    r = 0.235
    return dict(r=r, dy=-0.04, liquid_a=0.75, liquid_b=-0.05,
                halo_dy=0.75, halo_hw=0.26)


def orb_liquid(cx, cy, H, level, g=None):
    """球内琥珀液弦（下半球缺）。level ∈ [0,1]：0 空 / 0.5 半满 / 1 满。
    返回 (弦形点集, 液面y像素, 弦半宽像素)。"""
    if g is None:
        g = orb_geometry(H)
    r = g['r'] * H
    ocx, ocy = cx, cy + g['dy']*H
    t = max(0.0, min(1.0, level))
    ly = ocy + lerp(g['liquid_a'], g['liquid_b'], t) * r
    dy = (ly - ocy) / max(r, 1e-6)
    dy = max(-0.99, min(0.99, dy))
    a = math.asin(dy)
    half = r * math.cos(a)
    pts = [(ocx - half, ly)]
    for ang in np.linspace(a, math.pi - a, 48):
        pts.append((ocx + r * math.cos(ang), ocy + r * math.sin(ang)))
    return pts, ly, half, (ocx, ocy, r)


def make_jar(w, h, cx, cy, H, level=0.0, falling_star=True,
             monochrome=False, outline_scale=1.0, ground_shadow=False):
    """绘制「悬浮水晶球」品牌符号，返回 RGBA 图层（w×h）。
    level ∈ [0,1]：0 空球 / 0.5 半满 / 1 全满。
    falling_star: 是否画右上坠星 + 光晕。
    monochrome: 主题图标单色版（纯 alpha 剪影 + 透明液面弦）。
    ground_shadow: 未用（悬浮光环恒画），保留参数兼容插画调用。"""
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    g = orb_geometry(H)
    lw = max(2, int(0.045 * g['r'] * H * outline_scale))
    r = g['r'] * H
    ocx, ocy = cx, cy + g['dy']*H

    if monochrome:
        d = ImageDraw.Draw(im)
        # 球剪影 + 悬浮光环
        d.ellipse([ocx-r, ocy-r, ocx+r, ocy+r], outline=(0, 0, 0, 255), width=lw)
        halo_hw = g['halo_hw']*H
        halo_y = ocy + g['halo_dy']*r
        d.ellipse([cx - halo_hw, halo_y - 0.018*H, cx + halo_hw, halo_y + 0.018*H],
                  outline=(0, 0, 0, 255), width=max(1, int(0.014*H)))
        # 液面：一条透明弦线（把「半满」语义带进单色版）
        lpts, ly, half, _ = orb_liquid(cx, cy, H, level, g)
        wpts = [(lerp(ocx - half, ocx + half, t),
                 ly + 0.012*H*math.sin(math.pi*t))
                for t in np.linspace(0, 1, 48)]
        wipe = Image.new('L', (w, h), 0)
        ImageDraw.Draw(wipe).line(wpts, fill=255,
                                  width=max(2, int(0.028*H)), joint='curve')
        arr = np.asarray(im).astype(np.float32)
        arr[..., 3] = arr[..., 3] / 255.0 * (1 - 0.85 * np.asarray(wipe).astype(np.float32)/255.0) * 255
        im = Image.fromarray(arr.astype(np.uint8), 'RGBA')
        if falling_star:
            d = ImageDraw.Draw(im)
            sx, sy = cx + 0.26*H, ocy - 0.70*r
            star4_q(d, sx, sy, 0.070*H, (0, 0, 0, 255))
            star_trail(d, sx, sy, sx - 0.045*H, sy + 0.12*H,
                       color=(0, 0, 0), w=max(1, int(0.012*H)))
        return im

    # ---- 彩色版 ----
    # 0) 悬浮光环（球底下方，先画被球压住上缘）
    halo_hw = g['halo_hw']*H
    halo_y = ocy + g['halo_dy']*r
    halo = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(halo).ellipse([cx - halo_hw, halo_y - 0.020*H,
                                  cx + halo_hw, halo_y + 0.020*H],
                                 outline=GLOW_WARM + (185,), width=max(2, int(0.022*H)))
    im.alpha_composite(halo.filter(ImageFilter.GaussianBlur(0.010*H)))

    # 1) 球身：白 → 淡冷蓝纵渐变，圆形 mask
    yy, _ = np.mgrid[0:h, 0:w].astype(np.float32)
    t = np.clip((yy - (ocy - r)) / (2*r), 0, 1)
    body = np.zeros((h, w, 4), np.uint8)
    top_c = np.array(WHITE, np.float32)
    bot_c = np.array(ORB_BODY_LO, np.float32)
    for j in range(3):
        body[..., j] = (top_c[j] + (bot_c[j] - top_c[j]) * t).astype(np.uint8)
    body[..., 3] = 245
    body_layer = Image.fromarray(body, 'RGBA')
    m = Image.new('L', (w, h), 0)
    ImageDraw.Draw(m).ellipse([ocx-r, ocy-r, ocx+r, ocy+r], fill=255)
    body_layer.putalpha(Image.composite(body_layer.split()[3],
                                        Image.new('L', (w, h), 0), m))
    im.alpha_composite(body_layer)

    # 2) 琥珀液弦（下半球缺 + 液面高光 + 白星）
    if level > 0.02:
        lpts, ly, half, _ = orb_liquid(cx, cy, H, level, g)
        liq = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        ImageDraw.Draw(liq).polygon(lpts, fill=AMBER + (242,))
        im.alpha_composite(liq)
        d = ImageDraw.Draw(im)
        # 液面微凸高光
        eh = 0.018*r if level > 0.9 else 0.028*r
        d.ellipse([ocx - half*0.96, ly - eh, ocx + half*0.96, ly + eh],
                  fill=AMBER_L + (255,))
        # 液内两颗白星
        seg = (ocy + r) - ly
        star4(d, ocx - 0.30*r, ly + seg*0.42, 0.14*r, 0.40, WHITE + (255,))
        star4(d, ocx + 0.22*r, ly + seg*0.62, 0.10*r, 0.40, WHITE + (230,))

    # 3) 玻璃双层描边 + 左上高光弧 + 高光点
    d = ImageDraw.Draw(im)
    d.ellipse([ocx-r, ocy-r, ocx+r, ocy+r], outline=BRAND_D + (255,), width=lw)
    ir = r * 0.93
    d.ellipse([ocx-ir, ocy-ir, ocx+ir, ocy+ir],
              outline=STROKE_HI + (190,), width=max(1, int(0.018*r*outline_scale)))
    hl = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    hr = r * 0.80
    ImageDraw.Draw(hl).arc([ocx-hr, ocy-hr, ocx+hr, ocy+hr], 200, 285,
                           fill=WHITE + (230,), width=max(2, int(0.045*r)))
    im.alpha_composite(hl.filter(ImageFilter.GaussianBlur(0.008*r)))
    hx, hy = ocx - 0.52*r, ocy - 0.55*r
    hr2 = 0.055*r
    d.ellipse([hx-hr2, hy-hr2, hx+hr2, hy+hr2], fill=WHITE + (235,))

    # 4) 右上坠星 + 光晕 + 曳尾 + 伴星
    if falling_star:
        sx, sy = cx + 0.26*H, ocy - 0.70*r
        im.alpha_composite(radial_glow(w, h, sx - 0.02*H, sy + 0.02*H,
                                       0.12*H, GLOW_WARM, 0.50))
        im.alpha_composite(radial_glow(w, h, sx, sy, 0.065*H, WHITE, 0.40))
        d = ImageDraw.Draw(im)
        star_trail(d, sx, sy, sx - 0.045*H, sy + 0.12*H,
                   w=max(1, int(0.010*H)))
        star4_q(d, sx, sy, 0.070*H, WHITE + (255,))
        star4_q(d, sx, sy, 0.040*H, GLOW_WARM + (255,))
        star4_q(d, cx - 0.30*H, ocy - 0.45*r, 0.024*H, WHITE + (215,))
        star_dust(im, sx - 0.05*H, sy, 0.11*H, 6, WHITE, seed=11)
    return im


def down(im, size):
    return im.resize(size, Image.LANCZOS)


def compose_foreground(S, mono=False):
    """自适应图标前景：透明底 + 白色柔光晕 + 悬浮水晶球"""
    W = Hc = S*SS
    base = Image.new('RGBA', (W, Hc), (0, 0, 0, 0))
    if not mono:
        base.alpha_composite(radial_glow(W, Hc, W/2, Hc*0.55, W*0.42, WHITE, 0.30))
        base.alpha_composite(radial_glow(W, Hc, W*0.66, Hc*0.22, W*0.28, GLOW_WARM, 0.20))
    jh = S*SS*0.66
    base.alpha_composite(make_jar(W, Hc, W/2, Hc*0.52, jh, level=0.5, monochrome=mono))
    return down(base, (S, S))


def compose_static(S, round_icon=False):
    """静态启动图标：三段对角渐变底 + 光斑 + 悬浮水晶球"""
    W = Hc = S*SS
    bg = diag_gradient(W, Hc, INK_DEEP, BRAND, CYAN_BRIGHT)
    bg.alpha_composite(radial_glow(W, Hc, W*0.66, Hc*0.22, W*0.34, GLOW_WARM, 0.16))
    bg.alpha_composite(radial_glow(W, Hc, W*0.30, Hc*0.80, W*0.36, INK_DEEP, 0.22))
    jh = S*SS*0.66
    bg.alpha_composite(make_jar(W, Hc, W/2, Hc*0.52, jh, level=0.5))
    # 圆角/圆形遮罩放最后，圆角外完全透明
    mask = Image.new('L', (W, Hc), 0)
    md = ImageDraw.Draw(mask)
    if round_icon:
        md.ellipse([0, 0, W-1, Hc-1], fill=255)
    else:
        md.rounded_rectangle([0, 0, W-1, Hc-1], radius=int(W*0.225), fill=255)
    bg.putalpha(mask)
    return down(bg, (S, S))


# ---------------- 空态插画 ----------------
IS = 3          # 插画超采样
IW, IH = 320*IS, 240*IS


def illus_disc(im, warm_at=(210, 62)):
    """插画渐变圆底 + 右上暖光斑。"""
    disc = diag_gradient(IW, IH, INK_DEEP, BRAND, CYAN_BRIGHT)
    dmask = Image.new('L', (IW, IH), 0)
    ImageDraw.Draw(dmask).ellipse([28*IS, 16*IS, 292*IS, 224*IS], fill=255)
    disc.putalpha(dmask)
    im.alpha_composite(disc)
    im.alpha_composite(radial_glow(IW, IH, warm_at[0]*IS, warm_at[1]*IS,
                                   90*IS, GLOW_WARM, 0.20))


def wline(d, pts, width, alpha=235):
    """渐变底上的白色圆头折线。坐标为插画单位（×IS）。"""
    c = WHITE + (alpha,)
    w = int(width*IS)
    d.line([(x*IS, y*IS) for x, y in pts], fill=c, width=w, joint='curve')
    for x, y in (pts[0], pts[-1]):
        r = w/2
        d.ellipse([x*IS-r, y*IS-r, x*IS+r, y*IS+r], fill=c)


def wdash(d, pts, width, on=6, off=7, alpha=200):
    """白色虚线。坐标为插画单位。"""
    c = WHITE + (alpha,)
    w = int(width*IS)
    for a, b in zip(pts[:-1], pts[1:]):
        dx, dy = b[0]-a[0], b[1]-a[1]
        L = math.hypot(dx, dy)
        if L == 0:
            continue
        ux, uy = dx/L, dy/L
        p = 0.0
        while p < L:
            q = min(p+on, L)
            d.line([((a[0]+ux*p)*IS, (a[1]+uy*p)*IS),
                    ((a[0]+ux*q)*IS, (a[1]+uy*q)*IS)], fill=c, width=w)
            for (xx, yy) in [((a[0]+ux*p), (a[1]+uy*p)), ((a[0]+ux*q), (a[1]+uy*q))]:
                r = w/2
                d.ellipse([(xx*IS-r), (yy*IS-r), (xx*IS+r), (yy*IS+r)], fill=c)
            p = q + off


def wrrect(d, box, radius, width, alpha=255, fill=None):
    f = (fill + (255,)) if fill else None
    d.rounded_rectangle([v*IS for v in box], radius=radius*IS,
                        outline=WHITE + (alpha,), width=int(width*IS), fill=f)


def mini_jar(base, cx, cy, H, level=0.0, falling_star=True):
    """插画里的悬浮水晶球（同品牌符号）。"""
    d = make_jar(IW, IH, cx*IS, cy*IS, H*IS, level=level,
                 falling_star=falling_star, outline_scale=1.3)
    base.alpha_composite(d)


def mini_star_amber(d, cx, cy, R, color=AMBER):
    """插画里的琥珀小闪星（Q 版圆胖）。"""
    star4_q(d, cx*IS, cy*IS, R*IS, color + (255,))


def illus_home():
    """首页空态：渐变圆底 + 两叠白纸卡 + 字行 + 右下悬浮水晶球。"""
    im = Image.new('RGBA', (IW, IH), (0, 0, 0, 0))
    illus_disc(im)
    d = ImageDraw.Draw(im)
    # 两张错叠白纸卡
    wrrect(d, (74, 76, 218, 168), 10, 2.0, alpha=200, fill=(244, 246, 252))
    wrrect(d, (92, 60, 240, 152), 10, 2.4, alpha=245, fill=(252, 251, 248))
    # 字行（雾靛，在白卡上）
    for (x0, x1, y, w) in [(112, 208, 84, 3.0), (112, 184, 104, 2.6), (112, 160, 122, 2.2)]:
        d.line([(x0*IS, y*IS), (x1*IS, y*IS)], fill=MIST + (255,),
               width=int(w*IS), joint='curve')
    # 右下：半满悬浮水晶球
    mini_jar(im, 238, 158, 118, level=0.6, falling_star=False)
    # 右上琥珀坠星 + 光晕
    im.alpha_composite(radial_glow(IW, IH, 262*IS, 44*IS, 34*IS, GLOW_WARM, 0.5))
    d = ImageDraw.Draw(im)
    mini_star_amber(d, 262, 44, 12)
    star4_q(d, 262*IS, 44*IS, 6.5*IS, AMBER_L + (255,))
    # 左上一颗白色伴星 + 星尘
    star4_q(d, 48*IS, 46*IS, 7*IS, WHITE + (220,))
    star_dust(im, 60*IS, 52*IS, 24*IS, 6, WHITE, seed=3)
    return down(im, (320, 240))


def illus_folder():
    """文件夹空态：渐变圆底 + 白色文件夹线稿 + 空中悬浮水晶球等灵感。"""
    im = Image.new('RGBA', (IW, IH), (0, 0, 0, 0))
    illus_disc(im, warm_at=(196, 84))
    d = ImageDraw.Draw(im)
    # 后片（带折角标签）
    wline(d, [(56, 108), (128, 108), (146, 126), (254, 126), (254, 196), (56, 196), (56, 108)], 2.4, alpha=225)
    # 露出的一张白纸 + 字行
    wrrect(d, (86, 92, 224, 176), 8, 2.0, alpha=240, fill=(252, 251, 248))
    d.line([(106*IS, 116*IS), (186*IS, 116*IS)], fill=MIST + (255,), width=int(2.6*IS), joint='curve')
    d.line([(106*IS, 136*IS), (166*IS, 136*IS)], fill=MIST + (255,), width=int(2.4*IS), joint='curve')
    # 前片（梯形）
    wline(d, [(46, 148), (266, 148), (246, 214), (66, 214), (46, 148)], 2.6, alpha=245)
    wline(d, [(60, 162), (260, 162)], 1.6, alpha=140)
    # 空中：悬浮水晶球（空球等灵感，带坠星）
    wdash(d, [(206, 32), (200, 44)], 2.0)
    mini_jar(im, 210, 82, 88, level=0.0, falling_star=True)
    # 琥珀小星
    mini_star_amber(d, 250, 34, 9)
    star_dust(im, 210*IS, 36*IS, 22*IS, 6, WHITE, seed=9)
    return down(im, (320, 240))


def illus_graph():
    """关系图空态：渐变圆底 + 白色三节点虚线 + 中央悬浮水晶球。"""
    im = Image.new('RGBA', (IW, IH), (0, 0, 0, 0))
    illus_disc(im, warm_at=(160, 108))
    d = ImageDraw.Draw(im)
    # 三条虚线连接（一条刻意断开 = 还没有关联）
    wdash(d, [(92, 82), (224, 82)], 2.2)
    wdash(d, [(92, 82), (160, 178)], 2.2)
    wdash(d, [(224, 82), (160, 178)], 2.2)
    # 三个节点环（白环 + 语义色芯）
    for (x, y, c) in [(92, 82, BRAND_L), (224, 82, BRAND_L), (160, 178, DONE)]:
        r = 17
        d.ellipse([(x-r)*IS, (y-r)*IS, (x+r)*IS, (y+r)*IS],
                  outline=WHITE + (245,), width=int(2.6*IS))
        d.ellipse([(x-7)*IS, (y-7)*IS, (x+7)*IS, (y+7)*IS], fill=c + (255,))
    # 节点小标签条
    for box in [(66, 100, 118, 112), (200, 100, 252, 112), (132, 198, 188, 210)]:
        wrrect(d, box, 4, 1.6, alpha=210, fill=(252, 251, 248))
    # 中央悬浮水晶球
    mini_jar(im, 160, 128, 96, level=0.5, falling_star=False)
    star_dust(im, 160*IS, 48*IS, 28*IS, 7, WHITE, seed=13)
    mini_star_amber(d, 226, 40, 8)
    return down(im, (320, 240))


def illus_trash():
    """回收站空态：渐变圆底 + 白色桶线稿 + 飘出的琥珀闪星 + 星尘。"""
    im = Image.new('RGBA', (IW, IH), (0, 0, 0, 0))
    illus_disc(im, warm_at=(160, 62))
    d = ImageDraw.Draw(im)
    # 桶盖 + 提手
    wline(d, [(86, 100), (234, 100)], 2.6, alpha=245)
    wline(d, [(140, 100), (146, 84), (174, 84), (180, 100)], 2.4, alpha=245)
    # 桶身（上宽下窄）
    wline(d, [(98, 108), (222, 108), (208, 200), (112, 200), (98, 108)], 2.6, alpha=245)
    wline(d, [(134, 126), (139, 182)], 2.0, alpha=170)
    wline(d, [(186, 126), (181, 182)], 2.0, alpha=170)
    # 桶身中央小标签
    wrrect(d, (146, 140, 174, 160), 4, 1.8, alpha=210, fill=(252, 251, 248))
    d.line([(152*IS, 150*IS), (168*IS, 150*IS)], fill=MIST + (255,), width=int(1.8*IS))
    # 飘出的琥珀闪星 + 星轨弧
    p0 = np.array([112.0, 62.0]); p1 = np.array([140.0, 34.0]); p2 = np.array([176.0, 48.0])
    tt = np.linspace(0, 1, 48)[:, None]
    arc = (1-tt)**3*p0 + 3*(1-tt)**2*tt*p1 + 3*(1-tt)*tt**2*p1 + tt**3*p2
    d.line([(x*IS, y*IS) for x, y in arc], fill=AMBER_L + (170,),
           width=2*IS, joint='curve')
    im.alpha_composite(radial_glow(IW, IH, 196*IS, 40*IS, 30*IS, GLOW_WARM, 0.45))
    mini_star_amber(d, 122, 56, 9)
    mini_star_amber(d, 196, 40, 12)
    mini_star_amber(d, 160, 32, 7, color=AMBER_L)
    mini_star_amber(d, 150, 66, 4, color=AMBER_L)
    mini_star_amber(d, 208, 60, 5)
    star_dust(im, 160*IS, 48*IS, 44*IS, 12, WHITE, seed=17)
    return down(im, (320, 240))


# ---------------- 纸纹（暖灰纤维细噪）----------------
def paper_texture(dark):
    """8×8 纸纤维细噪 + 横向纤维：alpha 恒 255，靠 PaperTexture 的 Opacity 稀释。"""
    rng = np.random.default_rng(20231110 if not dark else 20231111)
    n = rng.normal(0, 1, (8, 8))
    fib = np.repeat(rng.normal(0, 0.45, (8, 1)), 8, axis=1)
    if dark:
        rgb = np.stack([180 + n*22 + fib*12, 186 + n*22 + fib*12,
                        200 + n*22 + fib*9], axis=-1)
    else:
        rgb = np.stack([118 + n*30 + fib*14, 124 + n*30 + fib*14,
                        138 + n*30 + fib*11], axis=-1)
    arr = np.zeros((8, 8, 4), np.uint8)
    arr[..., :3] = rgb.clip(0, 255).astype(np.uint8)
    arr[..., 3] = 255
    return Image.fromarray(arr, 'RGBA')


# ---------------- 生成 ----------------
DENS = [('mdpi', 48, 108), ('hdpi', 72, 162),
        ('xhdpi', 96, 216), ('xxhdpi', 144, 324),
        ('xxxhdpi', 192, 432)]

print('[1/5] Android mipmap ...')
for name, static, fg in DENS:
    out = os.path.join(RES, 'mipmap-'+name)
    os.makedirs(out, exist_ok=True)
    compose_static(static).save(os.path.join(out, 'ic_launcher.png'))
    compose_static(static, round_icon=True).save(os.path.join(out, 'ic_launcher_round.png'))
    compose_foreground(fg).save(os.path.join(out, 'ic_launcher_foreground.png'))
    compose_foreground(fg, mono=True).save(os.path.join(out, 'ic_launcher_monochrome.png'))
    print('  ', name, static, fg)

print('[2/5] Windows ico ...')
big = compose_static(256)
big.save(ICO, format='ICO', sizes=[(16, 16), (24, 24), (32, 32),
                                   (48, 48), (64, 64), (128, 128), (256, 256)])

print('[3/5] 空态插画 ...')
for fn, fnc in [('empty_home.png', illus_home), ('empty_folder.png', illus_folder),
                ('empty_graph.png', illus_graph), ('empty_trash.png', illus_trash)]:
    fnc().save(os.path.join(ILLUS, fn))
    print('  ', fn)

print('[4/5] 纸纹 ...')
paper_texture(False).save(os.path.join(TEX, 'paper_texture_light.png'))
paper_texture(True).save(os.path.join(TEX, 'paper_texture_dark.png'))

print('[5/5] 总览预览 ...')


def tile(im, s, bg=(250, 247, 242)):
    c = Image.new('RGBA', (s, s), bg+(255,))
    t = im.convert('RGBA').copy()
    t.thumbnail((s, s), Image.LANCZOS)
    c.alpha_composite(t, ((s-t.width)//2, (s-t.height)//2))
    return c.convert('RGB')


def _font(sz):
    for cand in (r'C:\Windows\Fonts\msyh.ttc', r'C:\Windows\Fonts\segoeui.ttf'):
        if os.path.exists(cand):
            try:
                return ImageFont.truetype(cand, sz)
            except OSError:
                pass
    return ImageFont.load_default()


cell, pad, lab = 190, 12, 26
prev = Image.new('RGB', (4*(cell+pad)+pad, 2*(cell+pad+lab)+pad), (214, 218, 228))
pd = ImageDraw.Draw(prev)
f = _font(13)
labels = ['自适应前景', '静态启动器', '圆形遮罩', '单色主题图标']
items = [compose_foreground(432), compose_static(192),
         compose_static(192, True), compose_foreground(432, mono=True)]
for i, (im, label) in enumerate(zip(items, labels)):
    x, y = pad+i*(cell+pad), pad
    prev.paste(tile(im, cell), (x, y))
    pd.text((x+3, y+cell+6), label, fill=(60, 64, 78), font=f)
labels2 = ['首页空态', '文件夹空态', '关系图空态', '回收站空态']
row = [illus_home(), illus_folder(), illus_graph(), illus_trash()]
for i, (im, label) in enumerate(zip(row, labels2)):
    x, y = pad+i*(cell+pad), pad+(cell+pad+lab)
    t = im.convert('RGBA').copy(); t.thumbnail((cell, cell), Image.LANCZOS)
    c = Image.new('RGBA', (cell, cell), (250, 247, 242, 255))
    c.alpha_composite(t, ((cell-t.width)//2, (cell-t.height)//2))
    prev.paste(c.convert('RGB'), (x, y))
    pd.text((x+3, y+cell+6), label, fill=(60, 64, 78), font=f)
os.makedirs(os.path.dirname(PREVIEW), exist_ok=True)
prev.save(PREVIEW)
print('  ->', os.path.relpath(PREVIEW, ROOT))
print('DONE')
