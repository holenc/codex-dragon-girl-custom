# GPT龙娘气泡插件更新记录

## 2.0.3 — 2026-11-17

- 修复恢复或导入的对话正在工作，但龙娘漏算运行数量的问题。部分对话的新轮次会写入日志，状态数据库却仍停留在旧轮次。
- 同时核对数据库与当前会话日志，以任务开始、完成、取消和整轮失败记录补齐状态；按对话去重，不把历史轮次重复计数。
- 修复数据库挑选最新轮次时过度依赖日志序号的问题，优先使用轮次开始时间。
- 保留单任务 `......`、多任务 `2......`、最大 99 的显示规则，以及授权/等待优先级。
- 新增数据库漏记、完成撤销、取消撤销、迟到的旧轮次事件及重启恢复测试。只读实测已同时识别两条实际运行中的对话，运行数为 2。

本版保留 2.0.2 的启停同步、每日更新检查和兼容旧更新器的下载布局。

## 2.0.2 — 2026-11-17

- 改进 Codex 启停同步：进程启动通知、进程句柄退出通知与兜底核对配合，避免每轮重复进行较慢的进程查询。
- 移除彻底退出后的固定 3 秒等待；桌面模式直接显示，不再等待 Codex 界面就绪检测。点 X 到后台、最小化仍保留龙娘。
- 修复旧更新器将 `tools` 与发行说明误判为个人文件的冲突。下载包采用兼容旧更新器的布局，升级过程中替换稳定启动器。
- 自动更新源直接使用本仓库，启动时检查一次，持续运行期间每 24 小时再检查一次。保留手动检查及 GitHub 限流退避。
- 名称统一为“GPT龙娘气泡插件”，版本菜单隐藏内部构建标识。原项目仓库、视频及许可继续保留在说明中。
- 新增进程生命周期、每日检查时间边界和发行包升级回归测试。

升级后请在菜单中确认版本为 **2.0.2**。从 2.0.0 / 2.0.1 可先尝试菜单中的“检查更新”。若旧状态阻止升级，可退出龙娘，将下载包完整覆盖到原目录，再运行 `安装GPT娘.cmd`；保留 `installation.json` 和个人数据，不要先卸载或删除设置。

测试使用隔离进程验证启动/退出通知、退出检测、恢复与保留设置；没有为测试而关闭正在使用的 Codex。实际显示时间还包含 PowerShell/WPF 初始化，其他电脑的端到端延迟需实机确认。

## 2.0.1 — 2026-11-17

- 修复关闭到后台后，双击龙娘唤出 Codex 可能卡住、无法点击的问题。
- 隐藏窗口改走客户端的正常应用激活入口，不再用 ShowWindowAsync 强行显示；普通最小化继续正常恢复。
- 动态读取运行中客户端的应用标识，避免硬编码安装版本；补充唤醒分支测试和诊断状态。
- 已由用户实际验证关闭到后台后可正常唤出并操作。


## 2.0.0 — 2026-11-16

基于 T7moris/GPT-Niang v1.3.6 发布非商业维护版本。完整出处与逐条改动见 [README](README.md)。

- 新增充值 credits 与美元估算、绿/红额度状态颜色。
- 新增流口水、旧版闭眼及带高光的简化美元眼，按额度和任务失败状态切换。
- 新增运行数量和等待数量，支持重启恢复、旧轮次去重、异常状态降级。
- 将授权和提问嵌入原气泡，授权优先、各自按时间排队，校验单次决定并跟随回执清理。
- 延长授权等待；过期后只保留只读提示，不接受旧按钮授权。
- 新增所有自动任务启动时显示最新对话标题、完成双行提示。
- 新增双击恢复后台 Codex，随 Codex 启停，修复多余控制台窗口。
- 移除长悬浮说明，微调气泡和右侧龙角旁的紫色角标。
- 更新源改为 holenc/codex-dragon-girl-custom，停止从上游仓库覆盖更新。
- 补齐脱敏发布、Node.js 24 检测、新设备默认设置和原作署名说明。


## English

### 2.0.3 — 2026-11-17

- Fix missing running-chat counts for resumed/imported conversations whose current turns exist in rollout logs but are absent from the history database.
- Reconcile database rows with lifecycle log events for task start, completion, cancellation and whole-turn failure. Count each chat once and exclude historical turns.
- Select database turns by start time before using rollout ordinal as a tie-breaker.
- Preserve `......` for one running chat, `2......` for multiple chats, the 99 cap and existing approval/wait priorities.
- Add regression coverage for missing index entries, completion, cancellation, late old-turn events and restart recovery. Read-only verification of the two active chats returned a running count of 2.

Includes the lifecycle synchronization, daily update checks and legacy-compatible download layout from 2.0.2.

### 2.0.2 — 2026-11-17

- Improve Codex lifecycle synchronization with process-start notifications, retained process-handle exit notifications and fallback reconciliation, avoiding repeated slow process queries on every tick.
- Remove the fixed three-second exit delay. Desktop mode displays without waiting for Codex interface-readiness probes. The pet remains while Codex is minimized or closed to the background.
- Fix shipped tools and documentation being mistaken for personal files. The download layout remains compatible with the old updater and refreshes the stable launcher during installation.
- Use this repository directly for automatic updates: check at startup and every 24 hours while running. Manual checks and GitHub rate-limit backoff remain available.
- Use the name “GPT Dragon Girl Bubble Plugin” and hide internal build identifiers in the version menu. Original project, video and license links remain in the documentation.
- Add lifecycle, daily-schedule boundary and release-upgrade regression tests.

Confirm **2.0.2** in the menu after upgrading. Users on 2.0.0 / 2.0.1 can try “Check for updates” first. If an old update state blocks installation, exit the pet, extract the complete download over the original directory and run `安装GPT娘.cmd`. Keep `installation.json` and personal data; do not uninstall or delete preferences first.

Isolated processes test notifications, exit detection, recovery and preference preservation without closing the active Codex client. Visible startup still includes PowerShell/WPF initialization; end-to-end latency on other computers needs local confirmation.

### 2.0.1 — 2026-11-17

- Fixed a potentially non-interactive Codex window when double-clicking the pet after closing Codex to the background.
- Hidden windows now use normal application activation instead of a raw Win32 show call; ordinary minimized-window restore is preserved.
- Read the running client's application identity dynamically and added activation-route regression tests and diagnostics.
- The user confirmed the background-close / double-click / interact flow works on the maintainer's computer.


### 2.0.0 — 2026-11-16

Initial custom fork based on upstream v1.3.6. Added purchased-credit/USD display, quota and failure expressions, running/waiting counters, embedded approval queues, restart recovery, scheduled-task title notifications, windowless startup, and independent startup-only updates. Original repository, Bilibili video, contributor credits and license notices are preserved. See README for the itemized bilingual comparison and current limitations.
