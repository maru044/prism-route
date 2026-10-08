# Independent CC0 motion sources

Pinned original source files for the character animation study: three GLBs and
six VRM Animation files, totaling 14,118,476 bytes (13.46 MiB).

The GLBs contain source armatures and multiple animation clips. Each VRMA has
one animation. These are source assets awaiting retargeting and visual review,
not runtime animation resources for the current character.

`.gdignore` keeps Godot from importing this source directory automatically.

## Download and verify

From the repository root, run with Python 3:

```powershell
python tools/download_motion_sources.py
python tools/download_motion_sources.py --verify-only
```

The downloader checks existing project files first, then the research cache,
then the pinned source URLs. All bytes must match the manifest's SHA-256.
`DOWNLOAD_RECEIPT.json` records the verified project copies.

## Sources and licenses

All nine selected motion files are provided under **CC0 1.0 Universal**.
The motions retain their own asset licenses independently of application code.

| Files | Creator / source | License evidence |
| --- | --- | --- |
| `human-*-animations.glb` | Mesh2Motion contributors | [Pinned asset license](https://github.com/Mesh2Motion/mesh2motion-app/blob/653a9698f5f315523072f1c3ff3496100401317b/LICENSE-CC0.MD) |
| `idle-01.vrma`, `speaking-01.vrma` | sashii | [Sachi VRMA 1 original release](https://booth.pm/ja/items/6412084) |
| `walk.vrma`, `run-slow.vrma` | sashii (retarget), JenJell (Josie original) | [Retarget release](https://booth.pm/ja/items/7861818), [Josie original](https://jenjell.itch.io/josie-character-model) |
| `review-phone.vrma`, `drink-water.vrma` | へすい / rerofumi | [Original motion pack](https://booth.pm/ja/items/5527394) |

The VRMA files were obtained from the pinned
[VoxAvatar asset collection](https://github.com/SanHsien/voxavatar/tree/2a757396fe85b995630385794ad0b8c196a29b9f/public/assets/animations).
Their hashes match that collection's per-asset source manifest.
[CC0 legal text](https://creativecommons.org/publicdomain/zero/1.0/legalcode).

For the exact 42 selected clip names and known coverage gaps, see
[the checklist](../../../../docs/MOTION_DOWNLOAD_CHECKLIST.md) and
[the machine-readable manifest](../../../../docs/MOTION_DOWNLOAD_MANIFEST.json).
