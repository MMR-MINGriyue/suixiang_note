# -*- coding: utf-8 -*-
"""
随想随记 · 全新美术素材生成（视觉重塑 v2.4）
设计概念：「星雨 · 落瓶」(Star Rain into the Jar)
  - 弃用 v2.3 的「水滴」（用户反馈：水滴离「灵感」太远，且积累没有形象寓意）
  - 品牌符号 = 开口玻璃瓶 + 瓶内琥珀液面（积累） + 正坠的四芒闪星（灵感降临）
    一图双义：正在闪 = 一次灵感来了；液面高度 = 已经攒了多少
  - 琥珀金是「灵感/闪」的专属色（绿仍专属完成、蓝仍专属推进中，语义不冲突）
  - 启动图标取「半满瓶」态：随想随记，永远攒在半路上
  - 全套素材（启动图标 / 空态插画 / 纸纹 / ico）统一到
    奶白纸底 + 雾靛线稿 + 品牌蓝渐变 + 琥珀金点睛 + 极淡径向光晕

本脚本自 v2.3 起是图标/插画/纸纹的唯一权威生成器；
tool/gen_icons.py 与 tool/gen_assets.py 保留为 v1/v2 历史设计档案，勿再执行
（执行会把旧的「蓝环+绿滴」刷回来）。

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

# ---- 色板（严格取自 lib/theme/tokens.dart）----
PAPER   = (250, 247, 242)   # #FAF7F2 纸底
BRAND   = (76, 111, 255)    # #4C6FFF 品牌蓝 / 推进中
BRAND_D = (61, 91, 224)     # #3D5BE0 按下/暗部
BRAND_L = (123, 147, 255)   # #7B93FF 深色模式/亮部
MIST    = (168, 185, 230)   # #A8B9E6 灵感 / 线稿
LINE    = (139, 161, 219)   # 主线稿：比 MIST 深一档，2x 下发虚也不糊
LINE2   = (198, 210, 240)   # 次线稿 / 虚线
CONT    = (232, 237, 255)   # #E8EDFF 品牌容器 / 光晕
DONE    = (47, 191, 143)    # #2FBF8F 完成
AMBER   = (255, 176, 59)    # #FFB03B 琥珀金 / 灵感闪星（v2.4 新增专属色）
AMBER_L = (255, 214, 140)   # 亮部 / 液面
AMBER_D = (222, 138, 22)    # #DE8A16 暗部 / 液体阴影
WHITE   = (255, 255, 255)

SS = 4  # 超采样倍数（抗锯齿）


def lerp(a, b, t):
    return a + (b - a) * t


def bezier(p0, p1, p2, p3, n=140):
    t = np.linspace(0, 1, n)[:, None]
    return ((1-t)**3 * p0 + 3*(1-t)**2*t * p1
            + 3*(1-t)*t**2 * p2 + t**3 * p3)


def jar_geometry(H):
    """开口玻璃瓶几何（单位坐标，×H + 中心）。
    口半宽 0.26 / 腹半宽 0.34 / 口沿 y=-0.36 / 底 y=+0.30 / 底圆角 0.12。
    y 向下为正，原点在瓶中心。"""
    return dict(hw_mouth=0.26, hw_belly=0.34, top_y=-0.36, bot_y=0.30,
                corner=0.12, lip=0.07)


def _wall_x(unit_y, g):
    """给定单位 y，返回瓶身内壁半宽（口→腹在肩部 0.10 内线性张开）。"""
    shoulder0, shoulder1 = g['top_y'], g['top_y'] + 0.10
    if unit_y <= shoulder0:
        return g['hw_mouth']
    t = min(1.0, (unit_y - shoulder0) / (shoulder1 - shoulder0))
    return lerp(g['hw_mouth'], g['hw_belly'], t)


def jar_outline(cx, cy, H, g=None):
    """玻璃壁完整轮廓（含口沿外挑），点集（像素坐标）。"""
    if g is None:
        g = jar_geometry(H)
    hm, hb = g['hw_mouth'], g['hw_belly']
    top, bot, cr, lip = g['top_y'], g['bot_y'], g['corner'], g['lip']
    P = lambda ux, uy: (cx + ux*H, cy + uy*H)

    pts = [P(-hm - lip, top)]                      # 左口沿外端
    pts.append(P(-hm, top))
    pts.append(P(-hb, top + 0.10))                 # 左肩张开
    pts.append(P(-hb, bot - cr))                   # 左壁直段
    # 左下圆角：圆心 (-hb+cr, bot-cr)，从 180° 到 90°
    for a in np.linspace(math.pi, math.pi/2, 30):
        pts.append((cx + (-hb+cr)*H + cr*H*math.cos(a),
                    cy + (bot-cr)*H + cr*H*math.sin(a)))
    pts.append(P(hb - cr, bot))                    # 底部直段
    # 右下圆角：圆心 (hb-cr, bot-cr)，从 90° 到 0°
    for a in np.linspace(math.pi/2, 0, 30):
        pts.append((cx + (hb-cr)*H + cr*H*math.cos(a),
                    cy + (bot-cr)*H + cr*H*math.sin(a)))
    pts.append(P(hb, bot - cr))
    pts.append(P(hb, top + 0.10))                  # 右壁直段
    pts.append(P(hm, top))                         # 右肩收口
    pts.append(P(hm + lip, top))                   # 右口沿外端
    return pts


def jar_liquid(cx, cy, H, level, g=None):
    """液面以下闭合区域点集。level ∈ [0,1]：0 空 / 0.5 半满 / 1 满。
    液面 y 在 [bot-0.07, top+0.05] 内插值（level 越大液面越高、ly 越小）；
    液面宽按内壁收 0.025 留出玻璃厚。
    顶点顺序：液面左 → 液面右 → 右壁下行 → 右下圆角 → 底部直段
    → 左下圆角 → 左壁上行，闭合。"""
    if g is None:
        g = jar_geometry(H)
    top, bot, cr, inset = g['top_y'], g['bot_y'], g['corner'], 0.025
    ly = lerp(bot - 0.07, top + 0.05, level)
    P = lambda ux, uy: (cx + ux*H, cy + uy*H)
    hw = _wall_x(ly, g) - inset
    rr = min(cr, hw)                                # 有效圆角（不超液面半宽）
    ly = min(ly, bot - rr)                          # 液面不低于圆角起点，避免右壁段翻折

    pts = [P(-hw, ly)]                             # 液面左
    pts.append(P(hw, ly))                          # 液面右
    pts.append(P(hw, bot - rr))                    # 右壁直段
    # 右下圆角：从 (hw, bot-rr) 到 (hw-rr, bot)，圆心 (hw-rr, bot-rr)，
    # 角度 0 → pi/2（cos 从 1→0，sin 从 0→1，y 向下为正所以向下弯）
    for a in np.linspace(0, math.pi/2, 30):
        pts.append((cx + (hw-rr)*H + rr*H*math.cos(a),
                    cy + (bot-rr)*H + rr*H*math.sin(a)))
    pts.append(P(-hw + rr, bot))                   # 底部直段
    # 左下圆角：从 (-hw+rr, bot) 到 (-hw, bot-rr)，圆心 (-hw+rr, bot-rr)，
    # 角度 pi/2 → pi（cos 从 0→-1，sin 从 1→0）
    for a in np.linspace(math.pi/2, math.pi, 30):
        pts.append((cx + (-hw+rr)*H + rr*H*math.cos(a),
                    cy + (bot-rr)*H + rr*H*math.sin(a)))
    pts.append(P(-hw, bot - rr))                   # 左壁直段
    return pts                                     # 闭合回液面左


def star4(d, cx, cy, R, ratio, color, rot=-math.pi/2, outline_w=0):
    """四芒星（8 点多边形）。outline_w>0 时只描边。"""
    pts = []
    for i in range(8):
        r = R if i % 2 == 0 else R * ratio
        a = rot + i * math.pi / 4
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    if outline_w > 0:
        d.polygon(pts, outline=color, width=int(outline_w))
    else:
        d.polygon(pts, fill=color)


def star_trail(d, sx, sy, tx, ty, color=AMBER_L, w=3):
    """闪星坠落的曳尾：两条渐隐斜线（长 + 短）。坐标为像素。"""
    dx, dy = tx - sx, ty - sy
    L = math.hypot(dx, dy) or 1.0
    ux, uy = dx / L, dy / L
    px, py = -uy, ux  # 垂直方向
    for (t0, t1, ww, al) in [(0.0, 0.85, w, 170), (0.12, 0.62, w * 0.6, 110)]:
        d.line([(sx + ux*L*t0 + px*ww, sy + uy*L*t0 + py*ww),
                (sx + ux*L*t1 + px*ww*0.3, sy + uy*L*t1 + py*ww*0.3)],
               fill=color + (al,), width=max(1, int(ww)))
        d.line([(sx + ux*L*t0 - px*ww, sy + uy*L*t0 - py*ww),
                (sx + ux*L*t1 - px*ww*0.3, sy + uy*L*t1 - py*ww*0.3)],
               fill=color + (al,), width=max(1, int(ww)))


def radial_glow(w, h, cx, cy, radius, color, peak):
    """径向淡光晕 RGBA（边缘完全透明，不会在启动器上露出方块）"""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    r2 = ((xx-cx)**2 + (yy-cy)**2) / (radius**2)
    al = (peak * np.exp(-2.4*r2)).clip(0, 1)
    arr = np.zeros((h, w, 4), np.float32)
    arr[..., 0] = color[0]; arr[..., 1] = color[1]; arr[..., 2] = color[2]
    arr[..., 3] = al * 255
    return Image.fromarray(arr.astype(np.uint8), 'RGBA')


def make_jar(w, h, cx, cy, H, level=0.0, falling_star=True,
             monochrome=False, outline_scale=1.0):
    """绘制『星雨落瓶』品牌符号，返回 RGBA 图层（w×h，超采样画布尺寸）。
    level ∈ [0,1]：0 空瓶 / 0.5 半满 / 1 全满（液面在瓶身内插值）。
    falling_star: 是否画正坠闪星 + 曳尾。
    monochrome: 主题图标单色版（纯 alpha 剪影 + 透明液面细弧）。"""
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    g = jar_geometry(H)
    lip_w = max(2, int(0.034 * H * outline_scale))   # 玻璃壁描边宽

    if monochrome:
        d = ImageDraw.Draw(im)
        pts = jar_outline(cx, cy, H, g)
        d.line(pts, fill=(0, 0, 0, 255), width=lip_w, joint='curve')
        for p in (pts[0], pts[-1]):
            r = lip_w / 2
            d.ellipse([p[0]-r, p[1]-r, p[0]+r, p[1]+r], fill=(0, 0, 0, 255))
        # 液面：一条透明细弧（把「半满」语义带进单色版）
        ly = lerp(g['bot_y'] - 0.07, g['top_y'] + 0.05, level)
        half = _wall_x(ly, g) - 0.03
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
            sx, sy = cx + 0.14*H, cy + (g['top_y'] - 0.18)*H
            star4(d, sx, sy, 0.10*H, 0.30, (0, 0, 0, 255))
            # 曳尾（单色里也保留，纯 alpha）
            star_trail(d, sx, sy, sx - 0.07*H, sy + 0.20*H,
                       color=(0, 0, 0), w=max(1, int(0.012*H)))
        return im

    # ---- 彩色版 ----
    # 1) 琥珀液体（先画，玻璃壁叠在上面）
    if level > 0.02:
        lpts = jar_liquid(cx, cy, H, level, g)
        liquid = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        ld = ImageDraw.Draw(liquid)
        # 液面微凸椭圆：贴着液面画在液体同层。液面像素 y 必须含 cy，
        # 否则椭圆与白星会浮到画布顶部（v2.4 首版的真实 bug）；直接取
        # 液体 polygon 首点，与 jar_liquid 共用同一液面。
        surf_y = lpts[0][1]
        ly = lerp(g['bot_y'] - 0.07, g['top_y'] + 0.05, level)
        half = _wall_x(ly, g) - 0.025
        eh = 0.012*H if level > 0.9 else 0.030*H   # 满瓶压扁，只留一条高光
        ld.ellipse([cx - half*H, surf_y - eh, cx + half*H, surf_y + eh],
                   fill=AMBER_L + (240,))
        ld.polygon(lpts, fill=AMBER + (235,))
        # 液体内两颗小白星（攒下的灵感还在闪）
        sr = 0.052*H
        star4(ld, cx - 0.12*H, surf_y + 0.11*H, sr, 0.34, WHITE + (255,))
        star4(ld, cx + 0.06*H, surf_y + 0.16*H, sr*0.75, 0.34, WHITE + (235,))
        # 液体左缘暗琥珀阴影带
        sh = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        sd = ImageDraw.Draw(sh)
        sd.line([(lpts[0][0] + 0.03*H, lpts[0][1] + 0.02*H),
                 (lpts[0][0] + 0.035*H, cy + (g['bot_y'] - 0.10)*H)],
                fill=AMBER_D + (150,), width=max(2, int(0.045*H)))
        sh = sh.filter(ImageFilter.GaussianBlur(0.02*H))
        # 只保留液体区域内的阴影
        mask_im = Image.new('L', (w, h), 0)
        ImageDraw.Draw(mask_im).polygon(lpts, fill=255)
        sh.putalpha(Image.composite(sh.split()[3], Image.new('L', (w, h), 0), mask_im))
        liquid.alpha_composite(sh)
        im.alpha_composite(liquid)

    # 2) 玻璃壁（品牌蓝描边 + 内侧淡蓝高光条）
    d = ImageDraw.Draw(im)
    pts = jar_outline(cx, cy, H, g)
    d.line(pts, fill=BRAND_D + (255,), width=lip_w, joint='curve')
    for p in (pts[0], pts[-1]):
        r = lip_w / 2
        d.ellipse([p[0]-r, p[1]-r, p[0]+r, p[1]+r], fill=BRAND_D + (255,))
    # 左壁内侧淡蓝高光条（玻璃质感，细而低调）
    hl = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    hd = ImageDraw.Draw(hl)
    hx0 = cx - (g['hw_belly'] - 0.06)*H
    hd.line([(hx0, cy - 0.12*H), (hx0 + 0.010*H, cy + 0.16*H)],
            fill=CONT + (150,), width=max(2, int(0.024*H)))
    hl = hl.filter(ImageFilter.GaussianBlur(0.012*H))
    im.alpha_composite(hl)

    # 3) 正坠闪星 + 曳尾（瓶口上方偏右）
    if falling_star:
        sx, sy = cx + 0.14*H, cy + (g['top_y'] - 0.18)*H
        im.alpha_composite(radial_glow(w, h, sx, sy, 0.22*H, AMBER_L, 0.5))
        d = ImageDraw.Draw(im)
        star_trail(d, sx, sy, sx - 0.08*H, sy + 0.22*H, w=max(1, int(0.010*H)))
        star4(d, sx, sy, 0.10*H, 0.30, AMBER)
        star4(d, sx, sy, 0.045*H, 0.42, AMBER_L)
    return im


def down(im, size):
    return im.resize(size, Image.LANCZOS)


def compose_foreground(S, mono=False):
    """自适应图标前景：透明底 + 淡光晕 + 星雨落瓶"""
    W = Hc = S*SS
    base = radial_glow(W, Hc, W/2, Hc/2, W*0.46, CONT, 0.30)
    jh = S*SS*0.58                      # 瓶高占画布 58%（含闪星域）
    jar = make_jar(W, Hc, W/2, Hc*0.60, jh, level=0.5, monochrome=mono)
    if mono:
        return down(jar, (S, S))        # 单色版不放光晕（纯 alpha mask）
    base.alpha_composite(jar)
    return down(base, (S, S))


def compose_static(S, round_icon=False):
    """静态启动图标：奶白圆角/圆形底 + 光晕 + 星雨落瓶"""
    W = Hc = S*SS
    if round_icon:
        bg = Image.new('RGBA', (W, Hc), (0, 0, 0, 0))
        ImageDraw.Draw(bg).ellipse([0, 0, W-1, Hc-1], fill=PAPER+(255,))
    else:
        bg = Image.new('RGBA', (W, Hc), (0, 0, 0, 0))
        ImageDraw.Draw(bg).rounded_rectangle(
            [0, 0, W-1, Hc-1], radius=int(W*0.225), fill=PAPER+(255,))
    bg.alpha_composite(radial_glow(W, Hc, W/2, Hc*0.55, W*0.44, CONT, 0.55))
    jh = S*SS*0.58
    bg.alpha_composite(make_jar(W, Hc, W/2, Hc*0.60, jh, level=0.5))
    return down(bg, (S, S))


# ---------------- 空态插画 ----------------
IS = 3          # 插画超采样
IW, IH = 320*IS, 240*IS


def line(draw, pts, width, color=LINE, dash=None):
    """圆头折线；dash=(实长,空长) 时画虚线"""
    color = color + (255,)
    w = int(width*IS)
    if dash is None:
        draw.line([(x*IS, y*IS) for x, y in pts], fill=color, width=w, joint='curve')
    else:
        on, off = dash
        for a, b in zip(pts[:-1], pts[1:]):
            dx, dy = b[0]-a[0], b[1]-a[1]
            L = math.hypot(dx, dy)
            if L == 0: continue
            ux, uy = dx/L, dy/L
            p = 0.0
            while p < L:
                q = min(p+on, L)
                draw.line([((a[0]+ux*p)*IS, (a[1]+uy*p)*IS),
                           ((a[0]+ux*q)*IS, (a[1]+uy*q)*IS)],
                          fill=color, width=w)
                # 圆头
                for (xx, yy) in [((a[0]+ux*p), (a[1]+uy*p)),
                                 ((a[0]+ux*q), (a[1]+uy*q))]:
                    r = w/2
                    draw.ellipse([(xx*IS-r), (yy*IS-r), (xx*IS+r), (yy*IS+r)], fill=color)
                p = q + off
    for x, y in (pts[0], pts[-1]):
        r = w/2
        draw.ellipse([x*IS-r, y*IS-r, x*IS+r, y*IS+r], fill=color)


def rrect(draw, box, radius, width, color=MIST, fill=None):
    f = (fill + (255,)) if fill else None
    draw.rounded_rectangle([v*IS for v in box], radius=radius*IS,
                           outline=color+(255,), width=int(width*IS), fill=f)


def mini_star(d, cx, cy, R, color=AMBER, rot=-math.pi/2):
    """插画里的点缀小闪星（四芒）。"""
    star4(d, cx*IS, cy*IS, R*IS, 0.30, color + (255,), rot=rot)


def mini_jar(base, cx, cy, H, level=0.0, falling_star=True):
    """插画里的点缀小落瓶。"""
    d = make_jar(IW, IH, cx*IS, cy*IS, H*IS, level=level,
                 falling_star=falling_star, outline_scale=1.3)
    base.alpha_composite(d)


def illus_home():
    im = Image.new('RGBA', (IW, IH), (0, 0, 0, 0))
    im.alpha_composite(radial_glow(IW, IH, 160*IS, 120*IS, 115*IS, CONT, 0.42))
    d = ImageDraw.Draw(im)
    # 三张错叠纸卡
    rrect(d, (58, 88, 214, 190), 11, 2.0, color=LINE2)
    rrect(d, (78, 72, 236, 176), 11, 2.0, color=(184, 199, 234))
    rrect(d, (100, 56, 258, 160), 12, 2.4, color=MIST, fill=(252, 251, 248))
    line(d, [(122, 88), (224, 88)], 3.0)
    line(d, [(122, 110), (196, 110)], 3.0, color=LINE2)
    # 右侧：小落瓶（半满）+ 正在坠落的闪星（带曳尾虚线）
    line(d, [(252, 30), (262, 48)], 2.2, dash=(6, 7), color=LINE2)
    mini_jar(im, 238, 158, 96, level=0.6)
    return down(im, (320, 240))


def illus_folder():
    im = Image.new('RGBA', (IW, IH), (0, 0, 0, 0))
    im.alpha_composite(radial_glow(IW, IH, 160*IS, 125*IS, 112*IS, CONT, 0.42))
    d = ImageDraw.Draw(im)
    # 后片（带折角标签）
    line(d, [(56, 78), (128, 78), (146, 96), (254, 96), (254, 176), (56, 176), (56, 78)], 2.4)
    # 露出的一张空白纸
    rrect(d, (86, 66, 224, 152), 8, 2.0, color=LINE2, fill=(252, 251, 248))
    line(d, [(106, 92), (186, 92)], 2.6, color=LINE2)
    line(d, [(106, 112), (166, 112)], 2.6, color=LINE2)
    # 前片（梯形）
    line(d, [(46, 118), (266, 118), (246, 196), (66, 196), (46, 118)], 2.6)
    # 上方小落瓶（空瓶等灵感）+ 闪星虚线
    mini_jar(im, 160, 128, 76, level=0.0, falling_star=True)
    line(d, [(160, 60), (160, 66)], 2.0, dash=(5, 6), color=LINE2)
    return down(im, (320, 240))


def illus_graph():
    im = Image.new('RGBA', (IW, IH), (0, 0, 0, 0))
    im.alpha_composite(radial_glow(IW, IH, 160*IS, 118*IS, 112*IS, CONT, 0.42))
    d = ImageDraw.Draw(im)
    # 三条虚线连接（一条刻意断开 = 还没有关联）
    line(d, [(92, 78), (224, 78)], 2.2, dash=(9, 9), color=LINE2)
    line(d, [(92, 78), (160, 176)], 2.2, dash=(9, 9), color=LINE2)
    line(d, [(224, 78), (160, 176)], 2.2, dash=(9, 9), color=LINE2)
    # 三个节点环
    for (x, y, c) in [(92, 78, BRAND), (224, 78, BRAND), (160, 176, DONE)]:
        r = 17
        d.ellipse([(x-r)*IS, (y-r)*IS, (x+r)*IS, (y+r)*IS],
                  outline=MIST+(255,), width=int(2.6*IS))
        d.ellipse([(x-7)*IS, (y-7)*IS, (x+7)*IS, (y+7)*IS], fill=c+(255,))
    # 中央小落瓶（半满）
    mini_jar(im, 160, 130, 70, level=0.5)
    return down(im, (320, 240))


def illus_trash():
    im = Image.new('RGBA', (IW, IH), (0, 0, 0, 0))
    im.alpha_composite(radial_glow(IW, IH, 160*IS, 128*IS, 110*IS, CONT, 0.42))
    d = ImageDraw.Draw(im)
    # 桶盖 + 提手
    line(d, [(86, 92), (234, 92)], 2.6)
    line(d, [(140, 92), (146, 76), (174, 76), (180, 92)], 2.4)
    # 桶身（上宽下窄）
    line(d, [(98, 100), (222, 100), (208, 192), (112, 192), (98, 100)], 2.6)
    # 桶身竖线纹理
    line(d, [(134, 118), (139, 174)], 2.2, color=LINE2)
    line(d, [(160, 118), (160, 174)], 2.2, color=LINE2)
    line(d, [(186, 118), (181, 174)], 2.2, color=LINE2)
    # 飘出的小闪星（回收 = 灵感并未消失，还能再落进瓶里）
    mini_star(d, 122, 52, 9)
    mini_star(d, 196, 38, 12)
    mini_star(d, 160, 30, 7, color=AMBER_L)
    return down(im, (320, 240))


# ---------------- 纸纹（暖灰细噪，更贴纸感）----------------
def paper_texture(dark):
    """8×8 纸纤维细噪：alpha 恒 255，靠 PaperTexture 的 Opacity 稀释成 3%/1.5%。
    浅色用冷灰压暖白纸底，深色用浅灰提亮深底，都比旧版（几乎全透明）更可读。"""
    rng = np.random.default_rng(20231110 if not dark else 20231111)
    n = rng.normal(0, 1, (8, 8))
    if dark:
        rgb = np.stack([180 + n*22, 186 + n*22, 200 + n*22], axis=-1)
    else:
        rgb = np.stack([118 + n*30, 124 + n*30, 138 + n*30], axis=-1)
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
