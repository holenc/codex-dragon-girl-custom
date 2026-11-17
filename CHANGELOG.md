# GPT龙娘气泡插件（自定义修改版）更新记录

## 2.0.1 — 2026-11-17

- 修复关闭到后台后，双击龙娘唤出 Codex 可能卡住、无法点击的问题。
- 隐藏窗口改走客户端的正常应用激活入口，不再用 ShowWindowAsync 强行显示；普通最小化继续正常恢复。
- 动态读取运行中客户端的应用标识，避免硬编码安装版本；补充唤醒分支测试和诊断状态。
- 已由用户实际验证关闭到后台后可正常唤出并操作。

### English

- Fixed a potentially non-interactive Codex window when double-clicking the pet after closing Codex to the background.
- Hidden windows now use normal application activation instead of a raw Win32 show call; ordinary minimized-window restore is preserved.
- Read the running client's application identity dynamically and added activation-route regression tests and diagnostics.
- The user confirmed the background-close / double-click / interact flow works on the maintainer's computer.

## 2.0.0 — 2026-11-16

基于 T7moris/GPT-Niang v1.3.6 建立个人非商业定制分支。完整出处与逐条改动见 [README](README.md)。

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

## English — v2.0.0

Initial custom fork based on upstream v1.3.6. Added purchased-credit/USD display, quota and failure expressions, running/waiting counters, embedded approval queues, restart recovery, scheduled-task title notifications, windowless startup, and independent startup-only updates. Original repository, Bilibili video, contributor credits and license notices are preserved. See README for the itemized bilingual comparison and current limitations.
