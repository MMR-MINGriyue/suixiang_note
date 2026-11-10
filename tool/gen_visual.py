# -*- coding: utf-8 -*-
"""
随想随记 · 全新美术素材生成（视觉重塑 v2.3）
设计概念：「水位 · 灵感滴」(The Tide Drop)
  - 弃用旧的「缺口蓝环 + 绿滴」（循环/完成语义混杂）
  - 品牌符号 = 一枚品牌蓝渐变水滴 + 一道半满水位线，
    与应用内三态徽章（空心 / 半满 / 实心）完全同构
  - 启动图标固定取「推进中(半满)」态：随想随记，永远在记录中
  - 全套素材（启动图标 / 空态插画 / 纸纹 / ico）统一到
    奶白纸底 + 雾靛线稿 + 品牌蓝渐变 + 极淡径向光晕

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
WHITE   = (255, 255, 255)

SS = 4  # 超采样倍数（抗锯齿）


def lerp(a, b, t):
    return a + (b - a) * t


def bezier(p0, p1, p2, p3, n=140):
    t = np.linspace(0, 1, n)[:, None]
    return ((1-t)**3 * p0 + 3*(1-t)**2*t * p1
            + 3*(1-t)*t**2 * p2 + t**3 * p3)


def drop_outline(cx, cy, H):
    """水滴轮廓点集（单位坐标 × H + 中心）。
    顶(0,-0.44) / 底(0,+0.43) / 半宽 0.33 / 底圆心(0,+0.10) 半径 0.33"""
    top = np.array([0.0, -0.44])
    lft = np.array([-0.33, 0.10])
    rgt = np.array([0.33, 0.10])
    L = bezier(top, np.array([-0.015, -0.20]),
               np.array([-0.33, -0.02]), lft)
    R = bezier(top, np.array([0.015, -0.20]),
               np.array([0.33, -0.02]), rgt)
    a = np.linspace(math.pi, 2*math.pi, 160)
    # 下半圆：a=pi -> (-0.33, 0.10)，a=1.5pi -> (0, 0.43) 底尖，
    # a=2pi -> (0.33, 0.10)。sin 在 [pi,2pi] 为负，故用减号让圆弧向下凸。
    arc = np.stack([0.33*np.cos(a), 0.10 - 0.33*np.sin(a)], axis=1)
    pts = np.concatenate([L, arc[1:], R[::-1][1:]], axis=0)
    return pts * H + np.array([cx, cy])


def radial_glow(w, h, cx, cy, radius, color, peak):
    """径向淡光晕 RGBA（边缘完全透明，不会在启动器上露出方块）"""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    r2 = ((xx-cx)**2 + (yy-cy)**2) / (radius**2)
    al = (peak * np.exp(-2.4*r2)).clip(0, 1)
    arr = np.zeros((h, w, 4), np.float32)
    arr[..., 0] = color[0]; arr[..., 1] = color[1]; arr[..., 2] = color[2]
    arr[..., 3] = al * 255
    return Image.fromarray(arr.astype(np.uint8), 'RGBA')


def make_drop(w, h, cx, cy, H, theme='brand', monochrome=False):
    """绘制一枚『半满水位』水滴，返回 RGBA 图层（w×h，超采样画布尺寸）"""
    outline = drop_outline(cx, cy, H)
    mask_im = Image.new('L', (w, h), 0)
    ImageDraw.Draw(mask_im).polygon([tuple(p) for p in outline], fill=255)
    mask = np.asarray(mask_im).astype(np.float32) / 255.0

    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    top_y = cy - 0.44*H
    bot_y = cy + 0.43*H
    water_y = cy + 0.02*H          # 水位线
    v = ((yy - top_y) / (bot_y - top_y)).clip(0, 1)

    if monochrome:
        # 主题图标：纯黑剪影 + 内部透明水位弧（alpha mask，系统自行上色）
        rgb = np.zeros((h, w, 3), np.float32)
        alpha = mask.copy()
        # 水位线：一条透明细弧，把「半满」语义也带进单色版
        wl = Image.new('L', (w, h), 0)
        d = ImageDraw.Draw(wl)
        pts = []
        for t in np.linspace(0, 1, 80):
            x = cx + lerp(-0.245*H, 0.245*H, t)
            y = water_y + 0.045*H*math.sin(math.pi*t)
            pts.append((x, y))
        d.line(pts, fill=255, width=max(2, int(0.018*H)), joint='curve')
        wl_np = np.asarray(wl).astype(np.float32)/255.0
        alpha = (alpha * (1 - 0.85*wl_np)).clip(0, 1)
        arr = np.zeros((h, w, 4), np.float32)
        arr[..., 3] = alpha*255
        return Image.fromarray(arr.astype(np.uint8), 'RGBA')

    if theme == 'brand':
        c_top, c_mid, c_bot = BRAND_L, BRAND, BRAND_D
    else:  # 插画里的点缀小水滴也用品牌蓝
        c_top, c_mid, c_bot = BRAND_L, BRAND, BRAND_D

    # 垂直三段渐变
    stops = [(0.0, c_top), (0.5, c_mid), (1.0, c_bot)]
    rgb = np.zeros((h, w, 3), np.float32)
    for i in range(3):
        rgb[..., i] = np.select(
            [v < 0.5, v >= 0.5],
            [lerp(stops[0][1][i], stops[1][1][i], (v/0.5).clip(0, 1)),
             lerp(stops[1][1][i], stops[2][1][i], ((v-0.5)/0.5).clip(0, 1))],
            default=stops[2][1][i])

    # 上半提亮（未记录的部分）→ 水位线处 0，顶部 0.60
    upper = ((water_y - yy) / (water_y - top_y)).clip(0, 1)
    whiten = 0.60 * upper * (yy < water_y)
    for i in range(3):
        rgb[..., i] = rgb[..., i]*(1-whiten) + WHITE[i]*whiten

    # 水位线下方一道更饱和的水面反光带
    band = np.exp(-((yy - (water_y + 0.035*H))**2) / (2*(0.035*H)**2))
    band *= (yy >= water_y)
    for i in range(3):
        rgb[..., i] = rgb[..., i]*(1-0.16*band) + c_mid[i]*0.16*band

    # 左上柔和长条高光
    hx, hy = cx - 0.125*H, cy - 0.055*H
    hl = Image.new('L', (w, h), 0)
    hd = ImageDraw.Draw(hl)
    hd.ellipse([hx-0.052*H, hy-0.115*H, hx+0.052*H, hy+0.115*H], fill=170)
    hl = hl.rotate(-18, center=(hx, hy))
    hl = hl.filter(ImageFilter.GaussianBlur(0.028*H))
    hl_np = np.asarray(hl).astype(np.float32)/255.0 * 0.42
    for i in range(3):
        rgb[..., i] = rgb[..., i]*(1-hl_np) + 255*hl_np

    # 水位张力：白色细弧
    wl = Image.new('L', (w, h), 0)
    d = ImageDraw.Draw(wl)
    pts = []
    for t in np.linspace(0, 1, 90):
        x = cx + lerp(-0.245*H, 0.245*H, t)
        y = water_y + 0.045*H*math.sin(math.pi*t)
        pts.append((x, y))
    d.line(pts, fill=255, width=max(2, int(0.016*H)), joint='curve')
    wl = wl.filter(ImageFilter.GaussianBlur(0.006*H))
    wl_np = np.asarray(wl).astype(np.float32)/255.0 * 0.82
    for i in range(3):
        rgb[..., i] = rgb[..., i]*(1-wl_np) + 255*wl_np

    # 外缘细描边，保证白色启动器上边界清晰
    edge = (np.asarray(mask_im.filter(ImageFilter.MaxFilter(5))).astype(np.float32)
            - np.asarray(mask_im.filter(ImageFilter.MinFilter(5))).astype(np.float32))/255.0
    edge = (edge*0.30).clip(0, 1)
    for i in range(3):
        rgb[..., i] = rgb[..., i]*(1-edge) + BRAND_D[i]*edge

    arr = np.zeros((h, w, 4), np.float32)
    arr[..., :3] = rgb
    arr[..., 3] = mask*255
    return Image.fromarray(arr.astype(np.uint8), 'RGBA')


def down(im, size):
    return im.resize(size, Image.LANCZOS)


def compose_foreground(S, mono=False):
    """自适应图标前景：透明底 + 淡光晕 + 半满水滴"""
    W = Hc = S*SS
    base = radial_glow(W, Hc, W/2, Hc/2, W*0.46, CONT, 0.30)
    dh = S*SS*0.66                      # 水滴高度占画布 66%
    drop = make_drop(W, Hc, W/2, Hc/2, dh, monochrome=mono)
    if mono:
        return down(drop, (S, S))       # 单色版不放光晕（纯 alpha mask）
    base.alpha_composite(drop)
    return down(base, (S, S))


def compose_static(S, round_icon=False):
    """静态启动图标：奶白圆角/圆形底 + 光晕 + 半满水滴"""
    W = Hc = S*SS
    if round_icon:
        bg = Image.new('RGBA', (W, Hc), (0, 0, 0, 0))
        ImageDraw.Draw(bg).ellipse([0, 0, W-1, Hc-1], fill=PAPER+(255,))
    else:
        bg = Image.new('RGBA', (W, Hc), (0, 0, 0, 0))
        ImageDraw.Draw(bg).rounded_rectangle(
            [0, 0, W-1, Hc-1], radius=int(W*0.225), fill=PAPER+(255,))
    bg.alpha_composite(radial_glow(W, Hc, W/2, Hc/2, W*0.44, CONT, 0.55))
    dh = S*SS*0.66
    bg.alpha_composite(make_drop(W, Hc, W/2, Hc/2, dh))
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


def mini_drop(base, cx, cy, H):
    d = make_drop(IW, IH, cx*IS, cy*IS, H*IS)
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
    # 落下的灵感滴 + 下落虚线
    line(d, [(252, 32), (252, 52)], 2.2, dash=(6, 7), color=LINE2)
    mini_drop(im, 252, 42, 44)
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
    # 上方小水滴
    mini_drop(im, 160, 40, 40)
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
    # 中央灵感滴
    mini_drop(im, 160, 116, 36)
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
    # 飘出的小水滴（回收 = 灵感并未消失）
    mini_drop(im, 122, 46, 32)
    mini_drop(im, 196, 34, 24)
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
