# 需求对应表

| 需求 | 实现与证据 |
|---|---|
| Godot 标准版 | `project.godot`，纯 GDScript，无 .NET |
| 完整可玩成品 | `scenes/main.tscn`、`scripts/ui/main.gd`、`build/DevilsGame.exe` |
| 完整规则结算 | `scripts/core/game_rules.gd`、`match_state.gd` |
| 严格公开信息边界 | `MatchState.public_ai_state()` 与自动化边界测试 |
| 最多 75 个候选 | `UtilityAI._generate_candidates()` |
| 十因子效用评分 | `UtilityAI._score_action()` 和逐候选日志 |
| 4 人格 × 3 难度 | `data/ai_config.json`，12 个 Profile |
| 对手行为模型 | `UtilityAI._build_opponent_model()` |
| 读牌、弑王、求和、失忆 | `game_session.gd`、`utility_ai.gd`、`match_state.gd` |
| 五套多轮剧本 | `data/ai_config.json` Playbooks 与运行时推进/中断逻辑 |
| 中文人格台词 | `data/dialogue_zh_cn.json`，156 条 |
| 完整游戏 UI | 菜单、配置、对局、教程、设置、战绩、结算七类页面 |
| 存档与设置 | `save_service.gd`，音量、全屏、减少动态、大字、高对比度 |
| 美术与音效 | 两张最终生成图、程序化背景印记、运行时合成反馈音 |
| 500ms 性能预算 | 356 项测试中 100 次决策性能基准 |
| Windows 发布物 | `build/DevilsGame.exe` + `DevilsGame.pck` |
