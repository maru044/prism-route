"""Acquire the pinned independent motion files and verify their original bytes."""

import argparse
import hashlib
import json
from pathlib import Path
import struct
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "docs/MOTION_DOWNLOAD_MANIFEST.json"
OUTPUT = ROOT / "assets/characters/motion_sources/independent_cc0"


def validate(raw, entry, actions):
    if len(raw) != entry["bytes"]:
        raise ValueError(f"Wrong size: {entry['file']}")
    if hashlib.sha256(raw).hexdigest() != entry["sha256"]:
        raise ValueError(f"Checksum mismatch: {entry['file']}")
    magic, version, length = struct.unpack_from("<4sII", raw)
    if magic != b"glTF" or version != 2 or length != len(raw):
        raise ValueError(f"Invalid glTF binary: {entry['file']}")
    json_length, kind = struct.unpack_from("<II", raw, 12)
    if kind != 0x4E4F534A:
        raise ValueError(f"Missing JSON chunk: {entry['file']}")
    gltf = json.loads(raw[20:20 + json_length])
    animations = gltf.get("animations", [])
    if len(animations) != entry["animation_count"]:
        raise ValueError(f"Changed animation count: {entry['file']}")
    names = {animation.get("name", "") for animation in animations}
    for action in actions:
        if action["file_id"] != entry["id"]:
            continue
        if action["clip_selection"] == "only animation index 0":
            if len(animations) != 1:
                raise ValueError(f"Ambiguous single clip: {entry['file']}")
        elif action["clip_name"] not in names:
            raise ValueError(f"Missing clip: {action['clip_name']}")
    if entry["file"].endswith(".vrma"):
        if "VRMC_vrm_animation" not in gltf.get("extensions", {}):
            raise ValueError(f"Missing VRMA extension: {entry['file']}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify-only", action="store_true",
                        help="Check the project copies without downloading or writing.")
    args = parser.parse_args()
    plan = json.loads(MANIFEST.read_text(encoding="utf-8"))
    cache = Path(plan["cache"])
    if not args.verify_only:
        OUTPUT.mkdir(parents=True, exist_ok=True)
    verified = []
    for entry in plan["files"]:
        name = entry["file"]
        if Path(name).name != name or "\\" in name:
            raise ValueError(f"Expected a plain filename: {name}")
        target = OUTPUT / name
        if target.exists():
            raw = target.read_bytes()
            acquisition = "existing project file"
        elif args.verify_only:
            raise FileNotFoundError(target)
        elif (cache / name).is_file():
            raw = (cache / name).read_bytes()
            acquisition = "verified download cache"
        else:
            request = Request(entry["download_url"],
                              headers={"User-Agent": "Prism-Route-motion-download"})
            with urlopen(request, timeout=60) as response:
                raw = response.read()
            acquisition = "pinned source download"
        validate(raw, entry, plan["actions"])
        if not args.verify_only and not target.exists():
            temporary = target.with_suffix(target.suffix + ".download")
            temporary.write_bytes(raw)
            temporary.replace(target)
        verified.append({"id": entry["id"], "file": name, "bytes": len(raw),
                         "sha256": hashlib.sha256(raw).hexdigest(),
                         "download_url": entry["download_url"],
                         "source_url": entry["source_url"],
                         "license": entry["license"],
                         "acquisition": acquisition})
        print(f"OK {entry['id']} {name} ({len(raw):,} bytes; {acquisition})")
    if len(verified) != plan["total_files"]:
        raise ValueError("File count differs from the plan")
    if sum(entry["bytes"] for entry in verified) != plan["total_bytes"]:
        raise ValueError("Total bytes differ from the plan")
    if not args.verify_only:
        receipt = {"manifest_date": plan["date"], "files": verified,
                   "total_bytes": plan["total_bytes"],
                   "selected_clip_count": len(plan["actions"]),
                   "verification": "Original SHA-256, sizes, binary headers and selected clip presence passed; no runtime playback test."}
        (OUTPUT / "DOWNLOAD_RECEIPT.json").write_text(
            json.dumps(receipt, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Verified {len(verified)} files and {len(plan['actions'])} selected clips.")


if __name__ == "__main__":
    main()
