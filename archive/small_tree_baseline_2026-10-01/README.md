# 旧版小树与接受前的对照归档

日期：2026-10-01。用户确认连续树冠受光版本明显更好，要求新版作为
正式基准、旧版归档。本目录由 `.gdignore` 排除，不进入 Godot 资源导入。

## 内容

- `screenshots/vegetation_art_site_*_baseline.png` 与
  `vegetation_art_metrics.json`：旧版四处观景记录。
- `screenshots/foliage_filtering_*`：接受新版前的原版 / 新版配对图和指标。
- `tools/`：旧 A/B 截图及汇总工具。
- `comparison_snapshot/`：`9f6ff16` 中配套的材质配置、shader、场景脚本、
  mip 构建工具和六组 mip 元数据。
- `assets/vegetation/textures/filtered_lod/*_raw.res`：普通 mip 的诊断资源。

## 复现与恢复

原版未修改运行时的基线提交是 `f75fc7f`；包含完整 A/B 功能和依赖的
实验提交是 `9f6ff16`。若需要复现，请在独立 checkout / worktree 检出
相应提交，避免用单个归档脚本覆盖当前工程。快照仅供比较，不是独立工程。

当前入口 `scenes/main.tscn`、四处观景审阅和专用树林固定使用新版。
原始 PNG、GLB 及生成器仍作为新版的源数据或其他树的共享依赖保留，
不代表旧版仍可从入口切换。新绘制纹理的被否决尝试属于另外的
`archive/painted_foliage_trials_2026-10-01/` 归档。
