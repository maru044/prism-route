import glob, os, re

for anim_name in ['A01', 'A05', 'A06', 'A18', 'A19', 'A20', 'A25']:
    path = f'D:/Prism Route/prism-route/assets/characters/motion_review/{anim_name}.tres'
    with open(path, 'r', encoding='utf-8') as f:
        text = f.read()
    tracks = re.findall(r'tracks/(\d+)/path = NodePath\("[^"]+:Hips"\)', text)
    for t_idx in tracks:
        type_m = re.search(r'tracks/' + t_idx + r'/type = "([^"]+)"', text)
        if type_m and type_m.group(1) == 'position_3d':
            keys_m = re.search(r'tracks/' + t_idx + r'/keys = PackedFloat32Array\(([\s\S]+?)\)', text)
            if keys_m:
                raw = [float(x.strip()) for x in keys_m.group(1).split(',') if x.strip()]
                step = 5
                xs = [raw[i+2] for i in range(0, len(raw), step)]
                ys = [raw[i+3] for i in range(0, len(raw), step)]
                zs = [raw[i+4] for i in range(0, len(raw), step)]
                print(f'{anim_name}: count={len(xs)} X=[{min(xs):.3f}, {max(xs):.3f}] Y=[{min(ys):.3f}, {max(ys):.3f}] Z=[{min(zs):.3f}, {max(zs):.3f}]')
