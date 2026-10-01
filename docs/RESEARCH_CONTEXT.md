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

## Accepted trunk implementation

- The three descriptive tree assets now include the accepted refined trunks;
  no separate candidate or runtime legacy-trunk switch remains.
- Trunks are quiet, nearly straight multi-ring meshes rather than
  perfect cones. Variation is limited to subtle ring rotation, ellipticity and
  centre offsets; there is no bark noise, baked shading or decorative bend.
- The small tree remains branchless. Its trunk has 6 rings, 10 sides,
  height 3.25 m and radii 0.145–0.074 m. The two medium trunks have 8
  rings, 12 sides, a modest 0.36 m root flare and taper to 0.118 m inside the
  crown at heights 6.4 m (broad) and 6.2 m (upright).
- Godot overrides all trunk surfaces with one rough, desaturated
  warm dark material (`#342A24`). The texture contains no lighting detail.
- These trees intentionally have no visible primary branches: their crowns are
  already dense and detailed enough that added structure would create noise
  without improving readability. Do not introduce branches unless a future,
  substantially more open tree species specifically requires them.

## Accepted color and grove test baseline

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
- The active scene places both accepted medium-tree forms in the back layer:
  `tree_medium_broad_clustered_canopy.glb` is the large cherry-flower tree and
  `tree_medium_upright_asymmetric_canopy.glb` is the orange autumn tree. Older
  A0-A2 capture modes keep them green for structural baseline comparisons;
  the small broad-canopy trees remain the background planting.
- A provisional flower/autumn palette study now places four identical
  `tree_small_broad_canopy.glb` instances at the front of the grove. From left
  to right they test cherry pink, golden yellow, orange-red and burgundy-red.
  All four use the same scale, orientation, alpha silhouette, normals and wind,
  so the comparison isolates color and light response.
- Species palettes do not multiply pink/orange by the green atlas RGB. The
  atlas supplies alpha plus only 8% restrained luminance detail; instance
  uniforms provide deep, shadow, middle, light and optional accent colors.
  Direct color still uses canopy normals, sun direction and `ATTENUATION`,
  while the shadow color remains the ambient/base response. The rejected A0
  branch uses an 8–14% low-frequency accent field; A1 and A2 disable it.
- Issue #5 phase A now has a one-command comparison. `--capture-flower-a0`
  preserves the rejected three-tone/accent-noise paint-bucket baseline;
  `--capture-flower-a1` enables the four-role `deep/shadow/mid/sun` remap and
  disables accent noise. Additional A1 checks use `--capture-flower-a1-45`,
  `--capture-flower-a1-top` and `--capture-flower-a1-cherry`. A1 uses current
  directional `LIGHT`, `LIGHT_IS_DIRECTIONAL` and `ATTENUATION`; grass and
  ordinary green foliage remain on the accepted legacy branch. These palettes
  are rendering validation, not four new tree models or accepted final colors.
- A1's nested `smoothstep` chain produced visible contour-like color bands.
  A2 is now the default test: it uses broad overlapping shadow/mid/sun weights
  instead of four sequential thresholds, with a very weak world-space macro
  warp applied only to the lighting boundary. It does not paint noise directly
  into the leaf color. `deep` is deliberately dormant in A2 until phase B has
  a real interior-volume/occlusion signal; using N.L alone for `deep` made a
  false back-facing band. Validate A2 with `--capture-flower-a2`,
  `--capture-flower-a2-45`, `--capture-flower-a2-top` and
  `--capture-flower-a2-cherry`. Front, 45-degree, top and cherry close-up tests
  confirm that the transition remains continuous across views without changing
  geometry, alpha, card-angle fading, normals, wind, grass or green foliage.
- A2 still produced excessive value contrast because the Issue #5 palette
  endpoints spanned dark purple/brown to near-white and the direct palette was
  added over a shadow-colored environment base. A3 is now the default study.
  It keeps A2's continuous weights but compresses every species into a tighter
  hue/value family, mixes 42% of the mid color into the indirect-light base,
  and reduces the colored direct-light contribution to 42% of A2. This keeps
  the crown readable as one color before it is read as light and shadow. Use
  `--capture-flower-a3`, `--capture-flower-a3-45`,
  `--capture-flower-a3-top` and `--capture-flower-a3-cherry` for its four-view
  check; A0, A1 and A2 remain selectable comparison baselines.
- The palette-study planting is organized as a shallow four-tree arc rather
  than a rigid row. The trees use generous lateral gaps so every crown and
  trunk remains readable. The broad and upright large trees sit deeper in the
  two intervening gaps, while the former right-front small trees have moved to
  a loose right-edge cluster. This preserves an open central grass bay and
  prevents unrelated green crowns from contaminating palette comparisons.
- The two accepted medium/large models now also test A3 species color in the
  default scene: `tree_medium_broad_clustered_canopy.glb` is the cherry-flower
  tree and `tree_medium_upright_asymmetric_canopy.glb` is the orange autumn
  tree. This is intentionally shader-only reuse: both keep their formal trunk,
  card layout, canopy normals, angle fade and shadow behavior. Top view confirms
  the large and small crowns are spatially separate even where the perspective
  view overlaps them. Older A0-A2 comparison modes leave both large trees green
  so their original palette baselines remain reproducible.

## Species expansion baseline, 2026-09-26

- `tree_medium_birch_upright_canopy.glb` is a true species model, not a recolor
  of the accepted upright broadleaf. It is approximately 11.6 m tall, uses 24
  overlapping crown groups and 1,152 randomly oriented cards. Its horizontal
  section remains near-round; the vertical oval and pale trunk create the
  birch silhouette. Three nearby instances are the intended first planting
  test, rather than a single artificial specimen.
- Birch bark uses `bark_birch_flat_v1.png`: warm off-white with sparse broken
  grey horizontal lenticels. It contains no directional shade or normal-map
  detail. At gameplay distance it must read as one pale trunk before individual
  marks become visible.
- `tree_medium_columnar_cypress.glb` uses 27 overlapping tapered volumes plus a
  small centered terminal volume, for 1,108 cards in total. Foliage begins near
  the ground. The outline may be irregular,
  but it must not become either a perfect Christmas-tree cone or a stack of
  horizontal shelves. Its low-contrast olive palette is shader-controlled. The
  current silhouette remains a rejected visual study rather than an accepted
  production tree; its geometry and density may change with the next redesign.
- The original species prototypes used 7,200 birch cards and 6,720 cypress
  cards. Those counts were generator overfill, not an artistic requirement:
  every card already carries a complete porous atlas cluster. The accepted
  near assets therefore use 24 crossed cells per birch group and 20 per cypress
  group. Their cards are deliberately broader than the discarded high-density
  prototype: card footprint and atlas negative space provide crown continuity,
  rather than thousands of overlapping sheets. Do not restore density by
  multiplying cards inside each volume; add or reshape crown volumes only when
  the silhouette itself requires it.
- `shrub_medium_rounded_canopy.glb` is the single accepted shrub asset. It uses
  `shrub_leaf_lobes_billboard_flat_v3.png` and five independently pivoted
  Y-billboard lobes. Every lobe contains a complete porous foliage silhouette;
  these are not miniature tree foliage systems and must not be expanded to
  hundreds of single-leaf cards. All lobes are packed into one foliage
  MeshInstance3D; UV2 and vertex alpha preserve each local pivot so the shader
  rotates every quad around its own center in one draw call. This retains
  limited parallax, stays suitable for later MultiMesh placement, and removes
  fixed crossed-card edges and view-angle-fade density popping.
- Shrubs do not use `use_view_angle_fade`. Billboard orientation solves the
  edge-on problem directly. The lobe meshes use bulged corner normals for a
  soft volume response and `MAIN_CAM_INV_VIEW_MATRIX` so the shadow pass keeps
  the gameplay-camera orientation. The shrub ball is approximately
  person-height, remains readable above the 0.8–1 m meadow and keeps all woody
  structure concealed. Do not add a bare-stem shrub variant without a new
  explicit art requirement.
- Shrubs are planted as deliberate groups rather than random meadow scatter:
  four rounded shrubs form one compact group with breathing space around it.
  This scene tests appearance, not final CAD landscape placement.
- The three new alpha atlases were generated as transparent source silhouettes,
  then deliberately flattened by `tools/prepare_species_textures.py`. Never
  reintroduce the generated internal highlights, shadows or colored edge
  pixels. RGB is restrained and nearly uniform; Godot provides volume.
- The main scene keeps fewer ordinary small trees than the earlier test. The
  freed left and right areas hold the birch, cypress and shrub-ball group. The
  accepted old trees remain untouched.

## Experiments not to reintroduce without a specific new reason

- Island redesign direction, 2026-10-01: northern beach, southern cliffs;
  terrain can expose near-future artificial infrastructure beneath vegetation.
  The southern area should use a few connected broken terraces / small islands
  with explorable interiors and possible habitation. The user rejected excessive
  cliff height and weak connectivity. See `ISLAND_MEGASTRUCTURE_TERRAIN_PLAN.md`
  for a discussion proposal and fresh main-entry screenshots; the map geometry
  has not been changed to implement that proposal.

- As of 2026-10-01, the user accepted smooth small-tree crown shading and
  coverage-preserving mips as the baseline for the main entry, review and grove.
  Keep strengths 0.62 / 0.35 / 0.0 for near / middle / far; do not reintroduce
  the former shading toggle. Historical evidence and tools are in
  `archive/small_tree_baseline_2026-10-01/`; see
  `FOLIAGE_SIMPLIFICATION_RESULTS.md`. Original tree geometry remains accepted.

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
