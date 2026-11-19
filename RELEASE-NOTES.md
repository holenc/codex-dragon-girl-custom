# GPT龙娘气泡插件

## 2.0.7 — 2026-11-19

- 修复上级工作目录存在 `.git` 时，独立解压的发布版被一律当作源码、无法检查更新的问题。
- 检查器和安装助手使用一致规则：程序目录本身是仓库、程序文件被上级仓库跟踪、或存在明确的源码维护标记时继续保护；上级仓库未跟踪安装目录的发布版可以更新。
- Git 跟踪状态核对仅使用只读索引查询，不修改仓库文件或持久 Git 配置；无法核对时显示保护原因。
- 诊断脚本新增程序仓库、上级仓库和维护标记信息，更新状态增加具体的源码保护原因。
- 已验证 JavaScript 检查器与 PowerShell 安装助手在独立目录、未跟踪发布版、真实源码和无法核对等情况下判断一致。

此前已被旧版源码保护拦截的安装，需要手动完整覆盖本版并运行 `安装GPT娘.cmd` 一次，以同时刷新检查器和稳定安装助手。真正的源码仓库仍应通过 Git 维护或另行安装独立 Release，无需删除 `.git`。

## English

### 2.0.7 — 2026-11-19

- Fix portable releases being blocked as source merely because an ancestor workspace contains `.git`.
- Use the same policy in the checker and installer: protect repositories at the program boundary, files tracked by an ancestor repository, and explicit maintenance markers. Allow portable installations untracked by the ancestor workspace.
- Inspect the Git index read-only without changing repository files or persistent Git configuration. Remain protected with a specific reason when inspection is unavailable.
- Add repository-scope details to diagnostics and specific source-protection reasons to update status.
- Verify matching JavaScript and PowerShell decisions for standalone releases, untracked portable installs, tracked source and unavailable inspection.

Installations blocked by the old source guard require one complete manual overlay of this release followed by `安装GPT娘.cmd` to refresh both the checker and stable installer. Actual source repositories remain managed through Git or a separately installed Release; do not remove `.git`.
