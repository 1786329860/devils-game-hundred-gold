extends SceneTree

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	print("[TEST] 恶魔游戏：百金争夺")
	_test_matchups()
	_test_candidates()
	_test_all_profiles()
	_test_config_completeness()
	_test_information_boundary()
	_test_reading()
	_test_match_resolution()
	_test_general_draw_ban()
	_test_full_matches()
	_test_personality_statistics()
	_test_dialogue_data()
	_test_contracts()
	_test_progression()
	_test_performance()
	if failures.is_empty():
		print("[PASS] %d checks" % checks)
		quit(0)
	else:
		for failure in failures:
			printerr("[FAIL] " + failure)
		printerr("%d failures / %d checks" % [failures.size(), checks])
		quit(1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _test_matchups() -> void:
	for ai_piece in GameRules.PIECES:
		for ai_upgrade in [GameRules.Upgrade.NONE, GameRules.Upgrade.OPEN]:
			for player_piece in GameRules.PIECES:
				for player_upgrade in [GameRules.Upgrade.NONE, GameRules.Upgrade.OPEN]:
					var result := GameRules.resolve(ai_piece, ai_upgrade, player_piece, player_upgrade)
					_check(result.winner in [GameRules.Winner.AI, GameRules.Winner.PLAYER, GameRules.Winner.DRAW], "对抗矩阵返回非法结果")
	var upset := GameRules.resolve(GameRules.Piece.COMMONER, GameRules.Upgrade.SECRET, GameRules.Piece.KING, GameRules.Upgrade.OPEN)
	_check(upset.winner == GameRules.Winner.AI and upset.instant_upset, "二级平民必须绝杀二级国王")
	var normal := GameRules.resolve(GameRules.Piece.COMMONER, GameRules.Upgrade.NONE, GameRules.Piece.KING, GameRules.Upgrade.NONE)
	_check(normal.winner == GameRules.Winner.AI and not normal.instant_upset, "普通平民应弑普通国王但不绝杀")

func _test_candidates() -> void:
	var state := MatchState.new(10)
	state.reset(GameRules.Personality.TACTICAL, GameRules.Difficulty.HELL, 10)
	state.begin_next_round()
	var ai := UtilityAI.new(GameRules.Personality.TACTICAL, GameRules.Difficulty.HELL, 10)
	var result := ai.decide_action(state.public_ai_state())
	_check(result.candidates.size() == 75, "完整手牌加钻石应生成 75 个候选")
	state.ai_diamond_used = true
	result = ai.decide_action(state.public_ai_state())
	_check(result.candidates.size() == 25, "钻石已用后应生成 25 个候选")
	var beginner := UtilityAI.new(GameRules.Personality.TACTICAL, GameRules.Difficulty.BEGINNER, 11)
	state.ai_diamond_used = false
	result = beginner.decide_action(state.public_ai_state())
	_check(result.candidates.size() == 50, "入门难度禁用暗牌升级后应生成 50 个候选")

func _test_all_profiles() -> void:
	for personality in 4:
		for difficulty in 3:
			var state := MatchState.new(100 + personality * 10 + difficulty)
			state.reset(personality, difficulty, 100 + personality * 10 + difficulty)
			state.begin_next_round()
			var ai := UtilityAI.new(personality, difficulty, state.seed_value)
			var decision := ai.decide_action(state.public_ai_state())
			_check(not decision.is_empty(), "人格 %d 难度 %d 未产生行动" % [personality, difficulty])
			_check(GameRules.validate_action(state.ai_hand, state.ai_diamond_used, decision.action), "AI 产生非法行动")
			_check(float(decision.elapsed_ms) < 500.0, "AI 决策超过 500ms")

func _test_config_completeness() -> void:
	var ai := UtilityAI.new(GameRules.Personality.TACTICAL, GameRules.Difficulty.HELL, 15)
	_check(ai.config.get("Personalities", []).size() == 4, "必须有四种人格配置")
	_check(ai.config.get("Difficulties", []).size() == 3, "必须有三档难度配置")
	_check(ai.config.get("Profiles", []).size() == 12, "必须有 12 种人格难度组合")
	_check(ai.config.get("Playbooks", []).size() >= 5, "必须有至少五套剧本")
	for personality in ai.config.get("Personalities", []):
		var weights: Dictionary = personality.Weights
		var total := 0.0
		for key in weights:
			total += float(weights[key])
		_check(absf(total - 1.0) < 0.0001, "人格效用权重总和必须为 1")

func _test_information_boundary() -> void:
	var state := MatchState.new(20)
	var public_state := state.public_ai_state()
	_check(not public_state.has("opponent_hand"), "公开状态不得包含玩家手牌")
	_check(not public_state.has("player_current_action"), "公开状态不得包含玩家当前行动")
	_check(not public_state.has("player_disguise"), "公开状态不得包含玩家伪装")

func _test_reading() -> void:
	var state := MatchState.new(30)
	state.reset(GameRules.Personality.TACTICAL, GameRules.Difficulty.HELL, 30)
	state.begin_next_round()
	state.current_round_gold = 45
	var ai := UtilityAI.new(GameRules.Personality.TACTICAL, GameRules.Difficulty.HELL, 30)
	var reading := ai.evaluate_reading(state.public_ai_state())
	_check(reading.value >= 0.0 and reading.value <= 1.0, "读牌价值必须归一化")
	state.shared_readings_remaining = 0
	reading = ai.evaluate_reading(state.public_ai_state())
	_check(not reading.should_read, "共享次数耗尽后不得读牌")

func _test_match_resolution() -> void:
	var state := MatchState.new(40)
	state.reset(GameRules.Personality.CONSERVATIVE, GameRules.Difficulty.INTERMEDIATE, 40)
	state.current_round_gold = 40
	state.round_number = 1
	var player := {"piece": GameRules.Piece.COMMONER, "upgrade": GameRules.Upgrade.SECRET, "display": GameRules.Piece.SOLDIER}
	var ai_action := {"piece": GameRules.Piece.KING, "upgrade": GameRules.Upgrade.OPEN, "display": GameRules.Piece.KING}
	var result := state.resolve_round(player, ai_action)
	_check(result.instant_upset and state.match_over, "绝杀应立即结束对局")
	_check(state.ai_gold == 0 and state.final_winner == GameRules.Winner.PLAYER, "绝杀应清空败者金币")

func _test_general_draw_ban() -> void:
	var state := MatchState.new(41)
	state.reset(GameRules.Personality.CONSERVATIVE, GameRules.Difficulty.INTERMEDIATE, 41)
	state.current_round_gold = 12
	state.round_number = 1
	var action := {"piece": GameRules.Piece.GENERAL, "upgrade": GameRules.Upgrade.NONE, "display": GameRules.Piece.GENERAL}
	var result := state.resolve_round(action, action.duplicate(true))
	_check(result.winner == GameRules.Winner.DRAW, "同阶将军应平局")
	_check(state.player_hand[GameRules.Piece.GENERAL].banned, "玩家将军平局后必须标记封禁")
	_check(state.ai_hand[GameRules.Piece.GENERAL].banned, "AI 将军平局后必须标记封禁")

func _test_full_matches() -> void:
	for index in 24:
		var session := GameSession.new()
		root.add_child(session)
		session.start_match(index % 4, index % 3, 5000 + index)
		var guard := 0
		while not session.state.match_over and guard < 8:
			var pieces := GameRules.available_pieces(session.state.player_hand)
			_check(not pieces.is_empty(), "未结束对局中玩家必须有可用棋子")
			if pieces.is_empty():
				break
			var piece: int = pieces[0]
			var action := {"piece": piece, "upgrade": GameRules.Upgrade.NONE, "display": piece}
			session.submit_player_action(action)
			if not session.state.match_over:
				session.begin_round()
			guard += 1
		_check(session.state.match_over, "完整对局必须在有限回合内结束")
		_check(session.state.remaining_gold == 0, "结束时全部金币必须已赢取或浪费")
		_check(session.state.player_gold + session.state.ai_gold + session.state.wasted_gold == 100 or session.state.instant_upset, "金币守恒失败")
		session.queue_free()

func _test_personality_statistics() -> void:
	var deceptive_disguises := 0
	var aggressive_disguises := 0
	var aggressive_high := 0
	var conservative_high := 0
	for index in 120:
		var state := MatchState.new(7000 + index)
		state.reset(GameRules.Personality.DECEPTIVE, GameRules.Difficulty.HELL, 7000 + index)
		state.begin_next_round()
		state.current_round_gold = 38
		var deceptive: Dictionary = UtilityAI.new(GameRules.Personality.DECEPTIVE, GameRules.Difficulty.HELL, 8000 + index).decide_action(state.public_ai_state()).action
		var aggressive: Dictionary = UtilityAI.new(GameRules.Personality.AGGRESSIVE, GameRules.Difficulty.HELL, 9000 + index).decide_action(state.public_ai_state()).action
		var conservative: Dictionary = UtilityAI.new(GameRules.Personality.CONSERVATIVE, GameRules.Difficulty.HELL, 10000 + index).decide_action(state.public_ai_state()).action
		if deceptive.display != deceptive.piece: deceptive_disguises += 1
		if aggressive.display != aggressive.piece: aggressive_disguises += 1
		if aggressive.piece >= GameRules.Piece.GENERAL: aggressive_high += 1
		if conservative.piece >= GameRules.Piece.GENERAL: conservative_high += 1
	_check(deceptive_disguises > aggressive_disguises, "欺诈型伪装率应高于激进型")
	_check(aggressive_high > conservative_high, "激进型大额轮高阶投入应高于保守型")

func _test_dialogue_data() -> void:
	var engine := DialogueEngine.new(50)
	_check(engine.lines.size() >= 156, "中文台词应至少包含 156 条")
	for personality in 4:
		var text := engine.pick(personality, DialogueEngine.Event.ROUND_START, 1, 10, 0)
		_check(not text.is_empty(), "每种人格必须有回合开始台词")

func _test_contracts() -> void:
	var contracts := ContractSystem.all()
	_check(contracts.size() >= 6, "至少需要六种可玩契约")
	var daily_a := ContractSystem.daily_configuration("2026-06-15")
	var daily_b := ContractSystem.daily_configuration("2026-06-15")
	_check(daily_a == daily_b, "同一天的今日审判必须完全确定")
	for index in contracts.size():
		var contract: Dictionary = contracts[index]
		var state := MatchState.new(12000 + index)
		state.reset(GameRules.Personality.TACTICAL, GameRules.Difficulty.HELL, 12000 + index, String(contract.id))
		state.begin_next_round()
		var decision := UtilityAI.new(GameRules.Personality.TACTICAL, GameRules.Difficulty.HELL, 13000 + index).decide_action(state.public_ai_state())
		_check(not decision.is_empty(), "AI 必须为契约生成候选：" + String(contract.name))
		if decision.is_empty():
			continue
		_check(state.validate_action(decision.action, false), "AI 必须遵守契约限制：" + String(contract.name))
		if String(contract.id) == "true_names":
			_check(int(decision.action.display) == int(decision.action.piece), "真名戒律下 AI 不得伪装")
		if String(contract.id) == "blind_pact":
			_check(state.shared_readings_remaining == 0, "盲眼契约必须禁用读牌")
		if String(contract.id) == "fractured_oracle":
			_check(state.shared_readings_remaining == 3 and is_equal_approx(state.reading_accuracy, 0.60), "破碎预言参数错误")

func _test_progression() -> void:
	var data := SaveService.default_data()
	data.stats.personality_wins = [1, 1, 1, 1]
	var summary := {
		"winner": GameRules.Winner.PLAYER,
		"player_gold": 72,
		"ai_gold": 28,
		"difficulty": GameRules.Difficulty.HELL,
		"contract_id": "blind_pact",
		"instant_upset": false,
		"player_king_kills": 1,
		"player_readings_used": 0,
	}
	var reward := ProgressionService.record_result(data, summary, "daily", "2026-06-15")
	_check(int(reward.xp) > 0 and int(reward.seals) > 0, "成长奖励必须为正数")
	_check(bool(reward.daily_first) and int(data.profile.daily_streak) == 1, "首次每日挑战必须建立连签")
	_check(data.achievements.size() >= 5, "高质量胜局应一次解锁多个成就")
	var repeated := ProgressionService.record_result(data, summary, "daily", "2026-06-15")
	_check(not bool(repeated.daily_first) and int(repeated.xp) < int(reward.xp), "重复每日挑战奖励必须衰减")

func _test_performance() -> void:
	var started := Time.get_ticks_msec()
	for i in 100:
		var state := MatchState.new(1000 + i)
		state.reset(i % 4, i % 3, 1000 + i)
		state.begin_next_round()
		var ai := UtilityAI.new(i % 4, i % 3, 2000 + i)
		ai.decide_action(state.public_ai_state())
	var elapsed := Time.get_ticks_msec() - started
	print("[PERF] 100 decisions: %dms" % elapsed)
	_check(elapsed < 50000, "100 次决策总耗时异常")
