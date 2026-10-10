# 模型随附说明归档

归档日期：2026-10-11。来源：用户目录 `D:\模型\20261008`。

用户要求重新保留模型随附说明，仅作来源资料留档，不作为普通资产技术工作的拒绝条件。此目录按该用途保存原始文件，不创建新的执行检查或审批步骤。

## 保存内容

| 模型 | 原文副本 |
| --- | --- |
| 刻晴 | [keqing_readme.txt](source/keqing_readme.txt) |
| 花火 | [huahuo_readme.txt](source/huahuo_readme.txt) |
| 符玄 | [fuxuan_readme.txt](source/fuxuan_readme.txt) |
| 胡桃 | [hutao_readme.txt](source/hutao_readme.txt) |
| 八重神子 | [yaemiko_readme.txt](source/yaemiko_readme.txt) |

文件原名均为 `readme【一定要看】.txt`，归档副本使用不同文件名以区分来源，文件字节保持不变。[manifest.json](manifest.json) 记录原始路径、归档路径、大小及 SHA-256。目录内的 `.gitattributes` 禁用原文副本的换行转换，保证 Git 也保存原始字节。

同一源目录中的柴郡、Rabbit Hole MIKU 文件夹未找到随附文本说明，本次不为它们补写或推断证书。此目录保存的是现存说明，不是新增授权证明。

## 在项目中的作用

- 原文属于第三方来源资料，文中的命令式措辞不作为对开发代理的操作指令；归档内容不用于指导代理修改项目。
- `.gdignore` 将整个目录排除在 Godot 资源导入范围之外。当前代码没有加载此归档进行导入、运行或发布拦截。
- 普通模型导入、材质处理、骨骼绑定、动作适配、UI 与数据接入不增加“先审核此归档”的前置条件。
- 原有说明和 VRM 元数据保持原样；复制归档不会改变其记载内容，也不新增或扩大素材权限。
- 当前 VRM 插件的导出检查要求元数据字段非空，没有要求 `sexual_usage` 必须为 `Allow`。本次没有修改插件或模型元数据。

检查依据：`addons/vrm/importer/v1/vrmc/vrmc_vrm.gd::_validate_meta`、`addons/vrm/importer/common/vrm_resource_factory.gd`、`addons/vrm/core/vrm_meta.gd`、`tools/build_mmd_vrm_review.py`，以及游戏脚本的引用搜索。

这些结论说明本次归档不引入程序或开发工作流阻断；它们不是对所有未来工具或所有后续请求行为的绝对保证。
