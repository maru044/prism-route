"""Encode the matched Godot capture frames as looping before/after review GIFs."""
import json
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
catalog = json.loads((root/'assets/characters/motion_review/catalog.json').read_text(encoding='utf8'))
for action_id, speed in [('A05',1.0),('A39',0.65)]:
    frames = [Image.open(p).convert('RGB') for p in sorted((root/'.godot/walk_compare'/action_id).glob('frame_*.png'))]
    assert len(frames) == 32, 'Run capture_walk_comparison.gd first'
    duration = next(a['duration'] for a in catalog if a['id'] == action_id)
    path = root/f'screenshots/walk_{action_id.lower()}_comparison.gif'
    frames[0].save(path,save_all=True,append_images=frames[1:],duration=round(duration/speed/32*1000),loop=0,disposal=2)
    print(path)
