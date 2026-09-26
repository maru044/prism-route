"""Prepare restrained game textures from generated transparent silhouettes.

The image generator is used only for alpha silhouettes.  RGB is deliberately
flattened here so lighting stays in Godot instead of being painted into cards.
This also removes colored fringe pixels from transparent source images.
"""

from __future__ import annotations

import argparse
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw


def flatten_alpha(source: Path, target: Path, color: tuple[int, int, int]) -> None:
    image = Image.open(source).convert("RGBA")
    alpha = image.getchannel("A")
    image = Image.new("RGBA", image.size, (*color, 255))
    image.putalpha(alpha)
    image = image.resize((1024, 1024), Image.Resampling.LANCZOS)
    target.parent.mkdir(parents=True, exist_ok=True)
    image.save(target, optimize=True)


def flatten_generated_green_mask(
    source: Path, target: Path, color: tuple[int, int, int]
) -> None:
    """Recover alpha when an image generator paints a checkerboard backdrop.

    The shrub source is olive-green against a neutral grey/white checkerboard.
    Saturation therefore gives a stable silhouette mask without importing any
    of the generated lighting or colour variation into the game texture.
    """
    source_image = Image.open(source).convert("RGBA")
    saturation = source_image.convert("RGB").convert("HSV").getchannel("S")
    recovered_alpha = saturation.point(
        lambda value: max(0, min(255, round((value - 8) * 255 / 34)))
    )
    alpha = ImageChops.multiply(source_image.getchannel("A"), recovered_alpha)
    image = Image.new("RGBA", source_image.size, (*color, 255))
    image.putalpha(alpha)
    image = image.resize((1024, 1024), Image.Resampling.LANCZOS)
    target.parent.mkdir(parents=True, exist_ok=True)
    image.save(target, optimize=True)


def create_birch_bark(target: Path) -> None:
    rng = random.Random(20260926)
    width, height = 256, 512
    base = (211, 207, 194, 255)
    mark = (151, 146, 137, 255)
    image = Image.new("RGBA", (width, height), base)
    draw = ImageDraw.Draw(image, "RGBA")

    # Sparse, broken horizontal lenticels.  They are intentionally soft and
    # mid-grey rather than black; no directional shade or vertical gradient.
    for row in range(19):
        y = int((row + 0.55) * height / 19.0 + rng.uniform(-6.0, 6.0))
        segment_count = rng.randint(2, 4)
        for _ in range(segment_count):
            x0 = rng.randint(4, width - 48)
            length = rng.randint(18, 64)
            thickness = rng.choice((2, 3, 3, 4, 5))
            color = (*mark[:3], rng.randint(70, 112))
            draw.rounded_rectangle(
                (x0, y, min(width - 4, x0 + length), y + thickness),
                radius=max(1, thickness // 2),
                fill=color,
            )
    target.parent.mkdir(parents=True, exist_ok=True)
    image.save(target, optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--birch-source", type=Path, required=True)
    parser.add_argument("--cypress-source", type=Path, required=True)
    parser.add_argument("--shrub-source", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()

    flatten_alpha(
        args.birch_source,
        args.output_dir / "leaf_clusters_birch_sparse_flat_v1.png",
        (123, 148, 78),
    )
    flatten_alpha(
        args.cypress_source,
        args.output_dir / "foliage_cypress_sprays_flat_v1.png",
        (73, 91, 55),
    )
    flatten_generated_green_mask(
        args.shrub_source,
        args.output_dir / "shrub_leaf_lobes_billboard_flat_v3.png",
        (108, 130, 74),
    )
    create_birch_bark(args.output_dir / "bark_birch_flat_v1.png")


if __name__ == "__main__":
    main()
