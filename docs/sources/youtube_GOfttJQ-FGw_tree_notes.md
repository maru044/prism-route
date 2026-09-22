# Tree notes from `GOfttJQ-FGw`

Source: [How I made better foliage than 99% of games](https://www.youtube.com/watch?v=GOfttJQ-FGw), kodiakwhale.  The complete auto-generated English transcript is preserved beside this file as `youtube_GOfttJQ-FGw_transcript.txt`.

## What the source actually establishes

- The texture is a collection of individually readable leaves, inspired by *The Witness*.
- Foliage normals point away from the center of **each leaf clump**, not from one whole-crown ellipsoid.
- Separate low-poly shadow-casting objects rotate with the sun around the clumps. The visible leaf cards stop casting shadows, while the tree can still cast a coherent ground shadow.
- Leaf cards render from both sides.
- Cards that approach an edge-on angle to the camera fade before their plane edge becomes obvious.
- Per-clump interior shadow and blue shadow tint are optional artistic additions, not essential parts of the method.

## Observation and project interpretation

- The screenshots read as roughly **30 overlapping ellipsoidal leaf clumps per tree**, not 6–10. The exact number is a visual estimate; the narration does not state a count.
- A new large-canopy tree should therefore be built from about 24–36 independently oriented clumps, with roughly 30 as the first test, rather than deforming the existing single-crown v10 tree.
- Each clump needs enough cards to retain a fluffy outline. “Thirty clumps” is the crown hierarchy; it is not the total leaf-card count.
- Shadow proxies should follow the same clump hierarchy. They may later be merged for rendering, but should not begin as one featureless whole-crown blob.
- The current v10 source tree is 6.24 m high and 7.70 m wide. Normal grove instances are about 5.9–7.1 m high; the 1.40-scale focal instance is about 8.7 m high.
- A sensible first size target for the new mature, camphor-like tree is about **20 m high**, with an approximately 16–22 m broad crown. Test an 18–24 m range. A 30 m version should be treated as an exceptional old/landmark tree rather than the default.
