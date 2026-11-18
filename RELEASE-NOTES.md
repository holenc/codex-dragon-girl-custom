# GPT龙娘气泡插件

## 2.0.3 — 2026-11-17

- 修复恢复或导入的对话正在工作，但龙娘漏算运行数量的问题。部分对话的新轮次会写入日志，状态数据库却仍停留在旧轮次。
- 同时核对数据库与当前会话日志，以任务开始、完成、取消和整轮失败记录补齐状态；按对话去重，不把历史轮次重复计数。
- 修复数据库挑选最新轮次时过度依赖日志序号的问题，优先使用轮次开始时间。
- 保留单任务 `......`、多任务 `2......`、最大 99 的显示规则，以及授权/等待优先级。
- 新增数据库漏记、完成撤销、取消撤销、迟到的旧轮次事件及重启恢复测试。只读实测已同时识别两条实际运行中的对话，运行数为 2。

本版保留 2.0.2 的启停同步、每日更新检查和兼容旧更新器的下载布局。

## English

### 2.0.3 — 2026-11-17

- Fix missing running-chat counts for resumed/imported conversations whose current turns exist in rollout logs but are absent from the history database.
- Reconcile database rows with lifecycle log events for task start, completion, cancellation and whole-turn failure. Count each chat once and exclude historical turns.
- Select database turns by start time before using rollout ordinal as a tie-breaker.
- Preserve `......` for one running chat, `2......` for multiple chats, the 99 cap and existing approval/wait priorities.
- Add regression coverage for missing index entries, completion, cancellation, late old-turn events and restart recovery. Read-only verification of the two active chats returned a running count of 2.

Includes the lifecycle synchronization, daily update checks and legacy-compatible download layout from 2.0.2.
