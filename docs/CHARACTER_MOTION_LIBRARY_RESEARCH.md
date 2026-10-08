# 人物动作库调研与首轮测试计划

日期：2026-10-08。用户优先希望获得恋活／ILLUSION 风格的女性动作；MMD 模型转 VRM 留待后续。
本轮完成公开来源、格式和项目接入方式的调研，尚未下载收费动作、提取游戏数据或实机重定向。

## 结论与优先级

1. **先尝试恋活的日常动作导出**：有作者教程和开源工具作为依据，但没有确认可直接下载并导入 Godot 的完整、授权明确的恋活动作库。
2. **AI 少女／HS2 作为第二条技术路线**：可以调查 Unity 资源工具，尚未确认针对这些游戏能直接成功导出的具体动作集。
3. **格式明确的女性 FBX 动作包作为备用**：优先看 VanillaLoop 和 HandMade 的移动动作；日常姿态补充看 Reallusion、Sway Motion。
4. 动作风格必须在当前人物上对照。女性标签或换到女性模型并不保证符合想要的表演风格；骨骼比例和重定向也会影响结果。

## 首选：恋活

### A. 原有动作 → SB3Utility／KKBP → Blender

KKBP 作者的 [动画导出和导入说明](https://kkbpwiki.github.io/import_panel) 明确提供游戏动画的操作入口。
作者的 [动画库教程视频](https://www.youtube.com/watch?v=Ezsy6kwgBE0) 演示借助 SB3Utility 导出动画并在 Blender 中建立库，也说明应用完整动画而非单帧姿势。
这是值得优先测试的现有动作转换路线，不等同于 KKBP 模型导出按钮会自动导出全部动作。

限制：

- 作者页面指向的旧 `createanimationlibrary.py` GitHub 链接本轮返回 404；需要核对实际可获取的 KKBP 版本和功能，不能承诺当前版本一键可用。
- [KKBP 主文档](https://kkbpwiki.github.io/) 推荐 Blender 4.2 LTS；其他版本不保证兼容。人物导出使用 PMX 和 MMD Tools，可准备目标应用骨架。
- 完整动作与静态 pose 不同，首轮必须验证时长、关键帧和循环，而不是只导入姿势预览。
- 需要用户已有游戏安装目录及版本，随后检查具体文件和工具匹配；本轮未检查本机游戏目录。

### B. Studio Timeline → KKBridge → VMD

[KKBridge](https://github.com/rintrint/KKBridge) 是 BepInEx 插件，明确支持将恋活 Timeline 动画导出为 VMD，供 MMD／Blender MMD Tools 使用。
作者建议 Koikatu 优先于 Sunshine，骨架映射基于 Tda 标准；构建要求包含 Visual Studio 2022 和游戏／Timeline 依赖。

适合测试 Studio 内制作或播放的时间轴动作，但文档没有证明它会把所有内置 Animator 动作自动烘焙成 VMD。
是否能录下内置动作、IK 和约束后的最终骨骼运动，需要用一个具体片段验证，不能把工具说明当作完整动作库。

工具的 MIT 授权只覆盖工具代码，不能据此认定导出的游戏动作可用于本项目公开发行。
导出技术、动作质量和动作的使用授权分别记录；游戏原动作、社区原创动作也应区分来源。

## 第二选择：AI 少女／Honey Select 2

[SB3Utility](https://github.com/enimaroah/SB3Utility) 是面向 ILLUSION 游戏的资源工具。
[AssetStudio](https://github.com/Perfare/AssetStudio) 的 README 明确支持 Animator 与 AnimationClip 一同导出 FBX，并支持 Unity 3.4–2022.1；原仓库已归档。

这些是候选工具，不是对 AI 少女／HS2 导出成功的实测结论。
需要实际资源验证骨架／Avatar 绑定、动画压缩、根运动、游戏中 IK／约束与程序修正是否被保留。
单独取出 AnimationClip 并不保证获得能在其他骨架上播放的完整运动。
本轮没有找到足以确认“可直接使用的 AI 少女女性日常 FBX/BVH 完整库”的作者来源。

## 备用库

| 来源 | 已确认内容／格式 | 用途与状态 |
| --- | --- | --- |
| [VanillaLoop — Female Locomotion Set](https://www.fab.com/listings/e111d3ee-26f2-496f-bd1c-72884ede5f3d) | 女性走、慢跑、跑、跳、蹲、俯卧等；页面明确 Additional Files 提供 FBX 与 MotionBuilder 文件 | 首选移动动作备用；实际循环、比例适配及成人游戏用途条款仍需核对 |
| [HandMade — Female Locomotion Animations](https://www.fab.com/listings/3df5b4e7-5a62-4d05-b3a5-54d70f8cc9f0) | 女性走、跑、转向；提供 FBX，描述包含原地与根运动版本 | 第二组移动对照；不是整套控制器或玩法系统 |
| [Reallusion — Female Casual Moves](https://www.reallusion.com/contentstore/iclone/pack/femalecasualmoves/default.html) | 女性待机、走跑和坐卧等日常表现 | 日常动作候选；页面未确认可直接下载独立 FBX，须核对具体 SKU、导出能力和软件成本 |
| [Sway Motion — Walking Naturally](https://booth.pm/ja/items/6160883)／[店铺](https://swaymotion.booth.pm/) | 循环自然步行，另有女性站姿、坐姿、待机；以 Unity 动画交付为主 | 日常姿态候选；逐件检查是否只有 `.anim`、是否能烘焙转出，以及本项目用途授权 |

[Fab Standard License 摘要](https://www.fab.com/eula) 允许兼容工具使用，不限定 Unreal，也允许把资产嵌入商业项目。
因此“在 Fab 上销售”本身不妨碍 Godot 接入；仍需确认具体商品提供的许可证、源文件和适用条款。
本轮没有验证这些商品对成人游戏的完整授权，不能将“可商用”直接写成“已确认适合本 H 游戏”。
收费原始动作及其转换版本不默认提交到公开 GitHub；根据取得的授权保存工作副本与来源记录。

### 已排除的一个匹配包

[MotionPackage 第 98 弹“歩く走る女性”](https://booth.pm/ja/items/8304424) 有 20 段动作，提供 30 fps Humanoid FBX，涵盖待机、转向、走跑及不同表现风格，页面标价 ¥2,000。
但作者条款明确禁止用于性内容及显著暴力内容，**不列入本 H 游戏可用资源**。
记录它是为了避免后续仅看到“女性 FBX、可商用”就误购。

## 格式与接入路径

| 输入 | 计划处理 |
| --- | --- |
| FBX | 检查源骨架、rest pose、单位和根运动；导入 Godot 做 Humanoid 映射，或先经 Blender 整理后导出 GLB 动画 |
| BVH | Blender 导入骨骼运动，映射到统一人形骨架并处理根运动；面部通常另行制作 |
| VMD | MMD Tools 加载到兼容源骨架，烘焙 IK／约束结果，再做人形重定向和 GLB 导出；不能只改骨骼名字 |
| Unity `.anim` | 区分 transform 曲线与 Humanoid muscle 数据；可能需要匹配 Avatar、Unity 播放并烘焙，不能改后缀冒充 FBX |
| VRMA | 项目插件已有 `VRMC_vrm_animation` 支持代码；实际文件扩展名、导入流程和播放需样本验证 |

[Godot 官方骨骼重定向文档](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/retargeting_3d_skeletons.html) 使用 BoneMap／SkeletonProfileHumanoid 统一人形骨架。
本项目 VRM 导入器也执行骨名和 rest pose 重定向，因此不必等待所有 MMD 模型转换完才开始动作选型。
最终只将适配当前目标骨架、路径正确的动作资源接入 AnimationPlayer／AnimationTree。

## 当前项目证据

- `scenes/characters/ganyu.tscn` 已引用 VRM 模型和 45 个 `.res` 动画资源，包含 Idle、Walk、Walk_Formal、Sitting 等。
- `scripts/vegetation_test.gd` 播放当前人物的 Idle。
- `addons/vrm/importer/common/vrm_skeleton_retargeting.gd` 统一骨名并使用 `GeneralSkeleton`。
- `addons/vrm/plugin.gd` 注册 `vrmc_vrm_animation.gd`，该扩展包含 Humanoid 重定向处理。
- 现有动作来源和演员性别本轮未确认，不能仅凭用户观察或资源名字断言它们全部来自男性。

## 首轮实际测试计划

先取得一个完整片段证明“导出 → 重定向 → 当前人物播放”能通，再扩展成小库。

1. 优先用恋活日常待机或步行完成样本转换；安装目录未知时保留这一步待用户提供。
2. 做独立人物动作预览场景，使用现有 VRM 人物，提供旧动作与新动作同机位切换。
3. 首轮挑选自然待机、另一种日常待机、步行、小跑、转身、坐下、坐姿待机、起身约 8 段；来源覆盖不足时分批测试。
4. 分别保留原地与根运动用途，避免视觉脚步速度和人物移动速度不一致。
5. 检查脚底滑动／穿地、骨盆高度、肩臂姿态、手指、循环接缝，以及衣物／头发 spring bones 与动作的配合。
6. 同一动作在源骨架和目标骨架对照，区分动作本身风格与重定向造成的扭曲。表情单独验证，不假设身体动作附带完整表情。
7. 用户确认风格后再替换默认 Idle／Walk 等，并记录源地址、作者、取得方式、许可证和转换参数。

尚待确定：本机游戏目录／版本、可获取的恋活导出工具版本、实际样本及各商业包的最终用途授权。
本轮只确认候选与测试路径，未声称已下载动作或替换人物动画。
