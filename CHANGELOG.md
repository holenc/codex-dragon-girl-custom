# GPT龙娘气泡插件更新记录

## 2.0.8 — 2026-11-23

- 修复新版 Codex 通过中间进程启动后台服务时，龙娘无法识别当前会话、显示问号及丢失任务反馈的问题；不受角色与 Codex 是否位于不同屏幕影响。
- 进程识别核对同一 Windows 会话、同一客户端目录和父子创建时间，并限制祖先遍历，排除无关服务。
- 修复周额度耗尽且充值余额归零后未切换闭眼的问题；本地轮询与表情切换不依赖模型调用。
- 修复桌面模式下完成提醒为适配透明窗口边缘而把角色向上推的问题，提醒出现和消失保持桌面位置。
- 验证后台进程识别、美元眼到闭眼再恢复、完成提醒定位与恢复。其他电脑的实际运行仍需更新后确认。

## 2.0.7 — 2026-11-19

- 修复上级工作目录存在 `.git` 时，独立解压的发布版被一律当作源码、无法检查更新的问题。
- 检查器和安装助手使用一致规则：程序目录本身是仓库、程序文件被上级仓库跟踪、或存在明确的源码维护标记时继续保护；上级仓库未跟踪安装目录的发布版可以更新。
- Git 跟踪状态核对仅使用只读索引查询，不修改仓库文件或持久 Git 配置；无法核对时显示保护原因。
- 诊断脚本新增程序仓库、上级仓库和维护标记信息，更新状态增加具体的源码保护原因。
- 已验证 JavaScript 检查器与 PowerShell 安装助手在独立目录、未跟踪发布版、真实源码和无法核对等情况下判断一致。

此前已被旧版源码保护拦截的安装，需要手动完整覆盖本版并运行 `安装GPT娘.cmd` 一次，以同时刷新检查器和稳定安装助手。真正的源码仓库仍应通过 Git 维护或另行安装独立 Release，无需删除 `.git`。

## 2.0.6 — 2026-11-19

- 加固检查更新的启动链路：每次启动更新器前重新核对当前运行时，主动修复旧版 Node/Codex 路径，不因短期缓存跳过检查。
- 增加“正在启动更新器”“正在整理更新文件”和“已有更新正在进行”等状态，避免点击后看不出是否开始。
- 保留更新器返回的具体失败或回滚原因；异常退出时补充退出码及错误信息，不再统一覆盖成笼统提示。找不到可用运行时时明确报错，不静默返回。
- 修正更新测试隔离，使用独立配置、专用任务和无窗口模式；候选包不携带本机安装状态。
- 已通过真实更新器启动验证：模拟 Node 旧目录不存在，自动恢复后读取公开版本并返回最终状态，原设置保持不变。
- 已通过独立环境中的真实安装验证：升级注册新版本、监督进程健康检查、安装失败回滚、更新中断恢复及测试任务清理。

仍保留启动时和每 24 小时检查、安装包校验、空闲安装和失败恢复。旧版本若更新器本身已因运行时路径失效而无法启动，需要先手动完整升级到 2.0.5 或更新版本一次；之后使用新的检查更新链路。网络故障和 GitHub 限流仍可能使检查失败，届时会显示状态和原因，不应把失败当作已更新。

## 2.0.5 — 2026-11-19

- 修复 Codex 或其 Primary Runtime 更新后，旧版本目录失效导致额度、完成提醒和任务/审批监听无法启动，任务角标显示问号的问题。
- 启动挂件、监听器、更新器及 Hook 前核对可执行文件；必要时自动查找当前有效的 Node 24+ 和 Codex 路径，并只更新安装配置中的程序路径。
- 额度 MCP 插件使用稳定的 PowerShell 启动入口，再启动当前有效 Node；二进制转发标准输入/输出，保持 JSON-RPC 握手和工具列表正常。
- 修复“始终置顶”设置与 WPF 窗口属性不一致：同步 WPF Topmost 与原生窗口层级，重新显示或布局变化后保持一致；关闭置顶和切回窗口跟随模式时同步撤销。
- 自动识别当前运行的 Codex；没有运行实例时，选择最新可用安装版本，避免多个安装目录之间连错。
- 修复周额度耗尽、五小时仍有剩余时使用充值额度却不显示美元眼的问题；五小时或周额度任一耗尽且有充值余额时显示美元眼。最近有效的同账户快照可在短暂查询失败期间继续使用，超时或身份未验证时不猜测。
- 保留角色、气泡大小、坐标、语录、额度颜色和已有审批设置，不改变账号、额度或客户端权限。
- 新增运行时目录替换、配置保留、连续升级、窗口隐藏/重新显示及 MCP 启动握手验证。

## 2.0.4 — 2026-11-18

- 新增 Codex 原生审批同步通道，补齐没有进入 PermissionRequest Hook 的浏览器/插件确认。
- 支持在气泡中同意或拒绝无需额外填写字段的原生确认，例如网站下载许可。决定通过客户端原有接口回传，只提交对应请求，不设置“总是允许”。
- 登录、验证码、设备验证、需要填写字段的表单等仍在 Codex 本体处理；气泡提供只读提示，不伪造输入或验证结果。
- 原生审批参与授权优先与时间顺序队列、`+N` 等待计数。你在 Codex 本体处理、取消请求或连接断开时，及时撤销对应气泡/按钮。
- 每次点击先重新核对原生请求编号、所属对话、请求内容和窗口归属；失效、内容改变和重复响应不会批准其他操作。
- 使用独立本地客户端连接，不修改 Codex 程序，不开启远程控制，不调用模型。该接口依赖客户端内部协议，后续版本变化可能需要维护。
- 新增本地协议模拟测试：同意、拒绝、本体处理同步、请求改变竞态、篡改响应和断线撤销。用户已实测浏览器下载审批：点击龙娘同意后任务继续，气泡及等待标记消失。

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

### 2.0.8 — 2026-11-23

- Recognize Codex app servers launched through an intermediate client process, fixing question marks and missing task feedback, including use across separate monitors.
- Validate Windows session, client installation directory and process creation order with bounded ancestry checks to reject unrelated services.
- Close the pet's eyes when weekly quota is exhausted and purchased credits reach zero. Local polling and expression changes do not require model calls.
- Keep desktop placement unchanged when completion reminders appear or disappear, rather than moving the character to fit transparent window padding.
- Verify process identity, credit-depletion expression transitions, and reminder placement/restoration. Actual behavior on other computers still requires confirmation after updating.

### 2.0.7 — 2026-11-19

- Fix portable releases being blocked as source merely because an ancestor workspace contains `.git`.
- Use the same policy in the checker and installer: protect repositories at the program boundary, files tracked by an ancestor repository, and explicit maintenance markers. Allow portable installations untracked by the ancestor workspace.
- Inspect the Git index read-only without changing repository files or persistent Git configuration. Remain protected with a specific reason when inspection is unavailable.
- Add repository-scope details to diagnostics and specific source-protection reasons to update status.
- Verify matching JavaScript and PowerShell decisions for standalone releases, untracked portable installs, tracked source and unavailable inspection.

Installations blocked by the old source guard require one complete manual overlay of this release followed by `安装GPT娘.cmd` to refresh both the checker and stable installer. Actual source repositories remain managed through Git or a separately installed Release; do not remove `.git`.

### 2.0.6 — 2026-11-19

- Harden updater startup by rechecking the current runtime before each launch and repairing obsolete Node/Codex paths without a short-lived cache suppressing recovery.
- Show explicit starting, cleanup and update-in-progress states so a click is no longer visually ambiguous.
- Preserve specific update/rollback errors. Include the exit code and error output after an abnormal exit, and report a missing runtime rather than returning silently.
- Correct test isolation with separate configuration, a dedicated task and headless operation. Exclude local installation state from candidate archives.
- Verify the actual updater can recover from a missing Node directory, read the public release and finish with a terminal status while preserving preferences.
- Verify real isolated installation, version registration, supervisor health, rollback after installer failure, interrupted-update recovery and test-task cleanup.

Startup/daily checks, package verification, idle installation and recovery remain enabled. An older installation whose updater cannot start because its runtime path has disappeared requires one complete manual upgrade to 2.0.5 or later first. Subsequent checks use the hardened startup path. Network failures and GitHub rate limits remain possible and must report a reason rather than masquerading as a successful update.

### 2.0.5 — 2026-11-19

- Recover from versioned executable directories removed after Codex or Primary Runtime updates, which could prevent quota/activity/approval monitors from starting and show an unknown-state badge.
- Check executables before launching the widget, monitors, updater and hook. Rediscover an available Node 24+ and Codex path when necessary, updating only machine-specific executable paths.
- Launch the quota MCP service through a stable PowerShell entry point that selects the available Node runtime. Relay stdin/stdout as bytes to preserve JSON-RPC initialization and tool listing.
- Keep the Always on Top preference consistent with both WPF Topmost and the native window band across show/layout cycles. Disable both when the preference is cleared or window-follow mode is restored.
- Prefer the currently running Codex installation; otherwise select the newest available installed version.
- Show dollar eyes when either the five-hour or weekly allowance is exhausted and purchased credits remain. Retain only a recent verified same-account snapshot across transient query failures; do not infer from expired or unverified data.
- Preserve appearance, position, quotes, quota colors and approval preferences without changing accounts, quota or client permissions.
- Add runtime replacement, configuration preservation, successive-upgrade, hide/show and MCP transport validation.

### 2.0.4 — 2026-11-18

- Add a native Codex approval bridge for browser/plugin confirmations that do not enter the PermissionRequest hook.
- Allow or deny native confirmation forms that require no additional input, such as website download permission. Submit the decision through the client's existing interface for the matching request; do not set an always-allow policy.
- Login, CAPTCHA, device verification and forms requiring field values remain in Codex. The pet provides a read-only notice instead of fabricating input or verification results.
- Include native requests in the approval-first chronological queue and `+N` waiting count. Remove matching prompts/buttons when handled in Codex, cancelled or disconnected.
- Recheck request identity, chat, contents and owning client before each submission. Stale, changed and duplicate responses cannot approve another action.
- Connect as a separate local client without modifying Codex, enabling remote control or calling a model. This integration depends on an internal client protocol and may need maintenance after client updates.
- Add local protocol tests for allow, deny, native resolution, changed-request races, tampered responses and disconnect cleanup. A real browser download approval was confirmed interactively: clicking Allow in the pet resumed the task and cleared the bubble and waiting indicator.

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
