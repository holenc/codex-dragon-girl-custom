# GPT龙娘气泡插件

## 2.0.2 — 2026-11-17

- 改进 Codex 启停同步：进程启动通知、进程句柄退出通知与兜底核对配合，避免每轮重复进行较慢的进程查询。
- 移除彻底退出后的固定 3 秒等待；桌面模式直接显示，不再等待 Codex 界面就绪检测。点 X 到后台、最小化仍保留龙娘。
- 修复旧更新器将 `tools` 与发行说明误判为个人文件的冲突。下载包采用兼容旧更新器的布局，升级过程中替换稳定启动器。
- 自动更新源直接使用本仓库，启动时检查一次，持续运行期间每 24 小时再检查一次。保留手动检查及 GitHub 限流退避。
- 名称统一为“GPT龙娘气泡插件”，版本菜单隐藏内部构建标识。原项目仓库、视频及许可继续保留在说明中。
- 新增进程生命周期、每日检查时间边界和发行包升级回归测试。

升级后请在菜单中确认版本为 **2.0.2**。从 2.0.0 / 2.0.1 可先尝试菜单中的“检查更新”。若旧状态阻止升级，可退出龙娘，将下载包完整覆盖到原目录，再运行 `安装GPT娘.cmd`；保留 `installation.json` 和个人数据，不要先卸载或删除设置。

测试使用隔离进程验证启动/退出通知、退出检测、恢复与保留设置；没有为测试而关闭正在使用的 Codex。实际显示时间还包含 PowerShell/WPF 初始化，其他电脑的端到端延迟需实机确认。

## English

### 2.0.2 — 2026-11-17

- Improve Codex lifecycle synchronization with process-start notifications, retained process-handle exit notifications and fallback reconciliation, avoiding repeated slow process queries on every tick.
- Remove the fixed three-second exit delay. Desktop mode displays without waiting for Codex interface-readiness probes. The pet remains while Codex is minimized or closed to the background.
- Fix shipped tools and documentation being mistaken for personal files. The download layout remains compatible with the old updater and refreshes the stable launcher during installation.
- Use this repository directly for automatic updates: check at startup and every 24 hours while running. Manual checks and GitHub rate-limit backoff remain available.
- Use the name “GPT Dragon Girl Bubble Plugin” and hide internal build identifiers in the version menu. Original project, video and license links remain in the documentation.
- Add lifecycle, daily-schedule boundary and release-upgrade regression tests.

Confirm **2.0.2** in the menu after upgrading. Users on 2.0.0 / 2.0.1 can try “Check for updates” first. If an old update state blocks installation, exit the pet, extract the complete download over the original directory and run `安装GPT娘.cmd`. Keep `installation.json` and personal data; do not uninstall or delete preferences first.

Isolated processes test notifications, exit detection, recovery and preference preservation without closing the active Codex client. Visible startup still includes PowerShell/WPF initialization; end-to-end latency on other computers needs local confirmation.
