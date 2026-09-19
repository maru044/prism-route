# Research context for ChatGPT and future contributors

Read this before proposing changes to the vegetation. The source of truth for
current numeric parameters is `scripts/vegetation_test.gd`; this note explains
the intent and the result of previous visual tests.

## Art direction and acceptance

- Stylized, fresh, quiet color blocks; *less is more*. Texture alpha defines
  plant silhouettes, while the engine supplies volume, lighting and shadows.
- Do not paint directional shadow, strong color contrast, random mottling or
  photoreal leaf detail into the grass/tree textures.
- Test from gameplay-scale and overhead cameras in Godot Forward+, not just a
  Blender preview. Compare screenshots and dynamic wind over time.
- Grass is a continuous, dense, roughly 0.8–1 m tall natural straw meadow,
  not short lawn or scattered decoration. Do not change its point distribution
  or density merely to add randomness; the current distribution was accepted.
- The crown must be broad and dense, made from many irregularly oriented small
  foliage cards. Keep one comparatively thin, straight trunk. Avoid low
  decorative branching or a handful of large upright planes.

## Current accepted implementation

- Grass: `grass_star_3card_v6.glb`, `grass_tuft_straw_minimal_v5.png`, 63,000
  instances in 4 m chunks on a 24 m radius test ground. Grass-card normals
  point upward; the cutout texture is essentially one RGB color.
- Grass texture mipmaps are enabled to reduce distant cutout aliasing. They do
  not themselves solve gaps between the alpha-cut blades.
- A restrained height-only tone gives roots `0.90` and tips `1.045`; do not
  replace it with painted gradients or strong directional shadow.
- The visible ground color is `#968A55`. This similar, darker straw hue makes
  gaps between blades read as internal depth instead of green needle noise.
  Future biomes should pair their grass and ground-root palette, not force one
  global ground color across every terrain region.
- `vegetation_wind.gdshader` samples a seamless OpenSimplex-derived world
  noise texture for moving tonal waves and small vertex displacement. A cubic
  Bezier response narrows dark-band occupancy without turning contours into
  regular stripes. A second, slow time-only noise envelope varies whole-field
  wind strength smoothly between roughly 45% and 115%, affecting both sway
  and tonal bands. Local gusts still move through the field.
- Tree: `tree_foliage_480card_v8.glb` with a restrained sparse leaf-cluster
  alpha texture, volumetric canopy normals and a single straight trunk. The
  tree currently uses a separate lightweight sway fallback.
- Rosendal Park Sunset Pure Sky, directional sun, ACES, SSAO and mild glow
  provide the lighting baseline. Dense grass and leaf-card shadows are off to
  avoid dark card-shaped noise; tree trunk shadows remain.

## Experiments not to reintroduce without a specific new reason

- Grass distance/alpha/chunk fade made the meadow disappear in the test view.
  It was removed. Do not equate fading out grass with solved LOD.
- Strong transmission/backlighting made the grass look more realistic than
  cartoon-stylized and was removed. A tiny invisible setting was not retained.
- A stronger root-to-tip gradient (`0.82` to `1.08`) became too realistic;
  `0.87` to `1.06` was still too strong. The accepted range is above.
- The previous dark olive ground (`#696C48`) showed through the sparse alpha
  texture as deep green needles. Mipmaps alone did not solve that hue contrast.
- Do not add high-frequency random colors, physical per-blade simulation or
  conspicuous planar leaf-card self-shadowing without an in-engine comparison.

## How to hand off a research task

In a normal ChatGPT **Chat** conversation, cite primary sources and return a
short GitHub Issue draft with these sections:

1. The specific visual or technical problem, with a screenshot and Godot
   viewing condition where useful.
2. Two or three source-backed techniques, with exact links and version notes.
3. What to try first in this project, referring to existing files/parameters.
4. Risks to the stylized art direction, density and performance.
5. A falsifiable in-engine test and rollback condition.

Research is not authorization to change the project. Codex implements one
approved, bounded Issue at a time and verifies it in Godot. Distinguish cited
facts from hypotheses, and do not present a different engine's feature as a
Godot 4.6 feature without checking the Godot documentation.
