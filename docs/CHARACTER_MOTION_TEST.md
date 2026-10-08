# 人物动作测试场景

日期：2026-10-08。Godot 4.7.2 / Forward+ / Windows D3D12。

## 打开

在 Godot 打开 `scenes/character_motion_test.tscn`，按 **F6** 运行当前场景。
也可以从项目目录运行：

```powershell
& 'D:\Godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --path . res://scenes/character_motion_test.tscn
```

场景使用现有甘雨 VRM，载入下载清单中全部 **42 段**普通人物动作。
它独立于主场景、角色控制器和现有动作库；主游戏入口没有修改。
清单编号 A01–A42 与 `MOTION_DOWNLOAD_CHECKLIST.md` 一致。

## 操作

- 点击列表播放；搜索编号、中文或原始动作名，也可按分类筛选。
- 左右方向键 / 上一段、下一段：在当前筛选结果中切换。
- 空格：暂停 / 继续；R：重播；拖进度条检查某一帧。
- 速度范围 0.1–2.0 倍；可关闭循环查看一次性过渡动作。
- 右键拖动旋转相机，滚轮缩放；恢复视角按钮返回初始视角。
- 原地观察保留高度、转向和四肢运动。普通动作抵消骨盆水平位移；
  A05 / A39 原文件已是原地步行，采用固定的周期平均位置对齐，保留身体平衡所需的骨盆侧移。
  关闭它可观察原始水平位移；长距离动作可能走出镜头。
- “对比步行修正前版本”可切换 A05 / A39 的原转换结果与新结果。
  其他动作不受该开关影响。建议先检查修正后的 A05；A39 可设为约 0.65 倍速。
- 角色高度偏移是手动观察辅助，默认 0；它不代表 IK 或地面适配完成。
- 可显示参考椅；默认座面高度约 0.38 m，Y/Z 输入调整整把椅子的位移。
- 头发 / 服饰物理默认关闭以便检查骨架；开启后可检查衣物和发丝响应。
  大幅换姿势可能使弹簧模拟短暂抖动。

## 已验证与待筛选

已在 Godot 检查全部 42 个资源：关键帧非空、轨道节点与骨骼路径有效，
每段在 5 个时间位置的全部骨骼变换为有限值。另检查搜索、筛选后切换、
暂停、重播、拖动进度、关闭循环，以及 VRMA 与 GLB 之间切换。

Forward+ 实机截图覆盖 A01、A05、A06、A16、A22、A30、A33、A37、A39、A41、A42。
截图分别是 `screenshots/character_motion_test.png` 和
`screenshots/character_motion_contact_sheet.png`。截图只覆盖这些代表片段的单帧，
不代表所有片段的全程美术验收。

初步观察：站立、女性步行/跑步、坐姿和 VRMA 日常动作能驱动当前模型，
没有出现整个身体翻转或爆炸式拉伸；已修正 Godot motion_scale 二次缩放导致的陷地。
坐姿、跪姿和地面动作的接触位置仍受人体比例影响，可能浮空或穿插。
冥想姿势的腿部/服饰、俯卧撑的头发与袖口尤其需要进一步检查。

待用户评审：动作气质、脚滑、脚掌角度、手指姿势、服饰穿插，以及进入/退出片段
能否衔接。建议先看 A01–A06 和 A37–A40，再看坐姿 A21–A24。

当前只用于候选动作筛选：没有脚部 IK、碰撞、动作状态机、过渡混合或道具绑定。
手机/杯子没有实物道具；VRMA 表情节点、眼球和口型未转换，当前测试身体与手指动作。
转身、跳跃、坐下/起身等短片段循环可能有接缝，应关闭循环查看。
下腰、纵叉、横叉及额外进入/退出动作仍不在这 42 段中。

## 转换与重建

原始文件在 `assets/characters/motion_sources/independent_cc0/`，保持下载哈希，
使用 `.gdignore` 避免自动导入。来源及 CC0 声明见该目录 README 和下载回执。
派生资源在 `assets/characters/motion_review/`，只适用于当前人物绑定骨架。

转换步骤：

1. `tools/inspect_motion_skeleton.gd` 导出当前 VRM 的绑定骨架到 `.godot/motion_target_rest.json`。
2. `tools/build_motion_review.py` 读取 GLB 的逆绑定矩阵，或 VRMA 的 humanoid 节点映射，
   按绑定姿势计算世界空间旋转变化，再还原到目标局部骨骼；保留目标骨长。
3. 骨盆位移按目标/来源绑定骨盆高度比例缩放，以约 30 Hz 烘焙为 Godot Animation。
   场景将目标 `Skeleton3D.motion_scale` 设为 1，避免已经转换的米制位置再被缩放。
4. `tools/verify_motion_review.gd` 检查资源、骨骼与场景控制；
   `tools/capture_motion_review.gd` 生成代表画面。

```powershell
& 'D:\Godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tools/inspect_motion_skeleton.gd
python tools/build_motion_review.py
& 'D:\Godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tools/verify_motion_review.gd
& 'D:\Godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --path . --script tools/capture_motion_review.gd
```

Python 构建工具需要 numpy；运行测试场景不需要 Python 或 Blender。
构建工具对非 LINEAR/STEP 插值、稀疏或非浮点访问器会明确停止。
换人物或改骨架后需要重新导出和转换，不能直接把这些资源当通用人体动作库使用。

## 步行横移修正（2026-10-08）

用户已检查其余动作，本阶段不需要 IK。当前针对 A05 / A39 修正横向位移。

原因有两项：

1. 旧原地观察逐帧固定 Hips 的 X/Z，删掉了步行中用于抵消躯干反向摆动的骨盆侧移。
   A05 原来源的头部横向幅度约 2.8 cm，转换后再这样固定骨盆却达到约 21 cm。
2. 当前 MMD 转来的 VRM，其 Hips 枢轴比左右大腿根部的中点低约 24 cm。
   来源骨架的对应偏移小得多。直接围绕这个目标枢轴搬运旋转会扩大整个人的横移。

新转换在水平方向按两侧大腿根部中点校准比例与枢轴偏移，保留原有竖直位移、骨骼旋转、
骨长和手指动作；场景用固定周期平均位置观察这两段已经原地化的步行，保留自然平衡侧移。
仅 A05 / A39 的位置轨道修改；跑步和其他动作资源没有修改，也没有加入 IK。

完整周期采样 121 个时间点，统计最终世界坐标 X 的峰峰幅度：

| 动作 | 测量骨骼 | 修正前 | 修正后 |
| --- | --- | --- | --- |
| A05 女性步行 | Head | 21.07 cm | 2.32 cm |
| A05 女性步行 | Chest | 19.07 cm | 0.37 cm |
| A05 女性步行 | 左 / 右脚 | 19.14 / 19.94 cm | 3.98 / 3.28 cm |
| A39 替代步行 | Head | 5.69 cm | 5.27 cm |
| A39 替代步行 | Chest | 6.99 cm | 3.87 cm |
| A39 替代步行 | 左 / 右脚 | 15.12 / 17.34 cm | 5.11 / 7.45 cm |

这里测量的是骨骼标记的横向变化，不是滑步距离或地面接触误差。
A39 原来源头部本身有约 6 cm 的自然横摆，修正后仍保留这一动作特征；减速只改变节奏，
不会改变横摆幅度。若希望更稳定的步行，当前优先复查修正后的 A05。
A06 / A40 跑步的修正前后测量结果完全一致；全部 42 段的骨骼/关键帧检查仍通过。

修正前的两个转换资源归档在 `assets/characters/motion_review/archive/`，
对应提交 `f861259`。下载的 GLB / VRMA 原文件不变。

动态对比（左旧右新）：

- `screenshots/walk_a05_comparison.gif`：正常速度。
- `screenshots/walk_a39_comparison.gif`：双方同为 0.65 倍速。
- `screenshots/walk_a05_phases.png`、`screenshots/walk_a39_phases.png`：
  四个周期相位，上旧下新；背景竖线是固定世界位置。
- `docs/WALK_STABILITY_REPORT.json`：Godot 实测数值。

验证和重新生成对比：

```powershell
& 'D:\Godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tools/verify_walk_stability.gd
& 'D:\Godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --path . --script tools/capture_walk_comparison.gd
python tools/encode_walk_comparison.py
```

GIF 编码工具需要 Pillow。运行场景时在参数末尾添加 `-- --motion=A05` 可直接进入女性步行。
