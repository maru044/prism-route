# Rhino MCP 启动按钮

配置日期：2026-10-11。

## 使用

Rhino 8 顶部【标准】工具栏右侧、问号按钮后面已添加文字按钮 **MCP**。
左键单击启动已安装的 `rhino-gh-mcp` 服务；已运行时显示提示并保持运行。
右键没有绑定指令。

服务地址：`127.0.0.1:9876`。当前安装插件版本：`rhinogh-mcp-rhino 0.1.1`。

## 实现

按钮宏名称为“启动 MCP”，执行：

```text
! _-RunPythonScript "D:\Prism Route\prism-route\tools\rhino\start_mcp.py"
```

`tools/rhino/start_mcp.py` 兼容 Rhino 的 IronPython 2.7。
先通过 .NET 的 TCP 监听列表检查端口，没有监听时执行 `_ToggleMcpService`。
检查过程不创建空的客户端连接，避免插件输出连接读取错误。
此检查假定 9876 端口由当前 Rhino MCP 插件独占；端口监听状态不等于完整协议健康检查。

如果移动项目目录，需要相应更新按钮宏中的脚本路径。

## 配置与备份

按钮加入 Rhino 当前默认 RUI 的 Standard 工具栏，显示方式为仅文字。
已通过 Rhino 的工具栏配置接口刷新当前工具栏并写入配置。
本机配置文件：

```text
C:\Users\PC\AppData\Roaming\McNeel\Rhinoceros\8.0\settings\Scheme__Default\Rhino.UI.Resources.rui.default_c7da84fc-2991-4824-832a-4f2509bd0ede.xml
```

修改前的工具栏配置备份保存在：

```text
D:\Prism Route\tmp\rhino_toolbar_backup_2026-10-11
```

重建按钮时，可以运行 `Toolbar`，选取【标准】工具栏，点击新增；设置以上名称和宏，按钮文本填写 `MCP`，显示方式选“仅文本”。
本机完整工具栏配置没有纳入项目 Git。

## 实机验证

- 在服务运行时点击 MCP，输出 `MCP is already running on 127.0.0.1:9876.`，保持服务运行。
- 执行 `_ToggleMcpService` 停止服务后，系统监听列表确认 9876 没有监听。
- 点击 MCP，输出服务启动以及 `MCP is ready on 127.0.0.1:9876.`。
- 随后通过 Rhino MCP 成功读取当前 `map.3dm` 场景，确认协议连接恢复。
- 磁盘配置 XML 包含新按钮、宏与完整脚本路径。

测试结束时 MCP 保持运行。未重启 Rhino 验证启动后界面；当前运行界面和磁盘配置均已检查。
