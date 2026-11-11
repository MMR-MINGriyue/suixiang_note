# -*- coding: utf-8 -*-
"""
随想随记 · 全新美术素材生成（Q 版现代渐变 v2.5）
设计概念：「星雨 · 落瓶」Q 版 × 现代渐变（F2-Q）
  - 品牌符号 = 圆润 Q 版开口玻璃瓶（矮胖、大圆角、圆肩）
    + 瓶内琥珀渐变液面（积累） + 正坠的白色圆胖四芒星（灵感降临）
  - 图标底 = 三段对角渐变（深靛 #18246E → 品牌蓝 #4C6FFF → 亮青蓝 #6FA0FF）
  - 一图双义：正在闪 = 一次灵感来了；液面高度 = 已经攒了多少
  - 启动图标取「半满瓶」态：随想随记，永远攒在半路上

v2.5 风格演进（用户逐轮确认：F 现代渐变 → F2 渐变×星瓶 → 更精细 → 更圆润 Q → P1 配色微调）：
  - 瓶身：白→淡冷蓝纵向渐变 + 玻璃双层描边（深蓝外圈 + 亮蓝内圈）
  - 坠星改白色系（蓝渐变底上对比更强），星形圆胖（内凹 0.55）
  - 插画：雾靛线稿 → 渐变圆底 + 白纸卡，Q 版小瓶
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
BRAND_D = (61, 91, 224)     # #3D5BE0 按下/暗部（瓶描边）
BRAND_L = (123, 147, 255)   # #7B93FF 深色模式/亮部
MIST    = (168, 185, 230)   # #A8B9E6 灵感 / 线稿
LINE2   = (198, 210, 240)   # 次线稿 / 虚线
CONT    = (232, 237, 255)   # #E8EDFF 品牌容器 / 光晕
DONE    = (47, 191, 143)    # #2FBF8F 完成
AMBER   = (255, 176, 59)    # #FFB03B 琥珀金 / 灵感闪星
AMBER_L = (255, 214, 140)   # 亮部 / 液面
AMBER_D = (222, 138, 22)    # #DE8A16 暗部 / 液体阴影
WHITE   = (255, 255, 255)

# ---- v2.5 Q 版现代渐变配色 ----
INK_DEEP    = (24, 36, 110)     # 渐变最深端（左上深靛）
CYAN_BRIGHT = (111, 160, 255)   # 渐变最亮端（右下亮青蓝）
GLOW_WARM   = (255, 227, 172)   # 暖色光斑
JAR_BODY_LO = (226, 233, 252)   # 瓶身底部淡冷蓝（白→淡蓝体积感）
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
    """Q 版圆胖四芒星：内凹浅（ratio 0.55），芒尖短而可爱。"""
    star4(d, cx, cy, R, 0.55, color, rot)


def star_trail(d, sx, sy, tx, ty, color=WHITE, w=3):
    """闪星坠落的曳尾：两条渐隐斜线（长 + 短）。坐标为像素。"""
    dx, dy = tx - sx, ty - sy
    L = math.hypot(dx, dy) or 1.0
    ux, uy = dx / L, dy / L
    px, py = -uy, ux  # 垂直方向
    for (t0, t1, ww, al) in [(0.0, 0.85, w, 190), (0.12, 0.62, w * 0.6, 120)]:
        d.line([(sx + ux*L*t0 + px*ww, sy + uy*L*t0 + py*ww),
                (sx + ux*L*t1 + px*ww*0.3, sy + uy*L*t1 + py*ww*0.3)],
               fill=color + (al,), width=max(1, int(ww)))
        d.line([(sx + ux*L*t0 - px*ww, sy + uy*L*t0 - py*ww),
                (sx + ux*L*t1 - px*ww*0.3, sy + uy*L*t1 - py*ww*0.3)],
               fill=color + (al,), width=max(1, int(ww)))


def star_dust(im, cx, cy, spread, n, color, seed=7):
    """在 (cx,cy) 附近撒 n 颗星尘微点（大小/亮度随机）。坐标为像素。"""
    rng = np.random.default_rng(seed)
    d = ImageDraw.Draw(im)
    for _ in range(n):
        x = cx + rng.normal(0, spread * 0.55)
        y = cy + rng.normal(0, spread * 0.45)
        rr = rng.uniform(0.004, 0.012) * spread
        al = int(rng.uniform(90, 200))
        d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=color + (al,))


# ---------------- Q 版瓶几何 ----------------
def q_geometry(H):
    """Q 版瓶几何（单位坐标，×H + 中心）。
    口半宽 0.24 / 腹半宽 0.36 / 口沿 y=-0.34 / 底 y=+0.32
    / 底圆角 0.22（接近半圆）/ 口沿外挑 0.06。"""
    return dict(hm=0.24, hb=0.36, top=-0.34, bot=0.32, cr=0.22, lip=0.06)


def q_outline(cx, cy, H, inset=0.0, g=None):
    """Q 版瓶完整轮廓（含口沿外挑 + 圆肩贝塞尔），点集（像素坐标）。
    inset: 内缩量（单位坐标），用于内侧亮圈描边。"""
    if g is None:
        g = q_geometry(H)
    hm = g['hm'] + inset * 0.5
    hb = g['hb'] - inset
    lip, top, bot, cr = g['lip'], g['top'], g['bot'], g['cr']
    P = lambda ux, uy: (cx + ux*H, cy + uy*H)
    sh_top, sh_bot = top + 0.05, top + 0.16
    t = np.linspace(0, 1, 22)[:, None]

    def bez(p0, p1, p2, p3):
        return ((1-t)**3*p0 + 3*(1-t)**2*t*p1 + 3*(1-t)*t**2*p2 + t**3*p3)

    pts = [P(-hm - lip, top), P(-hm, top)]
    # 左肩：三次贝塞尔外凸圆弧（口 → 腹）
    b0 = np.array(P(-hm, sh_top))
    b1 = np.array([cx - (hb + 0.10)*H, cy + (sh_top - 0.02)*H])
    b2 = np.array([cx - (hb + 0.06)*H, cy + sh_bot*H])
    b3 = np.array(P(-hb, sh_bot))
    for p in bez(b0, b1, b2, b3):
        pts.append(tuple(p))
    pts.append(P(-hb, bot - cr))
    for a in np.linspace(math.pi, math.pi/2, 24):
        pts.append((cx + (-hb+cr)*H + cr*H*math.cos(a),
                    cy + (bot-cr)*H + cr*H*math.sin(a)))
    pts.append(P(hb - cr, bot))
    for a in np.linspace(math.pi/2, 0, 24):
        pts.append((cx + (hb-cr)*H + cr*H*math.cos(a),
                    cy + (bot-cr)*H + cr*H*math.sin(a)))
    pts.append(P(hb, sh_bot))
    # 右肩（对称，反向）
    b3r = np.array(P(hb, sh_top))
    b2r = np.array([cx + (hb + 0.06)*H, cy + sh_bot*H])
    b1r = np.array([cx + (hb + 0.10)*H, cy + (sh_top - 0.02)*H])
    b0r = np.array(P(hm, sh_top))
    for p in bez(b3r, b2r, b1r, b0r):
        pts.append(tuple(p))
    pts += [P(hm, top), P(hm + lip, top)]
    return pts


def q_liquid(cx, cy, H, level, g=None):
    """Q 版液体闭合区域。level ∈ [0,1]：0 空 / 0.5 半满 / 1 满。
    液面 y 在 [bot-0.06, top+0.04] 内插值（level 越大液面越高、ly 越小）。"""
    if g is None:
        g = q_geometry(H)
    top, bot, cr = g['top'], g['bot'], g['cr']
    hw = g['hb'] - 0.030
    ly = lerp(bot - 0.06, top + 0.04, level)
    rr = min(cr, hw)
    ly = min(ly, bot - rr)
    P = lambda ux, uy: (cx + ux*H, cy + uy*H)
    pts = [P(-hw, ly), P(hw, ly), P(hw, bot - rr)]
    for a in np.linspace(0, math.pi/2, 24):
        pts.append((cx + (hw-rr)*H + rr*H*math.cos(a),
                    cy + (bot-rr)*H + rr*H*math.sin(a)))
    pts.append(P(-hw + rr, bot))
    for a in np.linspace(math.pi/2, math.pi, 24):
        pts.append((cx + (-hw+rr)*H + rr*H*math.cos(a),
                    cy + (bot-rr)*H + rr*H*math.sin(a)))
    pts.append(P(-hw, bot - rr))
    return pts


def liquid_gradient_img(w, h, lpts):
    """液体竖向渐变层：液面 AMBER_L → 中部 AMBER → 瓶底 AMBER_D，
    用 polygon mask 裁进瓶身。返回 RGBA 图层。"""
    ys = [p[1] for p in lpts]
    y_top, y_bot = min(ys), max(ys)
    t = np.clip((np.arange(h, dtype=np.float32) - y_top)
                / max(1.0, y_bot - y_top), 0.0, 1.0)
    hi = np.array(AMBER_L, np.float32)
    mid = np.array(AMBER, np.float32)
    lo = np.array(AMBER_D, np.float32)
    first = (t <= 0.5)[:, None]
    tt = np.where(first, (t / 0.5)[:, None], ((t - 0.5) / 0.5)[:, None])
    c = np.where(first, hi + (mid - hi) * tt, mid + (lo - mid) * tt)
    arr = np.zeros((h, w, 4), np.uint8)
    for j in range(3):
        arr[..., j] = np.broadcast_to(c[:, j:j+1].astype(np.uint8), (h, w))
    arr[..., 3] = 255
    img = Image.fromarray(arr, 'RGBA')
    mask = Image.new('L', (w, h), 0)
    ImageDraw.Draw(mask).polygon(lpts, fill=255)
    img.putalpha(Image.composite(img.split()[3], Image.new('L', (w, h), 0), mask))
    return img


def make_jar(w, h, cx, cy, H, level=0.0, falling_star=True,
             monochrome=False, outline_scale=1.0, ground_shadow=False):
    """绘制 Q 版『星雨落瓶』品牌符号，返回 RGBA 图层（w×h）。
    level ∈ [0,1]：0 空瓶 / 0.5 半满 / 1 全满。
    falling_star: 是否画正坠白星 + 曳尾 + 星轨 + 星尘。
    monochrome: 主题图标单色版（纯 alpha 剪影 + 透明液面细弧）。
    ground_shadow: 瓶底落影（仅插画用）。"""
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    g = q_geometry(H)
    lw = max(2, int(0.036 * H * outline_scale))
    pts = q_outline(cx, cy, H, g=g)

    if monochrome:
        d = ImageDraw.Draw(im)
        d.line(pts, fill=(0, 0, 0, 255), width=lw, joint='curve')
        for p in (pts[0], pts[-1]):
            r = lw / 2
            d.ellipse([p[0]-r, p[1]-r, p[0]+r, p[1]+r], fill=(0, 0, 0, 255))
        # 液面：一条透明细弧（把「半满」语义带进单色版）
        ly = lerp(g['bot'] - 0.06, g['top'] + 0.04, level)
        half = g['hb'] - 0.03
        wpts = [(cx + lerp(-half*H, half*H, t),
                 cy + ly*H + 0.018*H*math.sin(math.pi*t))
                for t in np.linspace(0, 1, 60)]
        wipe = Image.new('L', (w, h), 0)
        ImageDraw.Draw(wipe).line(wpts, fill=255,
                                  width=max(2, int(0.030*H)), joint='curve')
        arr = np.asarray(im).astype(np.float32)
        arr[..., 3] = arr[..., 3] / 255.0 * (1 - 0.85 * np.asarray(wipe).astype(np.float32)/255.0) * 255
        im = Image.fromarray(arr.astype(np.uint8), 'RGBA')
        if falling_star:
            d = ImageDraw.Draw(im)
            sx, sy = cx + 0.16*H, cy + (g['top'] - 0.20)*H
            star4_q(d, sx, sy, 0.10*H, (0, 0, 0, 255))
            star_trail(d, sx, sy, sx - 0.07*H, sy + 0.20*H,
                       color=(0, 0, 0), w=max(1, int(0.012*H)))
        return im

    # ---- 彩色版 ----
    # 0) 瓶底柔和落影（仅插画）
    if ground_shadow:
        sh = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        ImageDraw.Draw(sh).ellipse(
            [cx - 0.36*H, cy + (g['bot'] + 0.01)*H,
             cx + 0.36*H, cy + (g['bot'] + 0.075)*H],
            fill=(10, 18, 60, 70))
        im.alpha_composite(sh.filter(ImageFilter.GaussianBlur(0.030*H)))

    # 1) 瓶身：白 → 淡冷蓝纵向渐变（体积感），mask 裁进 Q 轮廓
    jarr = np.zeros((h, w, 4), np.uint8)
    yy, _ = np.mgrid[0:h, 0:w].astype(np.float32)
    jt = np.clip((yy - (cy + g['top']*H)) / ((g['bot'] - g['top'])*H), 0, 1)
    top_c = np.array(WHITE, np.float32)
    bot_c = np.array(JAR_BODY_LO, np.float32)
    for j in range(3):
        jarr[..., j] = (top_c[j] + (bot_c[j] - top_c[j]) * jt).astype(np.uint8)
    jarr[..., 3] = 244
    jar_layer = Image.fromarray(jarr, 'RGBA')
    jmask = Image.new('L', (w, h), 0)
    ImageDraw.Draw(jmask).polygon(pts, fill=255)
    jar_layer.putalpha(Image.composite(jar_layer.split()[3],
                                       Image.new('L', (w, h), 0), jmask))
    im.alpha_composite(jar_layer)

    # 2) 琥珀液体（竖向渐变 + 液面高光 + 白星）
    if level > 0.02:
        lpts = q_liquid(cx, cy, H, level, g)
        surf_y = lpts[0][1]
        im.alpha_composite(liquid_gradient_img(w, h, lpts))
        d = ImageDraw.Draw(im)
        hw = g['hb'] - 0.030
        eh = 0.012*H if level > 0.9 else 0.026*H
        d.ellipse([cx - hw*H, surf_y - eh, cx + hw*H, surf_y + eh],
                  fill=AMBER_L + (250,))
        # 液体内两颗小白星
        sr = 0.050*H
        star4(d, cx - 0.11*H, surf_y + 0.10*H, sr, 0.40, WHITE + (255,))
        star4(d, cx + 0.06*H, surf_y + 0.155*H, sr*0.72, 0.40, WHITE + (235,))

    # 3) 玻璃双层描边：深蓝外圈 + 亮蓝内圈（厚度感）
    d = ImageDraw.Draw(im)
    d.line(pts, fill=BRAND_D + (255,), width=lw, joint='curve')
    for p in (pts[0], pts[-1]):
        r = lw / 2
        d.ellipse([p[0]-r, p[1]-r, p[0]+r, p[1]+r], fill=BRAND_D + (255,))
    lw2 = max(1, int(0.012*H*outline_scale))
    pts2 = q_outline(cx, cy, H, inset=0.022, g=g)
    d.line(pts2, fill=STROKE_HI + (200,), width=lw2, joint='curve')
    # 口沿下沿厚度线
    g_top = cy + g['top']*H
    hm, lip = g['hm'], g['lip']
    d.line([(cx - (hm + lip)*H, g_top + lw*0.75), (cx - hm*H, g_top + lw*0.75)],
           fill=CONT + (180,), width=max(1, int(lw*0.4)))
    d.line([(cx + hm*H, g_top + lw*0.75), (cx + (hm + lip)*H, g_top + lw*0.75)],
           fill=CONT + (180,), width=max(1, int(lw*0.4)))
    # 左壁内侧长高光条
    hl = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    hd = ImageDraw.Draw(hl)
    hx0 = cx - (g['hb'] - 0.03)*H
    hd.line([(hx0, cy - 0.12*H), (hx0 + 0.012*H, cy + 0.16*H)],
            fill=WHITE + (190,), width=max(2, int(0.026*H)))
    im.alpha_composite(hl.filter(ImageFilter.GaussianBlur(0.012*H)))

    # 4) 正坠白星 + 双光晕 + 星轨弧 + 曳尾 + 伴星 + 星尘
    if falling_star:
        sx, sy = cx + 0.16*H, cy + (g['top'] - 0.20)*H
        im.alpha_composite(radial_glow(w, h, sx - 0.04*H, sy - 0.02*H,
                                       0.30*H, GLOW_WARM, 0.55))
        im.alpha_composite(radial_glow(w, h, sx, sy, 0.18*H, WHITE, 0.40))
        d = ImageDraw.Draw(im)
        # 星轨弧（二次贝塞尔）
        p0 = np.array([sx - 0.22*H, sy - 0.08*H])
        p1 = np.array([sx - 0.15*H, sy - 0.26*H])
        p2 = np.array([sx + 0.03*H, sy - 0.18*H])
        tt = np.linspace(0, 1, 48)[:, None]
        arc = (1-tt)**3*p0 + 3*(1-tt)**2*tt*p1 + 3*(1-tt)*tt**2*p1 + tt**3*p2
        d.line([tuple(p) for p in arc], fill=WHITE + (150,),
               width=max(1, int(0.008*H)), joint='curve')
        star_trail(d, sx, sy, sx - 0.07*H, sy + 0.20*H,
                   w=max(1, int(0.010*H)))
        star4_q(d, sx, sy, 0.10*H, WHITE + (255,))
        star4_q(d, sx, sy, 0.055*H, GLOW_WARM + (255,))
        star4_q(d, sx - 0.18*H, sy - 0.08*H, 0.028*H, WHITE + (230,))
        star4_q(d, sx + 0.15*H, sy + 0.13*H, 0.020*H, WHITE + (210,))
        star_dust(im, sx - 0.02*H, sy, 0.20*H, 9, WHITE, seed=11)
    return im


def down(im, size):
    return im.resize(size, Image.LANCZOS)


def compose_foreground(S, mono=False):
    """自适应图标前景：透明底 + 白色柔光晕 + Q 版星瓶"""
    W = Hc = S*SS
    base = Image.new('RGBA', (W, Hc), (0, 0, 0, 0))
    if not mono:
        base.alpha_composite(radial_glow(W, Hc, W/2, Hc*0.58, W*0.42, WHITE, 0.30))
        base.alpha_composite(radial_glow(W, Hc, W*0.64, Hc*0.24, W*0.30, GLOW_WARM, 0.22))
    jh = S*SS*0.58
    jar = make_jar(W, Hc, W/2, Hc*0.575, jh, level=0.5, monochrome=mono)
    base.alpha_composite(jar)
    return down(base, (S, S))


def compose_static(S, round_icon=False):
    """静态启动图标：三段对角渐变底 + 光斑 + Q 版星瓶"""
    W = Hc = S*SS
    bg = diag_gradient(W, Hc, INK_DEEP, BRAND, CYAN_BRIGHT)
    bg.alpha_composite(radial_glow(W, Hc, W*0.66, Hc*0.22, W*0.34, GLOW_WARM, 0.16))
    bg.alpha_composite(radial_glow(W, Hc, W*0.30, Hc*0.80, W*0.36, INK_DEEP, 0.22))
    jh = S*SS*0.58
    bg.alpha_composite(make_jar(W, Hc, W/2, Hc*0.575, jh, level=0.5))
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
    """插画里的 Q 版小落瓶（带落影）。"""
    d = make_jar(IW, IH, cx*IS, cy*IS, H*IS, level=level,
                 falling_star=falling_star, outline_scale=1.3,
                 ground_shadow=True)
    base.alpha_composite(d)


def mini_star_amber(d, cx, cy, R, color=AMBER):
    """插画里的琥珀小闪星（Q 版圆胖）。"""
    star4_q(d, cx*IS, cy*IS, R*IS, color + (255,))


def illus_home():
    """首页空态：渐变圆底 + 两叠白纸卡 + 字行 + Q 版半满小瓶 + 琥珀坠星。"""
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
    # 右下：Q 版半满小瓶
    mini_jar(im, 236, 164, 92, level=0.6, falling_star=False)
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
    """文件夹空态：渐变圆底 + 白色文件夹线稿 + 空中 Q 版空瓶等灵感。"""
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
    # 空中：Q 版空瓶正要落入 + 白色虚线轨迹
    wdash(d, [(206, 40), (200, 54)], 2.0)
    mini_jar(im, 208, 88, 62, level=0.0, falling_star=True)
    # 琥珀小星
    mini_star_amber(d, 250, 34, 9)
    star_dust(im, 210*IS, 44*IS, 22*IS, 6, WHITE, seed=9)
    return down(im, (320, 240))


def illus_graph():
    """关系图空态：渐变圆底 + 白色三节点虚线 + 中央 Q 版半满小瓶。"""
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
    # 中央 Q 版半满小瓶
    mini_jar(im, 160, 130, 68, level=0.5, falling_star=False)
    star_dust(im, 160*IS, 56*IS, 28*IS, 7, WHITE, seed=13)
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
