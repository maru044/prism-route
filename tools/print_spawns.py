import os, json

path = r'd:\Prism Route\prism-route\assets\npc\spawns'
spawns = []
for f in sorted(os.listdir(path)):
    if f.endswith('.json'):
        d = json.load(open(os.path.join(path, f), encoding='utf-8'))
        spawns.append((d['character_id'], d['spawn_id'], d['position']))

print(f"Total spawns: {len(spawns)}")
for char_id, spawn_id, pos in spawns:
    print(f"{char_id:15} {spawn_id:22} {pos}")
