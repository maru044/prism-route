"""Build a fuller mid-frequency leaf atlas without baked lighting."""

from pathlib import Path

from PIL import Image, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "vegetation" / "textures" / "leaf_clusters_witness_sparse_flat_v11.png"
OUTPUT = ROOT / "assets" / "vegetation" / "textures" / "leaf_cluster_filler_full_v4.png"

ATLAS_SIZE = 1024
CELL_SIZE = ATLAS_SIZE // 2
WORK_SIZE = 256
FOLIAGE_COLOR = (104, 124, 82)


def alpha_curve() -> list[int]:
    values = []
    for value in range(256):
        t = max(0.0, min(1.0, (value - 68.0) / 104.0))
        t = t * t * (3.0 - 2.0 * t)
        values.append(round(t * 255.0))
    return values


def process_cell(cell: Image.Image) -> Image.Image:
    alpha = cell.convert("RGBA").getchannel("A")
    alpha = alpha.resize((WORK_SIZE, WORK_SIZE), Image.Resampling.LANCZOS)
    # Join only immediately adjacent leaves. This raises effective coverage
    # without turning a cluster into a single opaque fan shape.
    alpha = alpha.filter(ImageFilter.MaxFilter(5))
    alpha = alpha.filter(ImageFilter.GaussianBlur(0.40))
    alpha = alpha.point(alpha_curve())
    alpha = alpha.resize((CELL_SIZE, CELL_SIZE), Image.Resampling.BICUBIC)
    result = Image.new("RGBA", (CELL_SIZE, CELL_SIZE), (*FOLIAGE_COLOR, 0))
    result.putalpha(alpha)
    return result


def main() -> None:
    source = Image.open(SOURCE).convert("RGBA")
    source_width = source.width // 2
    source_height = source.height // 2
    atlas = Image.new("RGBA", (ATLAS_SIZE, ATLAS_SIZE), (0, 0, 0, 0))
    for index in range(4):
        column = index % 2
        row = index // 2
        cell = source.crop((
            column * source_width,
            row * source_height,
            (column + 1) * source_width,
            (row + 1) * source_height,
        ))
        atlas.alpha_composite(process_cell(cell), (column * CELL_SIZE, row * CELL_SIZE))
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(OUTPUT, optimize=True)
    alpha = atlas.getchannel("A")
    coverage = sum(alpha.histogram()[128:]) / float(ATLAS_SIZE * ATLAS_SIZE)
    print(f"FILLER_LEAF_TEXTURE_V4_BUILD_COMPLETE coverage={coverage:.3f} {OUTPUT}")


if __name__ == "__main__":
    main()
