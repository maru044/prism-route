# Rejected painted foliage trial, 2026-10-01

The user judged the painted version too busy: the added small foliage details
made the landscape more cluttered. The stable original LOD is the active version.

This archive retains the generated source, three derived eight-view atlases,
generation prompt, integration source snapshots and four-site comparison images.
The directory is excluded from Godot import with `.gdignore`; production code
does not load the archived textures. Live shader and streamer files were restored
to their pre-trial versions, and the review scene now explicitly shows old LOD.

- `painted_lod/`: generated and baked textures, import settings and provenance.
- `screenshots/`: rejected painted captures, left-old/right-painted comparison
  and measurement record. These are historical review results.
- `integration/`: implementation and review notes before rollback.

The archived scripts and notes retain their original project-relative paths.
They are source snapshots, not directly runnable from their archive location.
Restoring this trial would require intentionally restoring its integration and
asset paths. Do not use it as the default for subsequent foliage work.
