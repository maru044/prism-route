"""Measure source alpha only where the actual imported Ganyu surface UVs draw.

First run export_character_npr_inputs.gd to export the unmodified source inputs.
This is an audit, not an automatic material classifier or texture editor.
"""
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


def main():
    project = Path(__file__).resolve().parents[1]
    inputs = project / ".godot/character_npr_inputs"
    geometry_file = inputs / "surfaces.json"
    data = json.loads(geometry_file.read_text(encoding="utf-8"))
    rows = []
    textures = {}
    for surface in data["surfaces"]:
        texture_file = inputs / (surface["texture"] + ".png")
        image = Image.open(texture_file).convert("RGBA")
        alpha = np.asarray(image)[:, :, 3]
        textures[surface["texture"]] = {
            "sha256": hashlib.sha256(texture_file.read_bytes()).hexdigest(),
            "size": list(image.size),
        }
        mask = Image.new("1", image.size)
        draw = ImageDraw.Draw(mask)
        uv = np.asarray(surface["uv"]) * np.asarray(image.size)
        for triangle in np.asarray(surface["indices"]).reshape(-1, 3):
            draw.polygon([tuple(p) for p in uv[triangle]], fill=1)
        values = alpha[np.asarray(mask, dtype=bool)]
        assert len(values), surface["name"]
        rows.append({
            "name": surface["name"], "texture": surface["texture"],
            "covered_texels": len(values), "min_alpha": int(values.min()),
            "max_alpha": int(values.max()),
            "transparent_fraction": float(np.mean(values == 0)),
            "partial_fraction": float(np.mean((values > 0) & (values < 255))),
            "opaque_fraction": float(np.mean(values == 255)),
        })
    report = {
        "source_geometry_sha256": hashlib.sha256(geometry_file.read_bytes()).hexdigest(),
        "method": "Union of UV triangle rasterization at source texture resolution; inclusive texel edges. Material factor alpha is 1.0 for all 19 source surfaces. Fractional edge texels are not automatically classified as translucent fabric.",
        "textures": textures, "surfaces": rows,
    }
    out = project / "docs/water_character_1027/alpha_audit.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"surfaces": len(rows), "fully_opaque_uv_regions": sum(r["min_alpha"] == 255 for r in rows), "report": str(out)}))


if __name__ == "__main__":
    main()
