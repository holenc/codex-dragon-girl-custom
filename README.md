# GPT龙娘气泡插件

**v2.0.7 · Windows 桌面额度、任务状态与授权气泡。仅供非商业使用。**

## 原作出处与致谢

- 原项目：[T7moris/GPT-Niang](https://github.com/T7moris/GPT-Niang)
- 原项目下载：[原版 Releases](https://github.com/T7moris/GPT-Niang/releases)
- 原 B 站视频：[GPT龙娘气泡插件 · BV1Kga666EyT](https://www.bilibili.com/video/BV1Kga666EyT/)
- 原作者及贡献者的完整说明：[原项目 README](UPSTREAM-README.md)、[原项目更新记录](UPSTREAM-CHANGELOG.md)。

感谢 T7moris 及原项目贡献者提供的挂件、角色基础素材、额度读取、语录、图库、音效和更新框架。本分支保留原作署名与许可；下方列出本项目的后续改动，不将原有功能列为原创。其他仓库曾作为方案比较参考，不代表本分支合并了其中的代码。

## 2.0.7 更新

修复上级 Git 工作区误挡独立发布版更新。程序本身的仓库、被跟踪的程序文件及明确维护源码仍受保护。被旧版规则拦截时，须手动完整覆盖本版并运行安装脚本一次，刷新检查器与稳定安装助手。

## 2.0.6 更新

加固更新器启动、路径恢复及错误反馈。已在独立无窗口环境验证实际升级、失败回滚和中断恢复；启动器旧路径失效时会重新识别可用运行时。已坏到无法启动更新器的旧安装需先手动完整升级到 2.0.5 或以上一次，之后使用新的更新链路。

## 2.0.5 更新

修复客户端/运行时升级后程序路径失效引起的问号及监听器停止。自动重新定位 Node 与 Codex，额度插件通过稳定入口启动；始终置顶同时同步 WPF 属性和窗口层级。自动选择当前运行的 Codex 或最新可用安装。五小时或周额度耗尽且有充值余额时切换美元眼；外观和已有设置保留。

## 2.0.4 更新

新增原生浏览器/插件审批通道。无需填写字段的确认可在气泡中同意或拒绝，处理后同步撤销提示；点击前重新核对请求身份与内容。网站下载审批已由用户实测。登录、验证码、设备验证和需要填值的表单仍在 Codex 本体处理。此集成依赖本机客户端内部窗口协议，版本变化可能需要维护。

## 2.0.3 更新

修复部分恢复/导入对话正在运行却不显示运行标记的问题：同时核对当前日志与数据库，补齐未入库的任务开始、完成和取消状态；两个对话同时工作时显示 `2......`。详细记录见 [CHANGELOG](CHANGELOG.md)。

## 2.0.2 更新

- 改进随 Codex 启停的响应：监听进程启动/退出，保留进程句柄核对退出状态，减少反复查询；事件不可用时自动回退核对。
- 取消彻底退出后的固定 3 秒等待。桌面模式不再等待 Codex 界面加载检测；窗口跟随模式保留界面就绪检查。
- 点 X 关闭到后台、普通最小化仍保留龙娘；彻底退出 Codex 才关闭龙娘。
- 修复更新器把发行包自带的 `tools` 和说明文件误当作个人文件，阻止升级的问题。
- 自动更新使用本仓库：启动时检查一次，持续运行期间每 24 小时再检查一次；保留手动检查与限流退避。
- 版本菜单和更新提示简化名称，隐藏内部构建标识。

**从 2.0.0 / 2.0.1 升级：**本版下载包采用兼容旧更新器的目录布局，可在龙娘菜单中检查更新。更新后确认显示 **2.0.7**。若此前失败留下异常状态，可退出龙娘，将本版完整覆盖到原安装目录后运行 `安装GPT娘.cmd`；保留 `installation.json` 与个人数据，不要先卸载或删除配置。

## 下载与安装

本项目仓库：[holenc/codex-dragon-girl-custom](https://github.com/holenc/codex-dragon-girl-custom)

1. 从[本项目 Releases](https://github.com/holenc/codex-dragon-girl-custom/releases/latest)下载 `gpt-niang-usage-widget-v2.0.7-windows.zip` 与 `SHA256SUMS.txt`，核对校验值。
2. 完整解压到长期保留的普通目录，双击 `安装GPT娘.cmd`。请先安装并登录 Codex 桌面客户端。需要 Node.js 24+；安装器优先使用已有 Node，或检测 Codex Primary Runtime 自带的 Node。
3. 安装器在这台电脑重新生成程序路径、插件注册和启动配置；已有个人设置会保留，新安装使用默认设置。安装包不包含作者的账户、聊天、授权记录或桌面坐标。
4. 如使用授权气泡，请在 Codex 的 Hooks 页面检查并信任 GPT Niang 的 PermissionRequest Hook。不会替用户修改信任记录，也不会自动同意任何操作。

只支持 Windows 本地 Codex 会话。当前任务状态读取适配了 Codex 桌面客户端 26.1111.2228.0 的本机日志与状态数据库；客户端结构变化时可能需要跟进维护。普通 ChatGPT 网页对话没有接入。

## 相比原版新增或调整的内容

1. **随 Codex 启停。** 打开 Codex 出现龙娘；关闭到后台、最小化时仍保留，彻底退出 Codex 后收起。
2. **双击唤出 Codex。** 单击仍看额度，双击恢复最小化或关闭到后台的 Codex 主窗口。
3. **增加充值余额第三行。** 左侧显示官方接口返回的剩余 credits，右侧显示美元估算。默认按 `500 credits = 20 美元` 换算；这是参考值，不是账单或退款金额。
4. **额度颜色更易识别。** 正常进度条和百分比为绿色，剩余不超过 25% 时为红色；保留原警戒阈值。
5. **额度表情切换。** 普通情况保留原图；五小时耗尽且无充值余额时流口水；同时周剩余低于 5% 时闭眼；五小时或周额度耗尽但仍有充值余额时使用保留高光的简化美元眼。
6. **失败表情优先。** 明确的整轮任务失败优先显示流口水，处理后恢复额度对应表情。正常取消、单次工具失败后继续重试不触发此状态。
7. **运行数量标记。** 龙角凹口旁显示紫色 `......`；多对话同时工作显示 `3......` 等，数字最大显示 99。按对话计数，不按工具调用计数。
8. **等待数量标记。** 上一行显示紫色 `+1`、`+2`。等待与正常运行分开显示；异步提问时对话可能仍在继续工作。
9. **授权和提问气泡。** 提示嵌入原气泡；授权优先，授权内部和普通提问内部各按出现时间排队。
10. **一次性授权按钮。** 有效的 PermissionRequest 请求可在气泡中同意或拒绝本次操作；校验请求身份和有效性。没有有效回传通道的提示只提供打开 Codex，普通文字回答仍在 Codex 内完成。
11. **延长等待并跟随请求状态。** Hook 执行上限延至约 24 小时，超过后交回原生流程并保留只读镜像；不会保留可提交过期决定的按钮。根据请求回执、后续用户输入、取消和回合状态清理提示。部分网页原生登录或特殊界面提示仍需在 Codex 本体处理。
12. **重启恢复与去重。** 从每个对话最新一轮状态恢复计数，过滤子代理和旧进程记录，不靠只增不减的计数器。状态源异常时显示 `?`，不把未知状态假装成零。
13. **所有定时任务启动提醒。** 循环任务和一次性倒计时触发时，读取对应对话的最新标题显示提示，不固定绑定某一个任务。
14. **完成提示定制。** 同一气泡两行显示“已严肃回复”和“ᗜˬᗜ”。
15. **启动与界面细节。** 使用无窗口启动入口，移除角色上的长操作说明悬浮提示；调整额度排版、角标字号与位置。默认静音，关闭自动闲聊，人物与气泡分别缩放。
16. **独立更新源。** 自动更新直接使用本仓库的正式 Release，原作者仓库与视频链接保留在出处说明中。

## 自动更新与版本规则

- 更新源为本仓库，启动时检查一次，持续运行期间每隔 24 小时再检查一次。可手动检查；GitHub 限流时退避，不是秒级推送。
- 发布更新必须提高版本号，并在对应 Release 上传同版本 Windows ZIP 和 `SHA256SUMS.txt`。仅推送源码或修改 README 不会触发客户端升级。
- 下载后校验 SHA256，沿用原版的空闲安装、恢复与回滚机制，保留数据目录中的个人设置。
- 源码检出目录受 Git 保护，不由更新器覆盖；维护者在源码目录手动修改。其他电脑从 Release 安装的普通目录可自动更新。
- 本分支从 `2.0.0` 建立独立版本线。小修复增加补丁号，新增兼容功能增加次版本号，破坏兼容的改动增加主版本号。不按聊天次数递增版本。

## 许可与图片

代码沿用原项目 [MIT License](LICENSE)，保留 T7moris 和原项目贡献者版权声明。龙娘图片及派生表情**不属于代码 MIT 的商业授权范围**，仅作为本项目非商业副本的一部分分发；不得作为独立素材包或商业素材使用。详见 [角色素材声明](gpt-niang-usage/assets/CHARACTER-NOTICE.txt)、[语录许可](gpt-niang-usage/assets/quotes-LICENSE.txt)和[生成说明](gpt-niang-usage/assets/生成说明.md)。

新增的流口水、闭眼和美元眼为基于原角色的修改素材，遵循相同使用范围。本分支不主张拥有参考角色、第三方图像或商标的权利。


## English

**GPT Dragon Girl Bubble Plugin, v2.0.7.** Windows quota, task-state and approval bubbles. Non-commercial use only.

### Version 2.0.7

Allow portable releases untracked by an ancestor Git workspace while preserving protection for actual source. An old guard that blocks updates requires one complete manual overlay and installer run to update both the checker and stable helper.

### Version 2.0.6

Harden updater startup, runtime recovery and error feedback, with real isolated headless upgrade, rollback and restart-recovery checks. An old updater that cannot launch needs one full manual upgrade to 2.0.5 or later before subsequent checks can use this path.

### Version 2.0.5

Recover executable paths after client/runtime upgrades to restore quota and activity monitoring. Use a stable MCP launcher, and synchronize WPF Topmost with native window layering. Prefer the running Codex installation or the newest available install. Dollar eyes cover exhaustion of either the five-hour or weekly allowance with purchased credits remaining. Existing preferences are preserved.

### Version 2.0.4

Add native browser/plugin approval synchronization. Confirmation forms with no additional fields can be allowed or denied in the pet, with identity/content rechecks and prompt cleanup. A website download approval was verified interactively. Login, CAPTCHA, device verification and filled forms remain in Codex. This uses the local client's internal window protocol and may need maintenance after updates.

### Version 2.0.3

Fix missing running-chat indicators for resumed/imported chats by reconciling lifecycle logs with database state. Two active chats display `2......`; completion and cancellation clear their counts. See [CHANGELOG](CHANGELOG.md).

### Version 2.0.2

- Listen for Codex process start/exit events and retain validated process handles, with fallback reconciliation when events are unavailable.
- Remove the fixed three-second exit delay. Desktop mode no longer waits for Codex interface readiness; window-follow mode retains readiness checks.
- Keep the pet while Codex is minimized or closed to the background; close it when Codex fully exits.
- Fix upgrades blocked by shipped `tools` and documentation being mistaken for personal files.
- Check this repository for updates at startup and every 24 hours while running. Manual checks and rate-limit backoff remain available.
- Simplify version labels and hide internal build identifiers.

**Upgrading from 2.0.0 / 2.0.1:** this download uses a layout compatible with the old updater. Check for updates in the pet menu and confirm **2.0.7** afterwards. If an earlier failure left an abnormal update state, exit the pet, extract the complete release over the original installation, and run `安装GPT娘.cmd`. Keep `installation.json` and personal data; do not uninstall or delete settings first.

### Original project and credits

- Original repository: [T7moris/GPT-Niang](https://github.com/T7moris/GPT-Niang)
- Original releases: [upstream downloads](https://github.com/T7moris/GPT-Niang/releases)
- Original Bilibili video: [GPT龙娘气泡插件 — BV1Kga666EyT](https://www.bilibili.com/video/BV1Kga666EyT/)
- Original documentation and contributor credits: [UPSTREAM-README.md](UPSTREAM-README.md), [UPSTREAM-CHANGELOG.md](UPSTREAM-CHANGELOG.md).

Thanks to T7moris and all upstream contributors for the original widget, character artwork, quota reader, quotes, gallery, audio and update framework. This fork preserves their attribution and license notices. The following list describes the subsequent changes, not ownership of upstream features.

### What changed in this fork

1. **Codex-linked lifecycle:** the widget appears when Codex starts, stays available while Codex is minimized or running in the background, and closes when Codex fully exits.
2. **Double-click to restore Codex:** single-click still opens quota information; double-click brings the minimized or background Codex window forward.
3. **Purchased credits and USD estimate:** a third quota row shows the official remaining credit balance and an estimate using `500 credits = USD 20`. This is a display estimate, not a billing or refund balance.
4. **Clear quota colors:** progress bars and percentages are green normally and red at 25% remaining or less, preserving the existing warning threshold.
5. **Quota-based expressions:** normal artwork stays unchanged. An exhausted five-hour allowance with no purchased credits shows the drooling expression; with weekly allowance below 5%, it shows the previously approved closed-eye expression. When either the five-hour or weekly allowance is exhausted, remaining purchased credits select the simplified dollar-eye artwork with the original highlights retained.
6. **Failure expression override:** a confirmed failed turn takes priority and shows the drooling expression. The normal quota expression returns after resolution. Normal cancellation and individual tool errors followed by retries do not trigger this override.
7. **Running-chat counter:** purple `......` beside the horn changes to `3......` for concurrent chats, capped at 99. It counts chats, not individual tool calls.
8. **Waiting counter:** a purple `+1`, `+2`, etc. appears on the line above. Waiting and running are tracked separately; asynchronous questions can coexist with active work.
9. **Embedded interaction queue:** approval and question notices use the original speech bubble. Approvals take priority; approvals and ordinary questions each keep their own chronological order.
10. **Per-request approval buttons:** valid PermissionRequest hook requests can be allowed or denied once, with request identity and validity checks. Unsupported prompts open Codex instead; free-text answers still use Codex.
11. **Longer waits and lifecycle cleanup:** the hook runs for up to about 24 hours, then hands back to Codex with a read-only mirror. Expired buttons cannot submit decisions. Notices are reconciled using replies, subsequent user input, cancellation and turn state. Some native browser/login prompts still require the main app.
12. **Restart recovery and deduplication:** counters recover from the latest turn per chat, filtering subagents and old process records. An unavailable state source shows `?` instead of inventing a zero count.
13. **Automation-start notifications:** recurring and one-time scheduled tasks display their chat's latest title when triggered.
14. **Completion message:** one bubble shows `已严肃回复` and `ᗜˬᗜ` on separate lines.
15. **Startup and layout refinements:** windowless launchers, no long hover instruction tooltip, revised quota spacing and larger purple horn-side indicators. Defaults are silent, with automatic idle quotes disabled and separate character/bubble scales.
16. **Independent update source:** automatic updates use stable Releases from this repository. Original project links remain available in the credits.

### Installation and updates

Download the Windows ZIP and `SHA256SUMS.txt` from [this fork's Releases](https://github.com/holenc/codex-dragon-girl-custom/releases/latest), verify the hash, extract the entire package to a permanent ordinary folder, and run `安装GPT娘.cmd`. Requires a signed-in Codex desktop client and Node.js 24+. The installer can detect the Node bundled with Codex Primary Runtime.

Machine-specific paths and plugin registration are regenerated locally. Existing preferences are retained; a fresh installation uses the shipped defaults. Approval bubbles require reviewing and trusting the hook in Codex's Hooks page. The installer never grants trust or approves requests on your behalf.

Automatic update checks run **at startup and every 24 hours while the pet stays running**. Manual checks remain available. A new version requires a higher version tag and matching Windows ZIP plus `SHA256SUMS.txt` release assets; editing source files or the README alone does not trigger an update. Downloads are checksum-verified and use the existing idle-install/recovery mechanism. Git source checkouts are protected from replacement and maintained manually.

Windows local Codex sessions only; ordinary ChatGPT web chats are not integrated. Task-state parsing was adapted to Codex desktop 26.1111.2228.0 and may need maintenance when client internals change. Other computers and future client versions have not been fully validated.

### License and artwork

Code retains the upstream [MIT License](LICENSE) and copyright notices. Character artwork and derived expressions are **not covered by the code's commercial-use grant**. They are distributed only as part of this non-commercial project copy, not as standalone or commercial assets. Preserve [CHARACTER-NOTICE.txt](gpt-niang-usage/assets/CHARACTER-NOTICE.txt), [quote licensing](gpt-niang-usage/assets/quotes-LICENSE.txt) and [artwork provenance](gpt-niang-usage/assets/生成说明.md). Third-party character, image and trademark rights remain with their respective owners.
