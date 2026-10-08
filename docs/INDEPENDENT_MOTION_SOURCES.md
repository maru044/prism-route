# 独立人物动作资源：GitHub 与作者发布包

日期：2026-10-08。目标是取得少量女性日常动作，不为动作选型下载整款恋活／COM3D2 整合包。

当前下载执行入口：[固定下载清单与 42 片段覆盖表](MOTION_DOWNLOAD_CHECKLIST.md)。
该清单固定 9 个文件、准确片段名和校验值，后续取用按 `MOTION_DOWNLOAD_MANIFEST.json` 执行，避免重新从候选库临时查找。

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

初次调查只保存 addon（约 5.05 MiB）；固定下载清单阶段又取得 base 与 mocap。当前三者均已保存并检查。
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

## D. 柔韧、拉伸与地面动作补充

用户希望补充下腰、一字马等可用于日常表现的动作。这里调查的是这些身体运动本身，可用来表现练习、热身、伸展和休息。
需要分别确认姿势与进入／保持／退出动画，不把静态 pose、视频、3D 打印模型或动作名称当作完整骨骼动画。

### 已找到的独立动捕候选

以下三组都是付费商品候选，未购买、未下载；本轮核对了发布者商品说明，并取得作者在商品页提供的预览链接，未逐帧观看视频或验证骨骼文件。

| 来源 | 商品说明明确列出的内容 | 格式证据与待确认事项 |
| --- | --- | --- |
| [XSTAGE — Yoga #2_Stretching](https://www.fab.com/listings/deed2056-a58d-4eac-91f8-2686b7afb4ae)／[作者预览](https://www.youtube.com/watch?v=6bx4w_SwL4I) | 15 段，包含前后劈叉、全身拉伸、坐姿蝴蝶式、卧姿扭转、肩颈与手腕伸展 | 作者描述 FBX、120 fps、商业游戏用途；商品格式栏只显示 Unreal。取得前核对是否直接提供独立 FBX、根运动及具体用途条款。前后劈叉不等于横向劈叉，开腿角度与完整过渡需看预览 |
| [Morro Motion — Yoga MoCap 02](https://www.fab.com/listings/baeb5207-7e6a-4d80-8468-5d34974e8332)／[作者预览](https://www.youtube.com/watch?v=IFZC-lNZlC8) | 15 段，包含后弯序列、平板与侧平板动作 | 商品说明称 FBX 动捕、UE5 Mannequin、60 fps、手指和循环；交付栏显示 Unreal。后弯序列是下腰候选，但未确认是否有从站姿下腰到手脚撑地的完整轮式，不直接承诺精确匹配 |
| [Morro Motion — Yoga MoCap 01](https://www.fab.com/zh-cn/listings/3b54ec1a-2c51-49da-b9b3-ab14e225082b)／[作者预览](https://www.youtube.com/watch?v=-329rs1xB5U) | 15 段，包含树式、天堂鸟式、站立劈腿等 | 同样说明 FBX、UE5 骨架与 60 fps。站立劈腿属于单腿平衡／抬腿柔韧表现，不是坐地一字马，作为补充候选 |

当前优先候选：一字马方向先看 XSTAGE 的前后劈叉；后弯方向先看 Morro Motion 02。
没有取得源文件，不能确认这些片段有合适的进入／保持／退出段，也未确认任何一包包含完整横叉和站立下腰。
作者文档没有给出可核实的当前下载体积或价格，本轮不填写估计值。

[Fab Standard License 摘要](https://www.fab.com/eula)允许兼容工具使用，不限定 Unreal，但不允许把原始资产独立再分发。
具体购买项的许可证、源格式和本项目用途仍要逐件核对，不能把页面写着“FBX”理解为购买后必然能绕过 Unreal 直接取得源文件，也不能把“商业游戏可用”扩大成所有用途已确认。

### GitHub／免费资源目前的边界

- 已检查的 Mesh2Motion addon 包没有名为下腰、劈叉或瑜伽的片段；源资产仓库路径搜索也未找到这些关键词。文件命名搜索不能证明所有动作内容均不存在，本轮没有逐帧观看全部片段。
- 同一 CC0 addon 已确认有 `Meditate`、`Kneeling Tired`、`Pushup`、`Jumping Jacks`、`Sleeping` 等片段，可补充日常休息和运动；不能将它们当作用户指定的下腰／一字马。
- [OpenGym3D](https://github.com/AssiamahS/opengym3d) 中找到 [`glute_bridge.json`](https://github.com/AssiamahS/opengym3d/blob/main/exercises/glute_bridge.json)，但它是仰卧抬臀的臀桥，文件还标记 `draft`；不是手脚支撑的全身下腰，也不是已交付的完整 GLB 动捕。
- 未核实免费 GitHub 上可直接用于本项目的下腰／一字马完整动作文件。固定清单阶段补充的两个 GLB 用于基础坐姿与转身，不能计作这些柔韧动作已补齐。

### 对当前 VRM 的接入建议

这类动作主要依赖骨盆、脊柱、肩臂与腿部骨架，模型没有特殊局部细节也能做动作预览。
视觉上的主要风险是大角度动作的蒙皮、身体与衣物穿插、手脚离地，以及重定向后的身体比例偏差，必须在目标人物上检查。

若只需要下腰和纵／横叉少量动作，可以在 Blender 的目标骨架上单独制作：进入、保持、退出各一段，加入轻微呼吸与重心调整。
下腰使用多段脊柱共同后弯并约束手脚接触；劈叉协调骨盆高度与腿部旋转。不能只拉开两条腿，或让一个腰骨承担全部后弯。
这是自制备用方案，尚未制作，也不因搜索缺少免费文件就自动替换为未经检查的程序动画。

## 本机样本与验证范围

已下载的正式源资源在项目内：

`assets/characters/motion_sources/independent_cc0/`

当前共有 9 个二进制文件（3 GLB + 6 VRMA），合计 14,118,476 字节，约 13.46 MiB。
项目内附来源说明、下载核验 receipt 和 `.gdignore`，用于后续重定向。CC0 原始文件纳入 Git 保存，尚未接入默认人物。
当前完整文件、校验值和 42 个选中片段以 `docs/MOTION_DOWNLOAD_MANIFEST.json` 和源目录 `DOWNLOAD_RECEIPT.json` 为准。
项目外 `D:\Prism Route\research\motion_candidates\2026-10-08` 缓存及仓库 `docs/INDEPENDENT_MOTION_SAMPLE_MANIFEST.json` 保留早期调查记录。

已检查：文件真实存在、二进制格式、片段名、动画数量、时间采样、通道、六个 VRMA 的上游校验值。
尚未检查：Godot 导入、VRM 重定向、画面、脚底滑动、循环接缝、动作风格、道具与手部接触。

## 下一轮验证

先从 Mesh2Motion 的女性 Walk／Run + Idle_Subtle 开始，用现有 VRM 做独立预览。
随后对照 Josie 的 Walk／SlowRun 与 Sachi 待机，再补手机／喝水。
固定机位和播放速度，记录接入结果与审美；只在用户确认后替换默认动作。
VRMA 如果不能直接由现有导入器处理，先转成目标骨架上的标准 GLB；不假设文件存在即代表 Godot 已支持完整播放。
