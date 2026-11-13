"""Plot live Rhino measurements; does not modify the Rhino document."""
import json
from pathlib import Path
import cv2
import numpy as np
from scipy import ndimage
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
r = json.loads((HERE / 'terrace_geometry_raw.json').read_text())
points = np.array([p[:4] for p in r['samples']])
outline = np.array(r['outline'])
step = r['sample_step']
origin = points[:, :2].min(axis=0)
indices = np.round((points[:, :2] - origin) / step).astype(int)
shape = indices.max(axis=0) + 1
z = np.full(shape, np.nan)
z[indices[:, 0], indices[:, 1]] = points[:, 2]
gx, gy = np.gradient(z, step)
slope = np.degrees(np.arctan(np.hypot(gx, gy)))
high = np.isfinite(z) & (z >= 55)
gentle = high & (slope <= 10)
labels, count = ndimage.label(gentle)
counts = np.bincount(labels.ravel()); counts[0] = 0
core = labels == counts.argmax()
high_xy = origin + np.argwhere(high) * step
core_xy = origin + np.argwhere(core) * step
bounds = np.array(r['top_mesh_bounds'])
report = {
    'source_document': r['doc_path'], 'units': r['units'],
    'base_id': r['base_id'], 'hill_id': r['hill_id'],
    'footprint_net_area_m2': r['footprint_net_area_exact_xy'],
    'site_xy_axis_extents_m': (bounds[1, :2] - bounds[0, :2]).tolist(),
    'base_top_z_range_m': bounds[:, 2].tolist(),
    'terrain_peak_z_m': r['hill_mesh_bounds'][1][2],
    'three_tips': r['approx_three_tips'],
    'three_boundary_arcs': r['three_boundary_arcs'],
    'boundary_perimeter_xy_m': r['boundary_perimeter_exact_xy'],
    'upper_ridge': {
        'definition': 'Combined exposed terrain Z >= 55 m; NOT a flat building pad.',
        'sample_spacing_m': step, 'approx_area_m2': int(high.sum() * step**2),
        'xy_axis_extents_m': np.ptp(high_xy, axis=0).tolist(),
        'xy_bounds_m': [high_xy.min(axis=0).tolist(), high_xy.max(axis=0).tolist()],
        'highest_sample_xyz': points[np.argmax(points[:, 2]), :3].tolist(),
        'largest_gentle_component': {
            'definition': 'Z >= 55 m AND sampled slope <= 10 degrees; connected cells.',
            'approx_area_m2': int(core.sum() * step**2),
            'xy_axis_extents_m': np.ptp(core_xy, axis=0).tolist(),
        },
    },
    'method': 'Live Rhino NURBS boundary projection and area; trimmed-face meshes at 0.02 m tolerance; vertical rays on a 3 m XY grid; topmost base/hill surface; finite-difference slopes.',
    'notes': ['Bounding extents do not describe a rectangular usable site.',
              'Three boundary lengths are curved arc lengths, not straight wall lengths.',
              'No terrain was flattened, added, deleted or saved by this measurement.'],
}
(HERE / 'terrace_measurements.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')

W, H = 1800, 1360
image = Image.new('RGB', (W, H), '#f5f3eb')
draw = ImageDraw.Draw(image)
font_path = 'C:/Windows/Fonts/msyh.ttc'
bold_path = 'C:/Windows/Fonts/msyhbd.ttc'
def font(size=24, bold=False): return ImageFont.truetype(bold_path if bold else font_path, size)
def text(xy, value, size=24, fill='#233f4a', bold=False): draw.text(xy, value, font=font(size, bold), fill=fill)
def transform(rect, world):
    x0, y0, x1, y1 = rect; xmin, ymin, xmax, ymax = world
    scale = min((x1-x0)/(xmax-xmin), (y1-y0)/(ymax-ymin))
    ox = (x0+x1-(xmax-xmin)*scale)/2
    oy = (y0+y1-(ymax-ymin)*scale)/2
    return lambda x,y:(ox+(x-xmin)*scale, oy+(ymax-y)*scale), scale
def color(height):
    q = np.clip((height-35)/26, 0, 1)
    return tuple(int(v) for v in np.array([116,160,156]) + q*np.array([121,51,-59]))
def plot(rect, world, fine=False):
    global draw
    previous_draw = draw
    layer = image.copy()
    draw = ImageDraw.Draw(layer)
    conv, scale = transform(rect, world)
    draw.rectangle(rect, fill='#e4efee', outline='#c6d1ce', width=2)
    increment = 10 if fine else 100
    for x in range(int(world[0]//increment)*increment, int(world[2])+1, increment):
        a=conv(x, world[1]); b=conv(x, world[3]); draw.line([a,b], fill='#d3dedd', width=1)
    for y in range(int(world[1]//increment)*increment, int(world[3])+1, increment):
        a=conv(world[0], y); b=conv(world[2], y); draw.line([a,b], fill='#d3dedd', width=1)
    if not fine: draw.polygon([conv(x,y) for x,y in outline[:,:2]], fill=color(35))
    for x,y,height,_ in points:
        if not (world[0]<=x<=world[2] and world[1]<=y<=world[3]): continue
        px,py=conv(x,y); radius=step*scale*.51
        draw.rectangle((px-radius,py-radius,px+radius,py+radius),fill=color(height))
    for level in [40,45,50,55,58,60]:
        mask=(np.isfinite(z)&(z>=level)).T.astype(np.uint8)*255
        contours,_=cv2.findContours(mask,cv2.RETR_EXTERNAL,cv2.CHAIN_APPROX_SIMPLE)
        for contour in contours:
            pts=contour[:,0,:]
            if len(pts)<3: continue
            line=[conv(*(origin+np.array([px,py])*step)) for px,py in pts]
            line.append(line[0])
            draw.line(line, fill='#6c774f' if level<55 else '#98732b',width=2 if fine else 1)
    if fine:
        for x,y in core_xy:
            px,py=conv(x,y); radius=step*scale*.48
            draw.rectangle((px-radius,py-radius,px+radius,py+radius), fill='#27716a')
    else:
        draw.line([conv(x,y) for x,y in outline[:,:2]],fill='#244b5b',width=4)
        for path in r.get('walkway_outlines',[]):
            line=[conv(p[0],p[1]) for p in path]
            draw.line(line,fill='#645d78',width=3)
    image.paste(layer.crop(rect), (rect[0],rect[1]))
    draw = previous_draw
    return conv, scale

text((60,35),'初始台地 · Rhino 实测',42,bold=True)
text((62,92),'2026-10-28  |  单位：米  |  平面朝向：上北下南',23,fill='#62716d')
draw.line((60,135,1740,135),fill='#c3ccc6',width=2)
text((70,157),'01  整体上表面轮廓',28,bold=True)
conv, scale = plot((65,210,1020,1200),(245,-535,800,250))
tips=np.array(r['approx_three_tips'])
for i,(x,y,_) in enumerate(tips):
    px,py=conv(x,y);draw.ellipse((px-7,py-7,px+7,py+7),fill='#b75c3e')
    text((px+12,py-16),chr(65+i),25,bold=True)
cx,cy=conv(460,-130)
draw.rectangle((cx-75,cy-90,cx+80,cy+100),outline='#b75c3e',width=3)
text((cx+95,cy-10),'山脊顶部',23,fill='#a44f37',bold=True)
text((105,1080),'整体范围约 444 × 701 m',25,bold=True)
text((105,1118),'弧边三角形／三尖形，边界有明显内凹',22)
text((105,1153),'A、B、C 为三个端点；紫线为洞口步道边界',20,fill='#62716d')
sx,sy=820,1050;draw.line((sx,sy,sx+100*scale,sy),fill='#233f4a',width=5)
draw.line((sx,sy-6,sx,sy+6),fill='#233f4a',width=3)
draw.line((sx+100*scale,sy-6,sx+100*scale,sy+6),fill='#233f4a',width=3)
text((sx+10,sy-35),'100 m',20)
text((925,228),'N ↑',26,bold=True)

text((1080,157),'02  山脊顶部放大',28,bold=True)
text((1080,202),'标高 ≥55 m：约 2,310 m²，范围约 39 × 93 m',22)
detail, ds = plot((1080,245,1730,765),(405,-195,490,-65),True)
px,py=detail(*points[np.argmax(points[:,2]),:2])
draw.ellipse((px-6,py-6,px+6,py+6),fill='#a13a30')
draw.line((px,py,px+72,py-45),fill='#a13a30',width=2)
text((px+76,py-65),'最高约 60.19 m',21,fill='#943a2c',bold=True)
text((1080,780),'深绿色：顶部坡度 ≤10° 的最大连续区',20)
text((1080,811),'约 450 m²；仍不是水平地面',20,bold=True)

text((1080,855),'03  尺度核对',28,bold=True)
rows=[('顶面水平投影面积','约 79,690 m²'),('叠加地表标高','约 35.00 ～ 60.19 m'),('山脊相对主要台面抬高','约 25.19 m')]
yy=905
for label,value in rows:
    text((1080,yy),label,22);text((1440,yy),value,22,bold=True);yy+=40
text((1080,1045),'三边不是直线；沿边长度 / 端点直距',22,bold=True)
for j,side in enumerate(r['three_boundary_arcs']):
    text((1090,1085+j*36),f"{side['vertices']}    {side['boundary_length_xy']:.0f} m  /  {side['chord_xy']:.0f} m",23)
text((1080,1205),'35 m',19);text((1670,1205),'60 m',19)
for i in range(500): draw.line((1160+i,1209,1160+i,1225),fill=color(35+i/499*25),width=1)
draw.line((60,1240,1740,1240),fill='#c3ccc6',width=2)
text((65,1260),'轮廓和投影面积取自 Rhino 实体；等高线、顶部范围及坡度采用 3 m 网格抽样。55 m 是本次顶部分析的阈值。',21,fill='#62716d')
text((65,1298),'“范围”是坐标包围尺寸，不等于可直接放入同尺寸矩形建筑。测量没有改动现有地形。',21,fill='#62716d')
image.save(HERE/'terrace_measured_plan.png')
print(json.dumps(report,ensure_ascii=False,indent=2))
