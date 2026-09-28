#!/usr/bin/env python3
"""Generate a deterministic 64x64 progressive blue-noise threshold tile.

The sequence uses toroidal farthest-point insertion.  Every successive coverage
level therefore fills the largest remaining screen-space gap instead of
revealing the regular grid of an ordered Bayer matrix.  The output is a plain
8-bit grayscale PNG and needs no third-party Python packages.
"""

from __future__ import annotations

import binascii
import math
import random
import struct
import zlib
from pathlib import Path


SIZE = 64
SEED = 0x50524953
OUTPUT = (
    Path(__file__).resolve().parents[1]
    / "assets"
    / "vegetation"
    / "textures"
    / "lod_blue_noise_64.png"
)


def build_kernel(sigma: float = 1.9) -> list[float]:
    kernel: list[float] = []
    for y in range(SIZE):
        delta_y = min(y, SIZE - y)
        for x in range(SIZE):
            delta_x = min(x, SIZE - x)
            distance_squared = delta_x * delta_x + delta_y * delta_y
            kernel.append(math.exp(-distance_squared / (2.0 * sigma * sigma)))
    return kernel


def apply_kernel(
    density: list[float], kernel: list[float], center: int, multiplier: float
) -> None:
    center_x, center_y = center % SIZE, center // SIZE
    for y in range(SIZE):
        delta_y = (y - center_y) % SIZE
        row_offset = y * SIZE
        kernel_row = delta_y * SIZE
        for x in range(SIZE):
            delta_x = (x - center_x) % SIZE
            density[row_offset + x] += (
                kernel[kernel_row + delta_x] * multiplier
            )


def build_density(pattern: list[bool], kernel: list[float]) -> list[float]:
    density = [0.0] * len(pattern)
    for index, enabled in enumerate(pattern):
        if enabled:
            apply_kernel(density, kernel, index, 1.0)
    return density


def most_clustered(pattern: list[bool], density: list[float]) -> int:
    return max(
        (index for index, enabled in enumerate(pattern) if enabled),
        key=density.__getitem__,
    )


def largest_void(pattern: list[bool], density: list[float]) -> int:
    return min(
        (index for index, enabled in enumerate(pattern) if not enabled),
        key=density.__getitem__,
    )


def build_thresholds() -> bytes:
    count = SIZE * SIZE
    half_count = count // 2
    rng = random.Random(SEED)
    kernel = build_kernel()
    initial_indices = list(range(count))
    rng.shuffle(initial_indices)
    pattern = [False] * count
    for index in initial_indices[:half_count]:
        pattern[index] = True
    density = build_density(pattern, kernel)

    # Relax the random seed pattern by repeatedly moving its tightest sample
    # into the largest toroidal void.  This is the void-and-cluster step that
    # removes both low-frequency clumps and the lattice visible in Bayer tiles.
    for _iteration in range(count * 2):
        cluster = most_clustered(pattern, density)
        pattern[cluster] = False
        apply_kernel(density, kernel, cluster, -1.0)
        void = largest_void(pattern, density)
        if void == cluster:
            pattern[cluster] = True
            apply_kernel(density, kernel, cluster, 1.0)
            break
        pattern[void] = True
        apply_kernel(density, kernel, void, 1.0)

    ranks = [-1] * count

    # Lower half: peel the tightest occupied samples away.  Reversing the peel
    # order gives progressively even low-coverage masks.
    lower_pattern = pattern.copy()
    lower_density = build_density(lower_pattern, kernel)
    for rank in range(half_count - 1, -1, -1):
        cluster = most_clustered(lower_pattern, lower_density)
        ranks[cluster] = rank
        lower_pattern[cluster] = False
        apply_kernel(lower_density, kernel, cluster, -1.0)

    # Upper half: fill the largest remaining void first.  The complement is
    # therefore blue-noise distributed as coverage approaches one as well.
    upper_pattern = pattern.copy()
    upper_density = build_density(upper_pattern, kernel)
    for rank in range(half_count, count):
        void = largest_void(upper_pattern, upper_density)
        ranks[void] = rank
        upper_pattern[void] = True
        apply_kernel(upper_density, kernel, void, 1.0)

    return bytes(round(rank * 255 / (count - 1)) for rank in ranks)


def png_chunk(kind: bytes, payload: bytes) -> bytes:
    checksum = binascii.crc32(kind)
    checksum = binascii.crc32(payload, checksum) & 0xFFFFFFFF
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", checksum)


def write_png(pixels: bytes) -> None:
    rows = b"".join(
        b"\x00" + pixels[row * SIZE : (row + 1) * SIZE]
        for row in range(SIZE)
    )
    header = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 0, 0, 0, 0)
    contents = (
        b"\x89PNG\r\n\x1a\n"
        + png_chunk(b"IHDR", header)
        + png_chunk(b"IDAT", zlib.compress(rows, 9))
        + png_chunk(b"IEND", b"")
    )
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_bytes(contents)


if __name__ == "__main__":
    write_png(build_thresholds())
    print(OUTPUT)
