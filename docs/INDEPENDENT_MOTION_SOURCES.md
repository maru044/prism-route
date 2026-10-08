# 独立人物动作资源：GitHub 与作者发布包

日期：2026-10-08。目标是取得少量女性日常动作，不为动作选型下载整款恋活／COM3D2 整合包。

## 推荐顺序

1. **先测试 Mesh2Motion 的 `Walk_Female`、`Run_Female`，搭配 `Idle_Subtle`**。已经读取实际 GLB，确认有这些动画，而不只是介绍页的文字；这最贴近目前女性移动动作的需求。
2. **用 sashii 的 Josie 重定向包比较另一套 Walk／SlowRun**，同时用 Sachi VRMA 1 的待机／说话作为日常表现候选。
3. **用 rerofumi 的喝水、看手机等动作补充互动表现**。该包不是女性走跑库，不承诺其风格天然符合当前人物。
4. 恋活／CM／COM 留作后续候选。当前先使用独立资源验证流程，再决定是否值得建立游戏数据转换环境。

这些推荐来自文件、格式与来源调查，**尚未在本项目人物上播放或比较审美**。`Female` 是具体片段名，不代表已核实演员性别，也不保证重定向后动作自然。

## A. Mesh2Motion：首选 GitHub 资源

- [主项目](https://github.com/Mesh2Motion/mesh2motion-app)：包含最终 GLB 动画，代码采用 MIT，模型／骨架／动画采用单独的 CC0。
- [动作目录](https://github.com/Mesh2Motion/mesh2motion-app/tree/main/static/animations)。
- [动作资产许可证](https://github.com/Mesh2Motion/mesh2motion-app/blob/main/LICENSE-CC0.MD)：明确覆盖模型、Blender 文件、rig 与动画。
- [Blender 源资产项目](https://github.com/Mesh2Motion/mesh2motion-assets)：适合后续修改动作；首轮不需要克隆全部源文件。

本轮从固定 Git 提交 `653a9698f5f315523072f1c3ff3496100401317b` 读取了以下文件的实际动画列表：

| 文件 | 大小（字节） | 实际动画数量 | 与本项目相关的片段 |
| --- | ---: | ---: | --- |
| `human-addon-animations.glb` | 5,292,804 | 75 | `Walk_Female`、`Run_Female`、`Idle_Subtle`、`Idle Listening`、`Greeting` |
| `human-base-animations.glb` | 5,656,648 | 87 | `Walk`、`Jog`、`Sitting_Enter`、`Sitting_Idle`、`Sitting_Exit`、`Sitting_Talking` |
| `human-mocap-animations.glb` | 2,025,372 | 16 | 左右 90／180 度转身等 |

已保存 addon 文件作为后续测试样本，约 5.05 MiB；base 与 mocap 本轮只在内存中检查。
addon 的 Walk_Female／Run_Female 具有连续时间采样及旋转、平移、缩放轨道，确实是动画而非静态 pose。
该 GLB 是源骨架动画资产，需要映射 rest pose、单位与骨骼轨道，再烘焙到项目的 VRM 人形骨架。

注意：base 中多个动作名与当前项目的 `.res` 名字重合；名字相同不能证明来源相同，但重复测试普通 Walk 的价值有限，首轮优先选 addon 的女性走跑。

## B. VoxAvatar：GitHub 上可逐文件取得的 VRMA 集合

- [项目](https://github.com/SanHsien/voxavatar)。
- [实际动作目录](https://github.com/SanHsien/voxavatar/tree/main/public/assets/animations)。
- [逐资产来源与 SHA-256 清单](https://github.com/SanHsien/voxavatar/blob/main/public/assets/manifest.json)。
- [资产授权说明](https://github.com/SanHsien/voxavatar/blob/main/ASSET_LICENSES.md)。

它是桌面 VRM 应用，不是完整女性动作库，但仓库实际收录 13 个独立 VRMA 文件，可逐个取得而不必安装整套应用。
本轮按它记录的源地址重新核对以下三位作者的发布页；推荐依据是原作者的 CC0 声明，不是桌面应用代码的 MIT 许可证。
该项目自己的质量评分不作为 Prism Route 的播放／审美验证结果。

| 原作者资源 | 作者明确提供的内容／格式 | 发布包大小 | 本轮取得的 GitHub 样本 |
| --- | --- | ---: | --- |
| [sashii — Josie 动作重定向](https://booth.pm/ja/items/7861818) | Run、SlowRun、Walk；VRMA；CC0 | 67.4 KB（压缩包） | `walk.vrma`、`run-slow.vrma`；不是整个三动作包 |
| [sashii — Sachi VRMA 1](https://booth.pm/ja/items/6412084) | Blender 手工动作及 BVH 转换修整动作；VRMA；CC0 | 56.1 MB（完整包） | `idle-01.vrma`、`speaking-01.vrma` |
| [へすい／rerofumi — 短动作包](https://booth.pm/ja/items/5527394) | 8 段：姿态移动、道歉、踏台阶、招呼、手机、喝水、鼓励、惊讶；VRMA 与 Unity Humanoid anim；CC0 | 4.42 MB（完整包） | `review-phone.vrma`、`drink-water.vrma` |

[Josie 原作者页](https://jenjell.itch.io/josie-character-model) 提供 Godot 4 人物包，页面标记资产 CC0、shader MIT，完整包 18 MB。当前先取独立重定向动作，不需要更换项目人物。

本轮保存的 6 个 VRMA 总计 1,143,652 字节，约 1.09 MiB。每个都已确认是 glTF 2 二进制，包含 `VRMC_vrm_animation`、一个非零时长动画及时间采样。
使用固定 Git 提交 `2a757396fe85b995630385794ad0b8c196a29b9f`，六个 SHA-256 均与该提交内的 manifest 一致。
这验证了实际文件取得与基本数据结构，未验证脚底、循环、动作观感或 Godot 扩展名导入兼容性。

## C. 其他独立候选与排除项

| 来源 | 发现与结论 |
| --- | --- |
| [Imaginary Caravan — VRChat IDLE](https://booth.pm/ja/items/1511779) | CC0，8.53 KB；作者明确针对约 140 cm 的女性 avatar。站立有手臂动作，椅子／地面坐姿明确没有动画，只能算姿势。Unity anim 格式路线需要额外烘焙，暂不作为坐起动作库 |
| [Quaternius Universal Animation Library](https://quaternius.com/packs/universalanimationlibrary.html)／[第二套](https://quaternius.com/packs/universalanimationlibrary2.html) | 独立 CC0 动作，提供 FBX／GLB，适合坐起、互动、玩法动作备用；两套总内容介绍不等于 Standard 免费版全部包含，也不等于女性专用。首轮不为基础通用动作重复下载大量内容 |
| [Ready Player Me animation-library](https://github.com/readyplayerme/animation-library) | 有 200+ 动作及女性演员 `F_` 标记，但[许可证](https://github.com/readyplayerme/animation-library/blob/master/LICENSE.md)明确限制用于 Ready Player Me avatars；其他角色需要书面许可。当前 VRM 路线排除 |
| [MMDLoader-app walk/run VMD](https://github.com/takahirox/MMDLoader-app/tree/master/assets/vmd/walk) | 实际含独立 VMD，但附带 Readme 明确是复制、重命名的第三方动作并要求遵守原作者条款；未核实原作者用途授权，不因仓库开源就直接采用 |

## 本机样本与验证范围

样本暂存在项目外的研究目录：

`D:\Prism Route\research\motion_candidates\2026-10-08`

共有 7 个二进制文件（1 GLB + 6 VRMA），合计 6,436,456 字节，约 6.14 MiB。
`sources.json` 和 `inspection.json` 保留取得地址、作者、校验值和基本结构结果。
仓库中的 `docs/INDEPENDENT_MOTION_SAMPLE_MANIFEST.json` 保存同一份调查记录；二进制样本本轮没有提交到 Git，也没有接入默认人物。

已检查：文件真实存在、二进制格式、片段名、动画数量、时间采样、通道、六个 VRMA 的上游校验值。
尚未检查：Godot 导入、VRM 重定向、画面、脚底滑动、循环接缝、动作风格、道具与手部接触。

## 下一轮验证

先从 Mesh2Motion 的女性 Walk／Run + Idle_Subtle 开始，用现有 VRM 做独立预览。
随后对照 Josie 的 Walk／SlowRun 与 Sachi 待机，再补手机／喝水。
固定机位和播放速度，记录接入结果与审美；只在用户确认后替换默认动作。
VRMA 如果不能直接由现有导入器处理，先转成目标骨架上的标准 GLB；不假设文件存在即代表 Godot 已支持完整播放。
