"""Encode the matched Godot capture frames as looping before/after review GIFs."""
import json
import sys
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
loop_seam = '--loop-seam' in sys.argv[1:]
catalog = json.loads((root/'assets/characters/motion_review/catalog.json').read_text(encoding='utf8'))
for action_id, speed in [('A05',1.0),('A39',0.65)]:
    cache = 'walk_loop_compare' if loop_seam else 'walk_compare'
    frames = [Image.open(p).convert('RGB') for p in sorted((root/'.godot'/cache/action_id).glob('frame_*.png'))]
    assert len(frames) == 32, 'Run capture_walk_comparison.gd first'
    duration = next(a['duration'] for a in catalog if a['id'] == action_id)
    suffix = 'loop_comparison' if loop_seam else 'comparison'
    path = root/f'screenshots/walk_{action_id.lower()}_{suffix}.gif'
    frames[0].save(path,save_all=True,append_images=frames[1:],duration=round(duration/speed/32*1000),loop=0,disposal=2)
    print(path)
