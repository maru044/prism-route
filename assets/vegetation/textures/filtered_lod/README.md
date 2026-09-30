# Filtered derivatives of the accepted foliage

No source painting or model is replaced. `SmallTreeFiltering` uses the three
`*_coverage.res` ImageTextures. `*_raw.res` are diagnostic comparisons only.

| Stem | Source PNG in the parent directory | Alpha cutoff |
| --- | --- | --- |
| leaf | leaf_clusters_witness_sparse_flat_v11.png | 0.50 |
| clump | tree_broad_clump_unlit_4var_v1.png | 0.46 |
| canopy | tree_small_canopy_unlit_8view_v1.png | 0.42 |

RGB downsamples in linear color with alpha weighting; alpha-test coverage is
approximately maintained by scaling each mip's alpha. The original level's
visible RGB and alpha are retained. Quantization, trilinear sampling and the
coarsest atlas levels cannot preserve every hole or every individual frame's
coverage exactly. See `build_metadata.json` for measured per-level coverage.

From the repository root, using Python with Pillow and NumPy and Godot 4.7.2:

```powershell
python tools/build_foliage_mips.py
& 'D:\Godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tools/import_foliage_mips.gd
```

Intermediate RGBA chains are ignored under `.vegetation_art_build/foliage_mips`.
The importer writes the compressed resources and their metadata here.
