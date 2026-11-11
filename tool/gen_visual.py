# -*- coding: utf-8 -*-
"""
随想随记 · 全新美术素材生成（视觉重塑 v2.4 / 美术丰富化 v2.4.1）
设计概念：「星雨 · 落瓶」(Star Rain into the Jar)
  - 弃用 v2.3 的「水滴」（用户反馈：水滴离「灵感」太远，且积累没有形象寓意）
  - 品牌符号 = 开口玻璃瓶 + 瓶内琥珀液面（积累） + 正坠的四芒闪星（灵感降临）
     一图双义：正在闪 = 一次灵感来了；液面高度 = 已经攒了多少
  - 琥珀金是「灵感/闪」的专属色（绿仍专属完成、蓝仍专属推进中，语义不冲突）
  - 启动图标取「半满瓶」态：随想随记，永远攒在半路上

v2.4.1 美术丰富化（用户：整体风格太简单，要更丰富精致）：
  - 更多场景细节：胶带 / 字行 / 小标签 / 节点标签 / 飘散星尘
  - 光感与质感：液体竖向渐变、玻璃厚度双高光、液面折射、底部弧光、
     多层柔和光晕、瓶底落影（仅插画）
  - 更闪的星轨光斑：主星 + 伴星 + 星轨弧 + 星尘 + 暖色光斑
  - 更饱满的底色与纸感：暖色渐层纸底、边角暖阴影、纤维感纸纹
  - 覆盖范围：四态图标 + 四张空态插画 + 纸纹（App 内呈现见 empty_state.dart）
  ★ 几何（jar_geometry / jar_outline / jar_liquid）逐字未改，与
    lib/ui/widgets/drop_shape.dart 及 test/drop_shape_test.dart 同源。

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

# ---- v2.4.1 美术丰富化补充色 ----
PAPER_HI  = (255, 252, 246)   # 纸底中心暖高光
PAPER_LO  = (237, 228, 212)   # 纸底四角暖阴影
GLOW_WARM = (255, 227, 172)   # 暖色光斑（星轨氛围 / 更饱满的底色）
TAPE      = (216, 226, 248)   # 半透明胶带（雾靛）

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


def paper_base(w, h):
    """不透明奶白纸底：中心暖高光 → 四角暖阴影的柔和渐层（v2.4.1）。"""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    nx = (xx - w * 0.5) / (w * 0.5)
    ny = (yy - h * 0.5) / (h * 0.5)
    r = np.clip(np.sqrt(nx * nx + ny * ny) / 1.414, 0, 1)[..., None]
    hi = np.array(PAPER_HI, np.float32)
    lo = np.array(PAPER_LO, np.float32)
    rgb = hi * (1 - r) + lo * r
    arr = np.zeros((h, w, 4), np.uint8)
    arr[..., :3] = rgb.astype(np.uint8)
    arr[..., 3] = 255
    return Image.fromarray(arr, 'RGBA')


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


def liquid_gradient(w, h, lpts):
    """液体竖向渐变层：液面 AMBER_L → 中部 AMBER → 瓶底 AMBER_D，
    用 polygon mask 裁进瓶身。返回 RGBA 图层（v2.4.1 质感层次）。"""
    ys = [p[1] for p in lpts]
    y_top, y_bot = min(ys), max(ys)
    t = np.clip((np.arange(h, dtype=np.float32) - y_top)
                / max(1.0, y_bot - y_top), 0.0, 1.0)          # (h,)
    hi = np.array(AMBER_L, np.float32)
    mid = np.array(AMBER, np.float32)
    lo = np.array(AMBER_D, np.float32)
    first = (t <= 0.5)[:, None]                               # (h,1)
    tt = np.where(first, (t / 0.5)[:, None],
                  ((t - 0.5) / 0.5)[:, None])                 # (h,1)
    c = np.where(first, hi + (mid - hi) * tt,
                 mid + (lo - mid) * tt)                        # (h,3)
    arr = np.zeros((h, w, 4), np.uint8)
    arr[..., 0] = np.broadcast_to(c[:, 0:1].astype(np.uint8), (h, w))
    arr[..., 1] = np.broadcast_to(c[:, 1:2].astype(np.uint8), (h, w))
    arr[..., 2] = np.broadcast_to(c[:, 2:3].astype(np.uint8), (h, w))
    arr[..., 3] = 238
    img = Image.fromarray(arr, 'RGBA')
    mask = Image.new('L', (w, h), 0)
    ImageDraw.Draw(mask).polygon(lpts, fill=255)
    img.putalpha(Image.composite(img.split()[3], Image.new('L', (w, h), 0), mask))
    return img


def make_jar(w, h, cx, cy, H, level=0.0, falling_star=True,
             monochrome=False, outline_scale=1.0, ground_shadow=False):
    """绘制『星雨落瓶』品牌符号，返回 RGBA 图层（w×h，超采样画布尺寸）。
    level ∈ [0,1]：0 空瓶 / 0.5 半满 / 1 全满（液面在瓶身内插值）。
    falling_star: 是否画正坠闪星 + 曳尾 + 星轨 + 星尘。
    monochrome: 主题图标单色版（纯 alpha 剪影 + 透明液面细弧）。
    ground_shadow: 瓶底落影（仅插画用；透明底图标不加）。"""
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
            star_trail(d, sx, sy, sx - 0.07*H, sy + 0.20*H,
                       color=(0, 0, 0), w=max(1, int(0.012*H)))
        return im

    # ---- 彩色版 ----
    # 0) 瓶底柔和落影（仅插画，透明底图标不加）
    if ground_shadow:
        sh = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        ImageDraw.Draw(sh).ellipse(
            [cx - 0.34*H, cy + 0.31*H, cx + 0.34*H, cy + 0.375*H],
            fill=(120, 104, 78, 52))
        im.alpha_composite(sh.filter(ImageFilter.GaussianBlur(0.030*H)))

    # 1) 琥珀液体（竖向渐变 + 液面高光 + 白星 + 阴影带）
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
        # 液体主体：竖向渐变（顶亮 → 底暗），mask 裁进瓶身
        liquid.alpha_composite(liquid_gradient(w, h, lpts))
        # 顶层装饰重取 draw（不被渐变盖住）
        ld = ImageDraw.Draw(liquid)
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
        mask_im = Image.new('L', (w, h), 0)
        ImageDraw.Draw(mask_im).polygon(lpts, fill=255)
        sh.putalpha(Image.composite(sh.split()[3], Image.new('L', (w, h), 0), mask_im))
        liquid.alpha_composite(sh)
        im.alpha_composite(liquid)

    # 2) 玻璃壁（品牌蓝描边 + 内侧淡蓝双高光 + 口沿下沿厚度线）
    d = ImageDraw.Draw(im)
    pts = jar_outline(cx, cy, H, g)
    d.line(pts, fill=BRAND_D + (255,), width=lip_w, joint='curve')
    for p in (pts[0], pts[-1]):
        r = lip_w / 2
        d.ellipse([p[0]-r, p[1]-r, p[0]+r, p[1]+r], fill=BRAND_D + (255,))
    # 口沿下沿：一条淡亮厚度线（玻璃口沿的双层质感）
    d.line([(cx - (g['hw_mouth'] + g['lip'])*H, cy + g['top_y']*H + lip_w*0.7),
            (cx - g['hw_mouth']*H, cy + g['top_y']*H + lip_w*0.7)],
           fill=CONT + (170,), width=max(1, int(lip_w*0.40)))
    d.line([(cx + g['hw_mouth']*H, cy + g['top_y']*H + lip_w*0.7),
            (cx + (g['hw_mouth'] + g['lip'])*H, cy + g['top_y']*H + lip_w*0.7)],
           fill=CONT + (170,), width=max(1, int(lip_w*0.40)))
    # 左壁内侧双高光（长淡条 + 短亮点），玻璃质感
    hl = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    hd = ImageDraw.Draw(hl)
    hx0 = cx - (g['hw_belly'] - 0.06)*H
    hd.line([(hx0, cy - 0.12*H), (hx0 + 0.010*H, cy + 0.16*H)],
            fill=CONT + (150,), width=max(2, int(0.024*H)))
    hd.line([(hx0 - 0.018*H, cy - 0.06*H), (hx0 - 0.013*H, cy + 0.02*H)],
            fill=WHITE + (170,), width=max(1, int(0.014*H)))
    im.alpha_composite(hl.filter(ImageFilter.GaussianBlur(0.012*H)))

    # 3) 正坠闪星 + 星轨 + 伴星 + 星尘 + 暖色光斑（v2.4.1 更闪）
    if falling_star:
        sx, sy = cx + 0.14*H, cy + (g['top_y'] - 0.18)*H
        im.alpha_composite(radial_glow(w, h, sx - 0.04*H, sy - 0.02*H,
                                       0.32*H, GLOW_WARM, 0.34))
        im.alpha_composite(radial_glow(w, h, sx, sy, 0.22*H, AMBER_L, 0.5))
        d = ImageDraw.Draw(im)
        # 一条细星轨弧（灵感划过的轨迹）：二次贝塞尔，平滑无折角
        p0 = np.array([sx - 0.24*H, sy - 0.10*H])
        p1 = np.array([sx - 0.16*H, sy - 0.30*H])
        p2 = np.array([sx + 0.02*H, sy - 0.20*H])
        arc = bezier(p0, p1, p1, p2, n=48)
        d.line([tuple(p) for p in arc], fill=AMBER_L + (120,),
               width=max(1, int(0.007*H)), joint='curve')
        star_trail(d, sx, sy, sx - 0.08*H, sy + 0.22*H, w=max(1, int(0.010*H)))
        star4(d, sx, sy, 0.10*H, 0.30, AMBER)
        star4(d, sx, sy, 0.045*H, 0.42, AMBER_L)
        # 两颗伴星
        star4(d, sx - 0.19*H, sy - 0.10*H, 0.028*H, 0.32, AMBER_L)
        star4(d, sx + 0.16*H, sy + 0.15*H, 0.020*H, 0.32, AMBER_L)
        star_dust(im, sx - 0.02*H, sy, 0.22*H, 9, AMBER_L, seed=11)
    return im


def down(im, size):
    return im.resize(size, Image.LANCZOS)


def compose_foreground(S, mono=False):
    """自适应图标前景：透明底 + 淡光晕 + 暖光斑 + 星雨落瓶"""
    W = Hc = S*SS
    base = radial_glow(W, Hc, W/2, Hc/2, W*0.46, CONT, 0.30)
    base.alpha_composite(radial_glow(W, Hc, W/2, Hc*0.52, W*0.38, GLOW_WARM, 0.20))
    jh = S*SS*0.58                      # 瓶高占画布 58%（含闪星域）
    jar = make_jar(W, Hc, W/2, Hc*0.60, jh, level=0.5, monochrome=mono)
    if mono:
        return down(jar, (S, S))        # 单色版不放光晕（纯 alpha mask）
    base.alpha_composite(jar)
    return down(base, (S, S))


def compose_static(S, round_icon=False):
    """静态启动图标：暖色渐层圆角/圆形底 + 多层光晕 + 星雨落瓶"""
    W = Hc = S*SS
    bg = paper_base(W, Hc)              # 不透明暖渐层纸底
    bg.alpha_composite(radial_glow(W, Hc, W/2, Hc*0.55, W*0.44, CONT, 0.50))
    bg.alpha_composite(radial_glow(W, Hc, W/2, Hc*0.50, W*0.36, GLOW_WARM, 0.28))
    jh = S*SS*0.58
    bg.alpha_composite(make_jar(W, Hc, W/2, Hc*0.60, jh, level=0.5))
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
    """插画里的点缀小落瓶（带落影）。"""
    d = make_jar(IW, IH, cx*IS, cy*IS, H*IS, level=level,
                 falling_star=falling_star, outline_scale=1.3,
                 ground_shadow=True)
    base.alpha_composite(d)


def illus_home():
    """首页空态：三叠纸卡 + 胶带 + 字行 + 半满落瓶 + 星尘光斑。"""
    im = Image.new('RGBA', (IW, IH), (0, 0, 0, 0))
    im.alpha_composite(radial_glow(IW, IH, 160*IS, 120*IS, 120*IS, CONT, 0.42))
    im.alpha_composite(radial_glow(IW, IH, 176*IS, 104*IS, 92*IS, GLOW_WARM, 0.30))
    d = ImageDraw.Draw(im)
    # 三张错叠纸卡
    rrect(d, (58, 88, 214, 190), 11, 2.0, color=LINE2)
    rrect(d, (78, 72, 236, 176), 11, 2.0, color=(184, 199, 234))
    rrect(d, (100, 56, 258, 160), 12, 2.4, color=MIST, fill=(252, 251, 248))
    # 主卡字行 + 一枚小圆徽记
    line(d, [(122, 88), (224, 88)], 3.0)
    line(d, [(122, 110), (196, 110)], 3.0, color=LINE2)
    line(d, [(122, 128), (172, 128)], 2.6, color=LINE2)
    d.ellipse([(230*IS), (80*IS), (240*IS), (90*IS)], outline=MIST+(255,), width=2*IS)
    # 顶部胶带（半透明斜四边形）
    d.polygon([(168*IS, 48*IS), (196*IS, 44*IS), (200*IS, 60*IS), (172*IS, 64*IS)],
              fill=TAPE + (200,))
    # 左上角两颗小闪星 + 星尘
    mini_star(d, 46, 54, 6, color=AMBER_L)
    mini_star(d, 70, 40, 4, color=AMBER)
    star_dust(im, 60*IS, 52*IS, 26*IS, 7, AMBER_L, seed=3)
    # 右侧：小落瓶（半满）+ 坠落闪星虚线 + 星尘
    line(d, [(252, 30), (262, 48)], 2.2, dash=(6, 7), color=LINE2)
    mini_jar(im, 238, 158, 96, level=0.6)
    star_dust(im, 250*IS, 60*IS, 22*IS, 6, AMBER_L, seed=5)
    return down(im, (320, 240))


def illus_folder():
    """文件夹空态：文件夹 + 露出的纸 + 字行小标签 + 空中正要落入的空瓶。"""
    im = Image.new('RGBA', (IW, IH), (0, 0, 0, 0))
    im.alpha_composite(radial_glow(IW, IH, 160*IS, 125*IS, 116*IS, CONT, 0.42))
    im.alpha_composite(radial_glow(IW, IH, 196*IS, 84*IS, 80*IS, GLOW_WARM, 0.30))
    d = ImageDraw.Draw(im)
    # 后片（带折角标签）
    line(d, [(56, 78), (128, 78), (146, 96), (254, 96), (254, 176), (56, 176), (56, 78)], 2.4)
    # 露出的一张空白纸 + 字行 + 右上小标签
    rrect(d, (86, 66, 224, 152), 8, 2.0, color=LINE2, fill=(252, 251, 248))
    line(d, [(106, 92), (186, 92)], 2.6, color=LINE2)
    line(d, [(106, 112), (166, 112)], 2.6, color=LINE2)
    line(d, [(106, 130), (150, 130)], 2.4, color=LINE2)
    rrect(d, (186, 76, 210, 90), 4, 1.8, color=MIST, fill=(238, 243, 255))
    # 前片（梯形）+ 前片上一道淡横线（层次）
    line(d, [(46, 118), (266, 118), (246, 196), (66, 196), (46, 118)], 2.6)
    line(d, [(60, 132), (260, 132)], 1.8, color=LINE2)
    # 空中：小落瓶（空瓶等灵感）正要落入，配虚线轨迹 + 星尘
    line(d, [(212, 44), (206, 58)], 2.0, dash=(5, 6), color=LINE2)
    mini_jar(im, 214, 82, 62, level=0.0, falling_star=True)
    star_dust(im, 214*IS, 48*IS, 24*IS, 7, AMBER_L, seed=9)
    return down(im, (320, 240))


def illus_graph():
    """关系图空态：三节点 + 虚线 + 节点标签 + 中央半满落瓶 + 星尘光斑。"""
    im = Image.new('RGBA', (IW, IH), (0, 0, 0, 0))
    im.alpha_composite(radial_glow(IW, IH, 160*IS, 118*IS, 116*IS, CONT, 0.42))
    im.alpha_composite(radial_glow(IW, IH, 160*IS, 108*IS, 78*IS, GLOW_WARM, 0.28))
    d = ImageDraw.Draw(im)
    # 三条虚线连接（一条刻意断开 = 还没有关联）
    line(d, [(92, 78), (224, 78)], 2.2, dash=(9, 9), color=LINE2)
    line(d, [(92, 78), (160, 176)], 2.2, dash=(9, 9), color=LINE2)
    line(d, [(224, 78), (160, 176)], 2.2, dash=(9, 9), color=LINE2)
    # 三个节点环 + 各自的小标签条
    for (x, y, c) in [(92, 78, BRAND), (224, 78, BRAND), (160, 176, DONE)]:
        r = 17
        d.ellipse([(x-r)*IS, (y-r)*IS, (x+r)*IS, (y+r)*IS],
                  outline=MIST+(255,), width=int(2.6*IS))
        d.ellipse([(x-7)*IS, (y-7)*IS, (x+7)*IS, (y+7)*IS], fill=c+(255,))
    rrect(d, (66, 96, 118, 108), 4, 1.6, color=LINE2, fill=(252, 251, 248))
    line(d, [(74, 102), (110, 102)], 1.6, color=LINE2)
    rrect(d, (200, 96, 252, 108), 4, 1.6, color=LINE2, fill=(252, 251, 248))
    line(d, [(208, 102), (244, 102)], 1.6, color=LINE2)
    rrect(d, (132, 196, 188, 208), 4, 1.6, color=LINE2, fill=(252, 251, 248))
    line(d, [(140, 202), (180, 202)], 1.6, color=LINE2)
    # 中央小落瓶（半满），略上移不压交点
    mini_jar(im, 160, 128, 68, level=0.5)
    star_dust(im, 160*IS, 60*IS, 30*IS, 8, AMBER_L, seed=13)
    return down(im, (320, 240))


def illus_trash():
    """回收站空态：桶 + 标签 + 三颗飘出闪星 + 星轨 + 星尘光斑。"""
    im = Image.new('RGBA', (IW, IH), (0, 0, 0, 0))
    im.alpha_composite(radial_glow(IW, IH, 160*IS, 128*IS, 112*IS, CONT, 0.42))
    im.alpha_composite(radial_glow(IW, IH, 160*IS, 62*IS, 84*IS, GLOW_WARM, 0.34))
    d = ImageDraw.Draw(im)
    # 桶盖 + 提手
    line(d, [(86, 92), (234, 92)], 2.6)
    line(d, [(140, 92), (146, 76), (174, 76), (180, 92)], 2.4)
    # 桶身（上宽下窄）+ 中央小标签
    line(d, [(98, 100), (222, 100), (208, 192), (112, 192), (98, 100)], 2.6)
    line(d, [(134, 118), (139, 174)], 2.2, color=LINE2)
    line(d, [(186, 118), (181, 174)], 2.2, color=LINE2)
    rrect(d, (146, 132, 174, 152), 4, 1.8, color=LINE2, fill=(252, 251, 248))
    line(d, [(152, 142), (168, 142)], 1.8, color=LINE2)
    # 飘出的小闪星（回收 = 灵感并未消失，还能再落进瓶里）
    # 一条平滑细星轨弧（二次贝塞尔，避免尖锐折角）
    _p0 = np.array([112.0, 56.0]); _p1 = np.array([140.0, 30.0]); _p2 = np.array([176.0, 44.0])
    _arc = bezier(_p0, _p1, _p1, _p2, n=48)
    d.line([(x*IS, y*IS) for x, y in _arc],
           fill=AMBER_L + (150,), width=2*IS, joint='curve')
    mini_star(d, 122, 52, 9)
    mini_star(d, 196, 38, 12)
    mini_star(d, 160, 30, 7, color=AMBER_L)
    mini_star(d, 150, 62, 4, color=AMBER_L)
    mini_star(d, 208, 58, 5, color=AMBER)
    star_dust(im, 160*IS, 46*IS, 46*IS, 14, AMBER_L, seed=17)
    return down(im, (320, 240))


# ---------------- 纸纹（暖灰纤维细噪，更贴纸感 v2.4.1）----------------
def paper_texture(dark):
    """8×8 纸纤维细噪 + 横向纤维：alpha 恒 255，靠 PaperTexture 的 Opacity 稀释。
    浅色用冷灰压暖白纸底，深色用浅灰提亮深底；v2.4.1 加入横向纤维
    让纸感更饱满（不是纯随机噪点）。"""
    rng = np.random.default_rng(20231110 if not dark else 20231111)
    n = rng.normal(0, 1, (8, 8))
    fib = np.repeat(rng.normal(0, 0.45, (8, 1)), 8, axis=1)   # 横向纤维
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
