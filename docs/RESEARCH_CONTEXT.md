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
- Small broad-canopy tree: `tree_small_broad_canopy.glb` is the accepted
  approximately 6 m prototype formerly tested as v10. It retains the v8
  layered placement and 240 crossed-card pairs, gently widens the silhouette
  and increases each card's width and height by 25%. The sparse v11 alpha
  texture, straight trunk, volumetric normals, shadow policy and lightweight
  sway fallback remain unchanged. Godot default, overhead and side captures
  show a fuller continuous canopy without obvious top-down holes.
- Accepted medium upright tree: `tree_medium_upright_asymmetric_canopy.glb`
  redistributes the same 30 accepted old-crown groups into a continuously
  staggered upright oval with a low skirt, unequal shoulders, offset apex,
  three-axis group rotation and a horizontally round footprint. It is the
  current upright large-tree baseline. The former five-layer upright asset and
  numbered camphor experiments were deleted; do not recreate their regular
  shelves, column-like outline or excessive exposed trunk.
- Accepted medium broad clustered tree: `tree_medium_broad_clustered_canopy.glb`
  uses 30 variably sized, moderately flattened crown groups. Five groups now
  form a low irregular skirt around the trunk; the remaining groups use a
  wider controlled size range plus gentle pitch, roll and yaw variation rather
  than equal-size horizontal rows. Group centres are distributed radially and
  the generated model rejects horizontal X/Y bounds above a 1.12 aspect ratio,
  preventing the crown from becoming a rectangular prism that works from only
  one angle. Its lower skirt is pulled down around the trunk, while the outer
  rings spread farther and the top contracts; the generator also rejects a
  horizontal-diameter-to-crown-height ratio below 1.18. Its current silhouette
  and massing are close to the video reference. The slightly rounder, fuller
  and cuter result is an intentional strength for this project's clean,
  stylized rendering rather than a defect to correct. Preserve this asset as
  the current large broadleaf baseline; future work should refine it without
  returning to narrow, tall, rectangular or strongly separated clumps.
- Both medium-tree assets encode wind weight in vertex color `R` and each
  card's octahedral plane normal in `G/B`. Their shared gameplay material now
  tests a 0.020–0.140 grazing-angle fade (about 1.15–8.05 degrees from perfectly
  edge-on); background small trees keep the fade disabled. Do not widen this
  again without checking crown density from orthogonal gameplay views.
- Both medium clustered trees now sample the biome palette once at their
  whole-tree anchor and blend 66% whole-canopy ellipsoid normal with 34% of
  the authored local crown normal. Each asset uses its own measured foliage
  bounds rather than sharing one ellipsoid. This isolates excessive per-clump
  color and light gradients without removing all local crown volume.
- Numbered model names are temporary comparisons only. Stable assets use
  descriptive names and must not be overwritten by later experiments.
- The original v8 remains available with `--baseline-tree` for comparison;
  prototype acceptance does not imply a final production asset.
- Rejected v9 experiment: moving all cards into six ellipsoidal clouds lost
  the v8 silhouette and did not make convincing foliage masses. Do not use
  "six balls" as the modelling target; preserve a coherent crown and refine
  its edge and internal overlap instead.
- Rosendal Park Sunset Pure Sky, directional sun, ACES, SSAO and mild glow
  provide the lighting baseline. Dense grass and leaf-card shadows are off to
  avoid dark card-shaped noise; tree trunk shadows remain.

## Current color and grove experiment (not yet accepted)

- `scenes/main.tscn` is now the sole active scene. Earlier single-tree and
  6 × 6 grid scenes have been removed; their captures remain for comparison.
  This scene is a visual test, not the eventual CAD planting layout or an
  LOD/performance conclusion.
- The grass, tree leaves and ground share one world-space, low-frequency
  boundary field. A broad smooth transition and a small noise warp make the
  yellow and muted-green regions interpenetrate without a sharp line or a
  square grid. Ground colors change with the same field, preventing a green
  grass/yellow-gap mismatch. This is a test palette, not an extra texture.
- Grass MultiMesh custom data adds a stable per-blade boundary offset and tiny
  value variation. Tree foliage shares one ShaderMaterial; per-tree `instance
  uniform` tints create restrained variants of the same leaf atlas. No new
  grass or tree species mesh has been introduced.
- The root inspector exposes dry/green colors for grass, tree and ground, plus
  transition width, center, contour warp and grass-color overlap. Tune them
  in Godot before deciding on final biome palettes. The current test is not
  yet wired to the Rhino terrain or Grasshopper placement points.
- The active scene has a provisional planting composition. It replaces the grid
  with a 13-tree asymmetrical main group, a 3-tree small group and a 4-tree
  foreground group, all using the small broad-canopy tree. The original 6 × 6
  scene survives only in historical captures. Compare overhead, default and
  low-viewpoint captures before any claim of a final placement method.
- The active comparison scene places both accepted medium-tree forms:
  `tree_medium_broad_clustered_canopy.glb` at the left foreground and
  `tree_medium_upright_asymmetric_canopy.glb` offset toward the right. They share
  the same leaf material and tint so the comparison isolates crown structure;
  the small broad-canopy trees remain the background planting.

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
