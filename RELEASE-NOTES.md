# GPT龙娘气泡插件

## 2.0.8 — 2026-11-23

- 修复新版 Codex 通过中间进程启动后台服务时，龙娘无法识别当前会话、显示问号及丢失任务反馈的问题；不受角色与 Codex 是否位于不同屏幕影响。
- 进程识别核对同一 Windows 会话、同一客户端目录和父子创建时间，并限制祖先遍历，排除无关服务。
- 修复周额度耗尽且充值余额归零后未切换闭眼的问题；本地轮询与表情切换不依赖模型调用。
- 修复桌面模式下完成提醒为适配透明窗口边缘而把角色向上推的问题，提醒出现和消失保持桌面位置。
- 验证后台进程识别、美元眼到闭眼再恢复、完成提醒定位与恢复。其他电脑的实际运行仍需更新后确认。

## English

### 2.0.8 — 2026-11-23

- Recognize Codex app servers launched through an intermediate client process, fixing question marks and missing task feedback, including use across separate monitors.
- Validate Windows session, client installation directory and process creation order with bounded ancestry checks to reject unrelated services.
- Close the pet's eyes when weekly quota is exhausted and purchased credits reach zero. Local polling and expression changes do not require model calls.
- Keep desktop placement unchanged when completion reminders appear or disappear, rather than moving the character to fit transparent window padding.
- Verify process identity, credit-depletion expression transitions, and reminder placement/restoration. Actual behavior on other computers still requires confirmation after updating.
