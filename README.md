# claude-notify

会话等待用户决策时，在 Windows 右下角弹出原生 toast 提示——解决多个 Claude Code 会话并行运行时无法及时发现"哪个会话停下来等你"的问题。

## 功能

- **三类决策等待触发**：权限确认等待、`AskUserQuestion` 提问、`ExitPlanMode` 计划待批
- **原生 Windows toast**：标题为项目目录名，正文为等待原因，来源显示 "Claude Code"
- **常驻不消失**：`scenario="reminder"`，右上角 ✕ 与「忽略」按钮均可单条关闭
- **多会话并行**：多条通知由系统逐条排队；同会话重复事件替换更新而非叠加
- **自动清理**：你在某会话继续输入 / 会话结束 / 决策完成后，该会话的残留提示自动移除
- **去重**：hook 重复触发 2 秒窗口内只弹一次
- 不弹任务完成、不弹 60 秒空闲提醒，避免噪音

## 要求

- Windows 10 或更高版本
- Windows PowerShell 5.1（系统自带）
- 零外部依赖（仅用内置 WinRT / .NET API）

## 安装

```
/plugin marketplace add <your-github-user>/claude-notify-plugin
/plugin install claude-notify@claude-notify-marketplace
```

安装后**重启 Claude Code 会话**即可生效——首次会话启动时会自动注册通知来源（AUMID）并创建一个开始菜单快捷方式（`Claude Code.lnk`，Windows 显示原生 toast 来源名的必要前提；幂等，已存在则跳过）。

## 若弹窗不显示横幅

Windows 的「专注助手/勿扰」开启时会把横幅压进通知中心。到 设置 > 系统 > 通知，确认未拦截，或将 Windows PowerShell 加入优先应用。

## 卸载

```
/plugin uninstall claude-notify@claude-notify-marketplace
```

hooks 随插件卸载自动移除。若想一并清掉 AUMID 与开始菜单快捷方式，卸载前运行一次：

```
powershell -NoProfile -ExecutionPolicy Bypass -File "<插件目录>/scripts/setup-aumid.ps1" -Uninstall
```

## 已知限制

- 无点击跳转：Windows 未打包程序的 toast 点击激活需常驻 COM 激活器，本插件为保持零常驻/零依赖不做跳转，仅提示。切到对应终端窗口时，标题栏含项目名可辅助辨认。
- `reminder` 常驻横幅同屏最多 3 条，其余排队。

## 目录结构

```
claude-notify-plugin/
├── .claude-plugin/
│   ├── plugin.json         插件清单
│   └── marketplace.json    marketplace 定义（source: "./"）
├── hooks/
│   └── hooks.json          6 个 hook（SessionStart 配置 + 触发/清理）
└── scripts/
    ├── _common.ps1         公共库（toast、tag、日志）
    ├── notify-decision.ps1 hook 入口（弹提示 / -Clear 清理）
    └── setup-aumid.ps1     幂等注册 AUMID + 快捷方式（-Uninstall 清理）
```
