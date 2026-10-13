"""Create new periodic micro-normal / roughness textures; albedo is untouched."""
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/world/cliff_b_test/textures'


def main():
    size = 1024
    y, x = np.mgrid[0:size, 0:size].astype(np.float64) / size
    rng = np.random.default_rng(14102026)
    field = np.zeros((size, size))
    gx = np.zeros_like(field)
    gy = np.zeros_like(field)
    for _ in range(32):
        fx, fy = rng.integers(-180, 181, size=2)
        phase = rng.uniform(0, 2*np.pi)
        wave = 2*np.pi*(fx*x + fy*y) + phase
        amplitude = rng.uniform(.2, 1) / (1 + np.hypot(fx, fy))
        field += amplitude*np.sin(wave)
        gx += amplitude*fx*np.cos(wave)
        gy += amplitude*fy*np.cos(wave)
    slopes = np.stack([-gx, gy, np.ones_like(gx)*120], axis=-1)
    slopes /= np.linalg.norm(slopes, axis=-1, keepdims=True)
    normal = np.round((slopes*.5+.5)*255).astype(np.uint8)
    rough = np.clip(.73 + field/(np.std(field)+1e-8)*.018, .67, .79)
    OUT.mkdir(parents=True, exist_ok=True)
    Image.fromarray(normal).save(OUT/'warm_white_architecture_normal.png')
    Image.fromarray(np.round(rough*255).astype(np.uint8)).save(OUT/'warm_white_architecture_roughness.png')
    print('New periodic maps: 1024x1024; roughness range', float(rough.min()), float(rough.max()))


if __name__ == '__main__':
    main()
