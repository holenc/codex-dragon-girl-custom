# GPT龙娘气泡插件

## 2.0.5 — 2026-11-19

- 修复 Codex 或其 Primary Runtime 更新后，旧版本目录失效导致额度、完成提醒和任务/审批监听无法启动，任务角标显示问号的问题。
- 启动挂件、监听器、更新器及 Hook 前核对可执行文件；必要时自动查找当前有效的 Node 24+ 和 Codex 路径，并只更新安装配置中的程序路径。
- 额度 MCP 插件使用稳定的 PowerShell 启动入口，再启动当前有效 Node；二进制转发标准输入/输出，保持 JSON-RPC 握手和工具列表正常。
- 修复“始终置顶”设置与 WPF 窗口属性不一致：同步 WPF Topmost 与原生窗口层级，重新显示或布局变化后保持一致；关闭置顶和切回窗口跟随模式时同步撤销。
- 自动识别当前运行的 Codex；没有运行实例时，选择最新可用安装版本，避免多个安装目录之间连错。
- 修复周额度耗尽、五小时仍有剩余时使用充值额度却不显示美元眼的问题；五小时或周额度任一耗尽且有充值余额时显示美元眼。最近有效的同账户快照可在短暂查询失败期间继续使用，超时或身份未验证时不猜测。
- 保留角色、气泡大小、坐标、语录、额度颜色和已有审批设置，不改变账号、额度或客户端权限。
- 新增运行时目录替换、配置保留、连续升级、窗口隐藏/重新显示及 MCP 启动握手验证。

## English

### 2.0.5 — 2026-11-19

- Recover from versioned executable directories removed after Codex or Primary Runtime updates, which could prevent quota/activity/approval monitors from starting and show an unknown-state badge.
- Check executables before launching the widget, monitors, updater and hook. Rediscover an available Node 24+ and Codex path when necessary, updating only machine-specific executable paths.
- Launch the quota MCP service through a stable PowerShell entry point that selects the available Node runtime. Relay stdin/stdout as bytes to preserve JSON-RPC initialization and tool listing.
- Keep the Always on Top preference consistent with both WPF Topmost and the native window band across show/layout cycles. Disable both when the preference is cleared or window-follow mode is restored.
- Prefer the currently running Codex installation; otherwise select the newest available installed version.
- Show dollar eyes when either the five-hour or weekly allowance is exhausted and purchased credits remain. Retain only a recent verified same-account snapshot across transient query failures; do not infer from expired or unverified data.
- Preserve appearance, position, quotes, quota colors and approval preferences without changing accounts, quota or client permissions.
- Add runtime replacement, configuration preservation, successive-upgrade, hide/show and MCP transport validation.
