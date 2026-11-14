"""Bake the three CharaStudio locomotion samples into shared Godot tracks."""
import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np

CLIPS = {
    "idle": ("f_stand_00_00", 8620497821727385432),
    "walk": ("f_aruki_00_00_01", -938002415524212421),
    "run": ("f_hasiru_00_00_01", -4812904891494681965),
}
BUNDLE = "studio/anime/00.unity3d"
FPS = 30


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--abdata", type=Path, help="Koikatsu RX22 abdata directory")
    parser.add_argument("--unitypy-path", type=Path, help="Optional local UnityPy installation")
    args = parser.parse_args()
    if args.unitypy_path:
        sys.path.insert(0, str(args.unitypy_path))

    from import_koikatsu_selected_20 import (
        KK_ABDATA, ROOT, UnityPy, eval_clip_worlds, load_prefab, write_kk_clip,
    )

    abdata = args.abdata or KK_ABDATA
    skeleton = UnityPy.load(str(abdata / "chara/oo_base.unity3d"))
    objects = {obj.path_id: obj for obj in skeleton.objects}
    nodes, hashes, names, rest = load_prefab(skeleton, objects, "p_cf_body_bone")
    bundle_path = abdata / BUNDLE
    bundle = UnityPy.load(str(bundle_path))
    objects = {obj.path_id: obj for obj in bundle.objects if obj.type.name == "AnimationClip"}
    bundle_hash = hashlib.sha256(bundle_path.read_bytes()).hexdigest()
    destination = ROOT / "assets/characters/roster/motions"

    for kind, (clip_name, path_id) in CLIPS.items():
        clip = objects[path_id].read_typetree()
        settings = clip["m_MuscleClip"]
        assert clip["m_Name"] == clip_name and settings["m_LoopTime"]
        start, end = settings["m_StartTime"], settings["m_StopTime"]
        duration = end - start
        frame_count = round(duration * FPS) + 1
        times = np.linspace(0.0, duration, frame_count)
        poses = eval_clip_worlds(nodes, hashes, clip, times + start)

        # These originals are in-place. Center the horizontal pelvis offset
        # for comparison while keeping its sway and vertical travel.
        pelvis = names["cf_j_waist02"]
        positions = np.array([pose[pelvis][:3, 3] for pose in poses])
        assert np.linalg.norm((positions[-1] - positions[0])[[0, 2]]) < .01
        center = positions[:-1].mean(axis=0) - rest[pelvis][:3, 3]
        center[1] = 0.0
        for pose in poses:
            pose[pelvis][:3, 3] -= center

        name = f"koikatsu_{kind}"
        source = f"Koikatsu RX22 {BUNDLE} {clip_name} PathID {path_id} SHA256 {bundle_hash}"
        size, height = write_kk_clip(
            name, times, rest, poses, names, source, destination / f"{name}.tres", hermite_loop=True,
        )
        print(json.dumps(dict(clip=clip_name, duration=duration, frames=frame_count,
                              reference_height=height, bytes=size)))


if __name__ == "__main__":
    main()
