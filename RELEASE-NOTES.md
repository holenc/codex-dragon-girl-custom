# GPT龙娘气泡插件

## 2.0.6 — 2026-11-19

- 加固检查更新的启动链路：每次启动更新器前重新核对当前运行时，主动修复旧版 Node/Codex 路径，不因短期缓存跳过检查。
- 增加“正在启动更新器”“正在整理更新文件”和“已有更新正在进行”等状态，避免点击后看不出是否开始。
- 保留更新器返回的具体失败或回滚原因；异常退出时补充退出码及错误信息，不再统一覆盖成笼统提示。找不到可用运行时时明确报错，不静默返回。
- 修正更新测试隔离，使用独立配置、专用任务和无窗口模式；候选包不携带本机安装状态。
- 已通过真实更新器启动验证：模拟 Node 旧目录不存在，自动恢复后读取公开版本并返回最终状态，原设置保持不变。
- 已通过独立环境中的真实安装验证：升级注册新版本、监督进程健康检查、安装失败回滚、更新中断恢复及测试任务清理。

仍保留启动时和每 24 小时检查、安装包校验、空闲安装和失败恢复。旧版本若更新器本身已因运行时路径失效而无法启动，需要先手动完整升级到 2.0.5 或更新版本一次；之后使用新的检查更新链路。网络故障和 GitHub 限流仍可能使检查失败，届时会显示状态和原因，不应把失败当作已更新。

## English

### 2.0.6 — 2026-11-19

- Harden updater startup by rechecking the current runtime before each launch and repairing obsolete Node/Codex paths without a short-lived cache suppressing recovery.
- Show explicit starting, cleanup and update-in-progress states so a click is no longer visually ambiguous.
- Preserve specific update/rollback errors. Include the exit code and error output after an abnormal exit, and report a missing runtime rather than returning silently.
- Correct test isolation with separate configuration, a dedicated task and headless operation. Exclude local installation state from candidate archives.
- Verify the actual updater can recover from a missing Node directory, read the public release and finish with a terminal status while preserving preferences.
- Verify real isolated installation, version registration, supervisor health, rollback after installer failure, interrupted-update recovery and test-task cleanup.

Startup/daily checks, package verification, idle installation and recovery remain enabled. An older installation whose updater cannot start because its runtime path has disappeared requires one complete manual upgrade to 2.0.5 or later first. Subsequent checks use the hardened startup path. Network failures and GitHub rate limits remain possible and must report a reason rather than masquerading as a successful update.
