# GPT龙娘气泡插件

## 2.0.4 — 2026-11-18

- 新增 Codex 原生审批同步通道，补齐没有进入 PermissionRequest Hook 的浏览器/插件确认。
- 支持在气泡中同意或拒绝无需额外填写字段的原生确认，例如网站下载许可。决定通过客户端原有接口回传，只提交对应请求，不设置“总是允许”。
- 登录、验证码、设备验证、需要填写字段的表单等仍在 Codex 本体处理；气泡提供只读提示，不伪造输入或验证结果。
- 原生审批参与授权优先与时间顺序队列、`+N` 等待计数。你在 Codex 本体处理、取消请求或连接断开时，及时撤销对应气泡/按钮。
- 每次点击先重新核对原生请求编号、所属对话、请求内容和窗口归属；失效、内容改变和重复响应不会批准其他操作。
- 使用独立本地客户端连接，不修改 Codex 程序，不开启远程控制，不调用模型。该接口依赖客户端内部协议，后续版本变化可能需要维护。
- 新增本地协议模拟测试：同意、拒绝、本体处理同步、请求改变竞态、篡改响应和断线撤销。用户已实测浏览器下载审批：点击龙娘同意后任务继续，气泡及等待标记消失。

## English

### 2.0.4 — 2026-11-18

- Add a native Codex approval bridge for browser/plugin confirmations that do not enter the PermissionRequest hook.
- Allow or deny native confirmation forms that require no additional input, such as website download permission. Submit the decision through the client's existing interface for the matching request; do not set an always-allow policy.
- Login, CAPTCHA, device verification and forms requiring field values remain in Codex. The pet provides a read-only notice instead of fabricating input or verification results.
- Include native requests in the approval-first chronological queue and `+N` waiting count. Remove matching prompts/buttons when handled in Codex, cancelled or disconnected.
- Recheck request identity, chat, contents and owning client before each submission. Stale, changed and duplicate responses cannot approve another action.
- Connect as a separate local client without modifying Codex, enabling remote control or calling a model. This integration depends on an internal client protocol and may need maintenance after client updates.
- Add local protocol tests for allow, deny, native resolution, changed-request races, tampered responses and disconnect cleanup. A real browser download approval was confirmed interactively: clicking Allow in the pet resumed the task and cleared the bubble and waiting indicator.
