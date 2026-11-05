# -*- coding: utf-8 -*-
"""P3 资产预渲染：纸纹平铺图 + 三幅空态线稿插画（160×120，雾靛描边）。
用法：python tool/gen_assets.py  （仓库根目录执行，输出到 assets/）"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets')
random.seed(42)  # 可复现

# 调色（对齐 tokens.dart）
MIST = '#A8B9E6'      # 雾靛描边
BRAND = '#4C6FFF'     # 靛蓝
DONE = '#2FBF8F'      # 珠绿
PAPER = '#FAF7F2'     # 纸底
DARK_BG = '#1C1E26'   # 深色底


def rgba(hex_color, a=255):
    h = hex_color.lstrip('#')
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def save(img, *parts):
    d = os.path.join(OUT, *parts[:-1])
    os.makedirs(d, exist_ok=True)
    p = os.path.join(d, parts[-1])
    img.save(p)
    print(f'  {os.path.relpath(p, ROOT)}  {img.size}  {os.path.getsize(p)}B')


# ── 1. 纸纹 8×8 平铺噪点（透明底，仅噪点像素，由应用侧控透明度） ──
def paper_texture():
    for name, base_alpha in [('paper_texture_light.png', 200),
                             ('paper_texture_dark.png', 200)]:
        img = Image.new('RGBA', (8, 8), (0, 0, 0, 0))
        px = img.load()
        for y in range(8):
            for x in range(8):
                v = random.randint(0, 255)
                a = int(base_alpha * (0.35 + 0.65 * random.random()))
                px[x, y] = (v, v, v, a)
        save(img, 'texture', name)


# ── 2. 水滴路径（与 Flutter _dropPath 同一几何） ──
def drop_points(cx, cy, r, steps=64):
    """中心 (cx,cy)，半径 r 的水滴轮廓点列。"""
    pts = []
    # 圆主体：角度 60° 起绕到 300°（顶部留给尖）
    for i in range(steps + 1):
        t = math.radians(60 + (300 - 60) * i / steps)  # 60→300 顺时针
        pts.append((cx + r * math.cos(t), cy + r * math.sin(t)))
    # 尖顶
    pts.append((cx, cy - r * 1.55))
    return pts


def draw_drop(d, cx, cy, r, color, width=3, fill=None, half=False):
    pts = drop_points(cx, cy, r)
    if fill:
        d.polygon(pts, fill=fill)
    if half:
        # 左半实心：裁剪多边形（中线左侧）
        half_pts = [(cx, cy - r * 1.55)]
        for i in range(steps_half := 32, -1, -1):
            t = math.radians(60 + 240 * i / 32)
            half_pts.append((cx + r * math.cos(t), cy + r * math.sin(t)))
        # 仅画左半：取圆心左侧
        left = [(cx, cy - r)]
        for i in range(33):
            t = math.radians(90 + 180 * i / 32)  # 90→270 左半圆
            left.append((cx + r * math.cos(t), cy + r * math.sin(t)))
        d.polygon(left, fill=color)
    d.line(pts + [pts[0]], fill=color, width=width, joint='curve')


def rounded(d, box, radius, outline, width=3, fill=None):
    d.rounded_rectangle(box, radius=radius, outline=outline, width=width, fill=fill)


# ── 3. 插画一：首页空态「纸 + 水滴」160×120 ──
def illus_home(dark=False):
    img = Image.new('RGBA', (320, 240), (0, 0, 0, 0))  # 2x 超采样
    d = ImageDraw.Draw(img)
    ink = rgba(MIST)
    # 三张便签错落
    rounded(d, (70, 96, 178, 176), 12, ink, width=4)
    rounded(d, (96, 72, 204, 152), 12, ink, width=4)
    rounded(d, (122, 48, 230, 128), 12, ink, width=4, fill=rgba(MIST, 26))
    # 便签内两行横线
    d.line((140, 74, 208, 74), fill=ink, width=3)
    d.line((140, 92, 190, 92), fill=ink, width=3)
    # 悬落水滴（珠绿）
    draw_drop(d, 176, 196, 22, rgba(DONE), width=4)
    # 高光
    d.ellipse((166, 192, 174, 202), fill=rgba('#FFFFFF', 180))
    img = img.resize((160, 120), Image.LANCZOS)
    save(img, 'illus', 'empty_home.png')


# ── 4. 插画二：文件夹空态「打开的空文件夹 + 水滴」 ──
def illus_folder():
    img = Image.new('RGBA', (320, 240), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    ink = rgba(MIST)
    # 文件夹后片（凸起的标签耳）
    d.polygon([(84, 120), (84, 84), (128, 84), (144, 100), (236, 100), (236, 120)],
              outline=ink, width=4)
    # 文件夹前片（倾斜打开的盖）
    d.polygon([(70, 128), (250, 128), (232, 196), (88, 196)],
              outline=ink, width=4, fill=rgba(MIST, 20))
    d.line((70, 128, 250, 128), fill=ink, width=4)
    # 内部一滴靛蓝水珠（待入住）
    draw_drop(d, 160, 158, 16, rgba(BRAND), width=4)
    img = img.resize((160, 120), Image.LANCZOS)
    save(img, 'illus', 'empty_folder.png')


# ── 5. 插画三：回收站空态「微倾纸篓 + 蒸发水珠」 ──
def illus_trash():
    img = Image.new('RGBA', (320, 240), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    ink = rgba(MIST)
    # 微倾纸篓（梯形，向左倾 6°）：盖 + 身
    body = [(104, 108), (216, 108), (200, 208), (120, 208)]
    d.polygon(body, outline=ink, width=4, fill=rgba(MIST, 18))
    # 篓盖（斜线 + 提手）
    d.line((96, 108, 224, 100), fill=ink, width=4)
    d.arc((146, 76, 178, 100), start=180, end=360, fill=ink, width=4)
    # 篓身竖条纹（3 条）
    for x in (140, 160, 180):
        d.line((x, 126, x - 6, 194), fill=ink, width=3)
    # 蒸发水珠（两小滴上行渐隐）
    draw_drop(d, 150, 62, 10, rgba(DONE, 220), width=3)
    draw_drop(d, 186, 40, 7, rgba(DONE, 130), width=3)
    img = img.resize((160, 120), Image.LANCZOS)
    save(img, 'illus', 'empty_trash.png')


# ── 6. 插画四：关系图谱空态「散点待连线」160×120 ──
def illus_graph():
    """三个空心节点 + 两条虚线，第三条故意留缺口，表达「网还没长成」。"""
    img = Image.new('RGBA', (320, 240), (0, 0, 0, 0))  # 2x 超采样
    d = ImageDraw.Draw(img)
    ink = rgba(MIST)
    nodes = [(92, 88), (222, 104), (156, 186)]

    def dashed(p, q, width=3, dash=14, gap=11):
        dx, dy = q[0] - p[0], q[1] - p[1]
        dist = math.hypot(dx, dy)
        ux, uy = dx / dist, dy / dist
        t = 0.0
        while t < dist:
            e = min(t + dash, dist)
            d.line((p[0] + ux * t, p[1] + uy * t,
                    p[0] + ux * e, p[1] + uy * e),
                   fill=rgba(MIST, 170), width=width)
            t += dash + gap

    # 前两点连实虚线，第三点只连一半：一眼看出「还差一条」
    dashed(nodes[0], nodes[1])
    dashed(nodes[1], (nodes[1][0] + (nodes[2][0] - nodes[1][0]) * 0.45,
                      nodes[1][1] + (nodes[2][1] - nodes[1][1]) * 0.45))
    # 节点：纸底空心圆 + 中心珠绿小点（有内容，但还没连起来）
    for (x, y) in nodes:
        d.ellipse((x - 17, y - 17, x + 17, y + 17),
                  outline=ink, width=4, fill=rgba(PAPER, 210))
        d.ellipse((x - 5, y - 5, x + 5, y + 5), fill=rgba(DONE))
    # 中心悬一滴靛蓝小珠：呼应「关联会长出来」
    draw_drop(d, 160, 128, 9, rgba(BRAND), width=3)
    img = img.resize((160, 120), Image.LANCZOS)
    save(img, 'illus', 'empty_graph.png')


if __name__ == '__main__':
    print('paper texture:')
    paper_texture()
    print('illustrations:')
    illus_home()
    illus_folder()
    illus_trash()
    illus_graph()
    print('done.')
