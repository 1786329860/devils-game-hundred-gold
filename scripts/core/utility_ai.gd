class_name UtilityAI
extends RefCounted

var personality := GameRules.Personality.TACTICAL
var difficulty := GameRules.Difficulty.INTERMEDIATE
var rng := RandomNumberGenerator.new()
var config: Dictionary = {}
var personality_config: Dictionary = {}
var difficulty_config: Dictionary = {}
var active_playbook: Dictionary = {}
var playbook_step := 0
var playbook_disruptions := 0
var last_log := ""

func _init(personality_value: int = GameRules.Personality.TACTICAL, difficulty_value: int = GameRules.Difficulty.INTERMEDIATE, seed_value: int = 1) -> void:
	personality = personality_value
	difficulty = difficulty_value
	rng.seed = seed_value
	_load_config()

func _load_config() -> void:
	var file := FileAccess.open("res://data/ai_config.json", FileAccess.READ)
	if file:
		var parsed = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			config = parsed
	if config.is_empty():
		config = _fallback_config()
	for item in config.get("Personalities", []):
		if int(item.Type) == personality:
			personality_config = item
			break
	for item in config.get("Difficulties", []):
		if int(item.Tier) == difficulty:
			difficulty_config = item
			break
	if personality_config.is_empty() or difficulty_config.is_empty():
		push_error("AI 配置缺少人格或难度，使用安全默认值。")
		config = _fallback_config()
		personality_config = config.Personalities[personality]
		difficulty_config = config.Difficulties[difficulty]

func reset_match() -> void:
	active_playbook.clear()
	playbook_step = 0
	playbook_disruptions = 0
	last_log = ""

func evaluate_reading(state: Dictionary) -> Dictionary:
	if int(state.get("shared_readings", 0)) <= 0:
		return {"should_read": false, "value": 0.0, "threshold": float(difficulty_config.ReadingThreshold)}
	var model := _build_opponent_model(state)
	var uncertainty := 1.0 - float(model.confidence)
	var importance := clampf(float(state.current_gold) / 45.0, 0.0, 1.0)
	var resource_factor := 0.55 + float(state.shared_readings) / 2.0 * 0.45
	var endgame_factor := 1.15 if int(state.remaining_gold) < 40 else 1.0
	var value := clampf(uncertainty * importance * resource_factor * endgame_factor, 0.0, 1.0)
	var threshold := float(difficulty_config.ReadingThreshold)
	var jitter := rng.randf_range(-1.0, 1.0) * float(difficulty_config.UtilityNoise) * 0.30
	return {
		"should_read": value + jitter >= threshold,
		"value": value,
		"threshold": threshold,
		"reason": "不确定度 %.2f · 重要度 %.2f" % [uncertainty, importance],
	}

func decide_action(state: Dictionary) -> Dictionary:
	var started := Time.get_ticks_usec()
	var model := _build_opponent_model(state)
	var probabilities: Array = model.probabilities
	var upgrade_probability := float(model.upgrade_probability)
	_prepare_playbook(state)
	var candidates := _generate_candidates(state)
	var scored: Array[Dictionary] = []
	for action in candidates:
		scored.append(_score_action(action, state, model, probabilities, upgrade_probability))
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.total) > float(b.total))
	if scored.is_empty():
		push_error("AI 没有合法候选行动。")
		return {}
	var selected: Dictionary = scored[0]
	_advance_playbook(selected.action)
	var elapsed_ms := (Time.get_ticks_usec() - started) / 1000.0
	last_log = _format_log(state, scored, elapsed_ms)
	if elapsed_ms > 500.0:
		push_warning("AI 决策超出 500ms 预算：%.2fms" % elapsed_ms)
	return {
		"action": selected.action,
		"score": selected.total,
		"candidates": scored,
		"elapsed_ms": elapsed_ms,
		"log": last_log,
		"playbook": active_playbook.get("DisplayName", ""),
	}

func _generate_candidates(state: Dictionary) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	var upgrades: Array[int] = [GameRules.Upgrade.NONE]
	if not bool(state.ai_diamond_used):
		if bool(state.get("allow_open_upgrade", true)):
			upgrades.append(GameRules.Upgrade.OPEN)
		if bool(state.get("allow_secret_upgrade", true)) and bool(difficulty_config.AllowSecretUpgrade):
			upgrades.append(GameRules.Upgrade.SECRET)
	for piece in GameRules.available_pieces(state.ai_hand):
		for upgrade in upgrades:
			var displays: Array[int] = []
			if bool(state.get("allow_disguise", true)):
				displays.assign(GameRules.PIECES)
			else:
				displays.append(piece)
			for display in displays:
				actions.append({"piece": piece, "upgrade": upgrade, "display": display})
	return actions

func _build_opponent_model(state: Dictionary) -> Dictionary:
	var history: Array = state.get("history", [])
	var depth := int(difficulty_config.OpponentHistoryDepth)
	var start := maxi(0, history.size() - depth) if depth < 1000 else 0
	var recent := history.slice(start)
	var used := {}
	var disguise_count := 0
	var upgrades := 0
	var secret_upgrades := 0
	var power_sum := 0.0
	var large_power := 0.0
	var large_count := 0
	var powers: Array[float] = []
	for record in recent:
		var piece := int(record.player_piece)
		used[piece] = true
		var power := float(GameRules.combat_power(piece, int(record.player_upgrade)))
		power_sum += power
		powers.append(power)
		if int(record.player_display) != piece:
			disguise_count += 1
		if int(record.player_upgrade) != GameRules.Upgrade.NONE:
			upgrades += 1
			if int(record.player_upgrade) == GameRules.Upgrade.SECRET:
				secret_upgrades += 1
		if int(record.gold) >= 30:
			large_power += power
			large_count += 1
	var count := recent.size()
	var confidence: float
	if count <= 2:
		confidence = count * 0.14
	elif count <= 5:
		confidence = 0.30 + (count - 2) * 0.13
	else:
		confidence = minf(0.95, 0.72 + (count - 5) * 0.06)
	if bool(state.get("amnesia", false)):
		confidence *= 0.62
	var average_power := power_sum / count if count > 0 else 3.0
	var risk_preference := clampf((average_power - 1.0) / 5.0 + (float(upgrades) / maxi(1, count)) * 0.25, 0.0, 1.0)
	var aggression_trend := _power_trend(powers)
	var importance := clampf(float(state.current_gold) / 45.0, 0.0, 1.0)
	var probabilities: Array[float] = []
	var probability_total := 0.0
	for piece in GameRules.PIECES:
		if used.has(piece):
			probabilities.append(0.0)
			continue
		var strength := float(piece) / 4.0
		var gold_modifier := 0.65 + importance * strength * 1.35 + (1.0 - importance) * (1.0 - strength) * 0.55
		var risk_modifier := 0.70 + risk_preference * strength * 0.85
		var history_modifier := 1.0 + confidence * aggression_trend * strength * 0.40
		var drama := 1.15 if piece == GameRules.Piece.COMMONER and int(state.current_gold) >= 20 else 1.0
		var weight := maxf(0.01, gold_modifier * risk_modifier * history_modifier * drama)
		probabilities.append(weight)
		probability_total += weight
	if probability_total <= 0.0:
		probabilities = [0.2, 0.2, 0.2, 0.2, 0.2]
	else:
		for index in probabilities.size():
			probabilities[index] /= probability_total
	var observed_upgrade_rate := float(upgrades) / count if count > 0 else 0.20
	var upgrade_probability := 0.10 + importance * 0.35
	upgrade_probability = lerpf(upgrade_probability, observed_upgrade_rate, confidence)
	if bool(state.get("opponent_diamond_known_used", false)):
		upgrade_probability = 0.0
	if state.has("last_reading") and state.last_reading is Dictionary and not state.last_reading.is_empty():
		var reading: Dictionary = state.last_reading
		if int(reading.get("topic", -1)) == 0:
			var belief := 0.70 if bool(reading.reported) else 0.30
			upgrade_probability = lerpf(upgrade_probability, belief, 0.65)
	return {
		"probabilities": probabilities,
		"confidence": confidence,
		"risk_preference": risk_preference,
		"aggression_trend": aggression_trend,
		"disguise_rate": float(disguise_count) / count if count > 0 else 0.35,
		"upgrade_rate": observed_upgrade_rate,
		"secret_upgrade_rate": float(secret_upgrades) / upgrades if upgrades > 0 else 0.35,
		"large_power": large_power / large_count if large_count > 0 else 3.0,
		"upgrade_probability": clampf(upgrade_probability, 0.0, 0.90),
	}

func _power_trend(powers: Array[float]) -> float:
	if powers.size() < 3:
		return 0.0
	var split := powers.size() / 2
	var early := 0.0
	var late := 0.0
	for i in split:
		early += powers[i]
	for i in range(split, powers.size()):
		late += powers[i]
	early /= float(split)
	late /= float(powers.size() - split)
	return clampf((late - early) / 4.0, -1.0, 1.0)

func _score_action(action: Dictionary, state: Dictionary, model: Dictionary, probabilities: Array, opponent_upgrade_probability: float) -> Dictionary:
	var factors := {}
	factors.f1 = _expected_outcome(action, probabilities, opponent_upgrade_probability)
	factors.f2 = clampf(float(factors.f1) * float(state.current_gold) / 45.0, 0.0, 1.0)
	factors.f3 = _preservation(action, state)
	factors.f4 = _risk_safety(action, state, probabilities, opponent_upgrade_probability, float(factors.f1))
	factors.f5 = _gold_pressure(action, state)
	factors.f6 = clampf(1.0 - float(state.remaining_gold) / 100.0, 0.0, 1.0)
	factors.f7 = _disguise_value(action, state, model)
	factors.f8 = _diamond_value(action, state, probabilities, opponent_upgrade_probability, float(factors.f1))
	factors.f9 = 0.0
	factors.f10 = _pattern_exploitation(action, state, model, probabilities)
	factors.tactical = _special_bonus(action, state, model, probabilities) + _playbook_bonus(action)
	factors.noise = rng.randf_range(-float(difficulty_config.UtilityNoise), float(difficulty_config.UtilityNoise))
	var weights: Dictionary = personality_config.Weights
	var f2_weight := float(weights.GoldExpectedValue)
	var f3_weight := float(weights.PiecePreservation)
	if float(factors.f6) < 0.30:
		f2_weight *= 0.65
		f3_weight *= 1.30
	elif float(factors.f6) >= 0.70:
		f2_weight *= 1.35
		f3_weight *= 0.65
	var weighted := (
		float(weights.ExpectedWinRate) * float(factors.f1)
		+ f2_weight * float(factors.f2)
		+ f3_weight * float(factors.f3)
		+ float(weights.RiskSafety) * float(factors.f4)
		+ float(weights.GoldPressure) * float(factors.f5)
		+ float(weights.DisguiseValue) * float(factors.f7)
		+ float(weights.DiamondValue) * float(factors.f8)
		+ float(weights.PatternExploitation) * float(factors.f10)
	)
	var total := weighted + float(factors.tactical) + float(factors.noise)
	return {"action": action, "factors": factors, "weighted": weighted, "total": total}

func _expected_outcome(action: Dictionary, probabilities: Array, opponent_upgrade_probability: float) -> float:
	var result := 0.0
	for index in probabilities.size():
		var piece := index
		var normal := GameRules.outcome_utility(action.piece, action.upgrade, piece, GameRules.Upgrade.NONE)
		var upgraded := GameRules.outcome_utility(action.piece, action.upgrade, piece, GameRules.Upgrade.OPEN)
		result += float(probabilities[index]) * lerpf(normal, upgraded, opponent_upgrade_probability)
	return clampf(result, 0.0, 1.0)

func _preservation(action: Dictionary, state: Dictionary) -> float:
	var score := 1.0 - float(GameRules.PRESERVATION[action.piece])
	if GameRules.available_pieces(state.ai_hand).size() <= 2:
		score += 0.10
	if int(state.remaining_gold) <= int(state.current_gold):
		score = 0.75 + float(action.piece) * 0.04
	return clampf(score, 0.0, 1.0)

func _risk_safety(action: Dictionary, state: Dictionary, probabilities: Array, opponent_upgrade_probability: float, expected: float) -> float:
	var risk := 1.0 - expected
	if action.upgrade != GameRules.Upgrade.NONE:
		risk += (1.0 - expected) * 0.18
	if action.piece == GameRules.Piece.GENERAL and int(state.current_gold) >= 30:
		risk += float(probabilities[GameRules.Piece.GENERAL]) * (1.0 - opponent_upgrade_probability) * 0.30
	if action.piece == GameRules.Piece.KING:
		risk += float(probabilities[GameRules.Piece.COMMONER]) * 0.42
	return clampf(1.0 - risk, 0.0, 1.0)

func _gold_pressure(action: Dictionary, state: Dictionary) -> float:
	var pressure := clampf(0.5 + float(int(state.opponent_gold) - int(state.ai_gold)) / 100.0, 0.0, 1.0)
	var aggression := clampf(float(action.piece) / 4.0 + (0.15 if action.upgrade != GameRules.Upgrade.NONE else 0.0), 0.0, 1.0)
	return clampf(pressure * aggression + (1.0 - pressure) * (1.0 - aggression), 0.0, 1.0)

func _disguise_value(action: Dictionary, state: Dictionary, model: Dictionary) -> float:
	if action.piece == action.display:
		return clampf((0.42 + float(model.confidence) * 0.12) * (1.15 - _disguise_bias() * 0.40), 0.0, 1.0)
	var real_strength := float(action.piece) / 4.0
	var display_strength := float(action.display) / 4.0
	var direction := 0.78 if display_strength < real_strength else (0.62 if int(state.ai_gold) >= int(state.opponent_gold) else 0.48)
	var novelty := 1.0 - float(model.disguise_rate) * float(model.confidence) * 0.25
	return clampf(direction * _disguise_bias() * float(difficulty_config.DisguiseRateMultiplier) * novelty, 0.0, 1.0)

func _diamond_value(action: Dictionary, state: Dictionary, probabilities: Array, opponent_upgrade_probability: float, upgraded_outcome: float) -> float:
	var progress := 1.0 - float(state.remaining_gold) / 100.0
	if action.upgrade == GameRules.Upgrade.NONE:
		return clampf(0.78 - progress * 0.50, 0.20, 0.80)
	var plain := action.duplicate()
	plain.upgrade = GameRules.Upgrade.NONE
	var gain := clampf(upgraded_outcome - _expected_outcome(plain, probabilities, opponent_upgrade_probability) + float(state.current_gold) / 90.0, 0.0, 1.0)
	if action.upgrade == GameRules.Upgrade.OPEN:
		gain += 0.16 if personality == GameRules.Personality.AGGRESSIVE else 0.05
	else:
		gain += float(personality_config.SecretUpgradeBias) * 0.12
		if action.piece == GameRules.Piece.COMMONER:
			gain += 0.12
	if progress < 0.30:
		gain -= 0.15
	return clampf(gain, 0.0, 1.0)

func _pattern_exploitation(action: Dictionary, state: Dictionary, model: Dictionary, probabilities: Array) -> float:
	var importance := float(state.current_gold) / 45.0
	var high_chance := float(probabilities[GameRules.Piece.KING]) + float(probabilities[GameRules.Piece.GENERAL])
	var score: float
	if action.piece == GameRules.Piece.COMMONER:
		score = float(probabilities[GameRules.Piece.KING]) * 1.25
	elif action.piece >= GameRules.Piece.GENERAL:
		score = float(model.risk_preference) * importance
	else:
		score = (1.0 - high_chance) * (1.0 - importance)
	return clampf(lerpf(0.5, score, float(model.confidence)), 0.0, 1.0)

func _special_bonus(action: Dictionary, state: Dictionary, model: Dictionary, probabilities: Array) -> float:
	var bonus := 0.0
	var progress := 1.0 - float(state.remaining_gold) / 100.0
	if action.piece == GameRules.Piece.COMMONER and int(state.current_gold) >= 20:
		var king_probability := float(probabilities[GameRules.Piece.KING])
		var reward := float(state.current_gold) / 45.0 + (0.35 if action.upgrade != GameRules.Upgrade.NONE else 0.0)
		if int(state.ai_gold) < int(state.opponent_gold):
			reward += 0.25
		var miss_cost := 0.18 + (0.22 if action.upgrade != GameRules.Upgrade.NONE else 0.0)
		bonus += (king_probability * reward - (1.0 - king_probability) * miss_cost) * float(personality_config.CommonerUpsetBias)
	var leading := int(state.ai_gold) > int(state.opponent_gold)
	if (int(state.current_gold) >= 30 and leading) or (int(state.current_gold) < 30 and progress < 0.35):
		var draw_value := float(probabilities[action.piece]) * float(personality_config.DrawSeekingBias)
		bonus += draw_value * (0.30 if int(state.current_gold) >= 30 else 0.16)
		if action.piece == GameRules.Piece.GENERAL and int(state.current_gold) >= 30:
			bonus -= 0.20
	if personality == GameRules.Personality.CONSERVATIVE:
		if action.piece == GameRules.Piece.SOLDIER and progress < 0.35:
			bonus += 0.10
		if action.piece >= GameRules.Piece.GENERAL:
			bonus -= 0.06
	elif personality == GameRules.Personality.AGGRESSIVE:
		bonus += float(action.piece) / 4.0 * float(personality_config.LargeRoundAggression) * float(state.current_gold) / 45.0 * 0.10
		if int(state.ai_gold) + 20 < int(state.opponent_gold):
			bonus += float(action.piece) / 4.0 * 0.18
	elif personality == GameRules.Personality.DECEPTIVE:
		if action.piece != action.display:
			bonus += 0.08
		if action.upgrade == GameRules.Upgrade.SECRET:
			bonus += 0.08
	if bool(state.get("amnesia", false)):
		bonus += (0.08 if action.piece != action.display else -0.02) * (1.0 - float(model.confidence)) if personality == GameRules.Personality.DECEPTIVE else 0.0
	return bonus

func _disguise_bias() -> float:
	return [0.35, 0.20, 0.95, 0.65][personality]

func _prepare_playbook(state: Dictionary) -> void:
	if difficulty == GameRules.Difficulty.BEGINNER:
		return
	if personality not in [GameRules.Personality.DECEPTIVE, GameRules.Personality.TACTICAL]:
		return
	if not active_playbook.is_empty():
		return
	var chance := float(difficulty_config.ComboExecutionProbability) * (0.80 if personality == GameRules.Personality.DECEPTIVE else 1.0)
	if rng.randf() > chance:
		return
	var books: Array = config.get("Playbooks", [])
	if books.is_empty():
		return
	var chosen_index := 4 if int(state.remaining_gold) <= 40 and books.size() >= 5 else rng.randi_range(0, books.size() - 1)
	active_playbook = books[chosen_index].duplicate(true)
	playbook_step = 0
	playbook_disruptions = 0

func _playbook_bonus(action: Dictionary) -> float:
	if active_playbook.is_empty():
		return 0.0
	var steps: Array = active_playbook.get("Steps", [])
	if playbook_step >= steps.size():
		return 0.0
	var step: Dictionary = steps[playbook_step]
	var matches_piece: bool = action.piece == int(step.PreferredPiece)
	var matches_display: bool = bool(step.AnyDisplayName) or action.display == int(step.PreferredDisplayName)
	var matches_upgrade: bool = bool(step.AnyUpgrade) or action.upgrade == int(step.PreferredUpgrade)
	return float(step.MatchBonus) if matches_piece and matches_display and matches_upgrade else float(step.MissPenalty)

func _advance_playbook(action: Dictionary) -> void:
	if active_playbook.is_empty():
		return
	var steps: Array = active_playbook.get("Steps", [])
	if playbook_step >= steps.size():
		active_playbook.clear()
		return
	var step: Dictionary = steps[playbook_step]
	var matched: bool = action.piece == int(step.PreferredPiece) and (bool(step.AnyDisplayName) or action.display == int(step.PreferredDisplayName)) and (bool(step.AnyUpgrade) or action.upgrade == int(step.PreferredUpgrade))
	if matched:
		playbook_step += 1
		playbook_disruptions = 0
		if playbook_step >= steps.size():
			active_playbook.clear()
	else:
		playbook_disruptions += 1
		if playbook_disruptions >= 2:
			active_playbook.clear()
			playbook_step = 0

func _format_log(state: Dictionary, scored: Array[Dictionary], elapsed_ms: float) -> String:
	var lines: Array[String] = []
	lines.append("=== 百金争夺 AI 决策 ===")
	lines.append("%s / %s | 回合 %d | 金币 %d | %.2fms" % [GameRules.personality_name(personality), GameRules.difficulty_name(difficulty), int(state.round), int(state.current_gold), elapsed_ms])
	for index in mini(scored.size(), 75):
		var row := scored[index]
		var a: Dictionary = row.action
		var f: Dictionary = row.factors
		lines.append("%s/%s/显%s | F1 %.3f F2 %.3f F3 %.3f F4 %.3f F5 %.3f F6 %.3f F7 %.3f F8 %.3f F9 %.3f F10 %.3f 战术 %.3f 噪声 %.3f => %.3f" % [
			GameRules.piece_name(a.piece), GameRules.upgrade_name(a.upgrade), GameRules.piece_name(a.display),
			f.f1, f.f2, f.f3, f.f4, f.f5, f.f6, f.f7, f.f8, f.f9, f.f10, f.tactical, f.noise, row.total])
	return "\n".join(lines)

func _fallback_config() -> Dictionary:
	var weights := [
		{"ExpectedWinRate":0.20,"GoldExpectedValue":0.08,"PiecePreservation":0.20,"RiskSafety":0.25,"GoldPressure":0.05,"DisguiseValue":0.05,"DiamondValue":0.05,"PatternExploitation":0.12},
		{"ExpectedWinRate":0.15,"GoldExpectedValue":0.25,"PiecePreservation":0.05,"RiskSafety":0.05,"GoldPressure":0.15,"DisguiseValue":0.08,"DiamondValue":0.15,"PatternExploitation":0.12},
		{"ExpectedWinRate":0.12,"GoldExpectedValue":0.12,"PiecePreservation":0.08,"RiskSafety":0.10,"GoldPressure":0.10,"DisguiseValue":0.25,"DiamondValue":0.15,"PatternExploitation":0.08},
		{"ExpectedWinRate":0.18,"GoldExpectedValue":0.15,"PiecePreservation":0.12,"RiskSafety":0.15,"GoldPressure":0.10,"DisguiseValue":0.15,"DiamondValue":0.10,"PatternExploitation":0.05},
	]
	var people := []
	for i in 4:
		people.append({"Type":i,"Weights":weights[i],"EarlyProbeBias":0.5,"LargeRoundAggression":1.0,"KingAfterKilledMultiplier":0.8,"SecretUpgradeBias":1.0,"DrawSeekingBias":0.5,"CommonerUpsetBias":1.0})
	return {"Personalities":people,"Difficulties":[
		{"Tier":0,"UtilityNoise":0.30,"DisguiseRateMultiplier":0.30,"ReadingThreshold":0.70,"OpponentHistoryDepth":2,"ComboExecutionProbability":0.10,"AllowSecretUpgrade":false},
		{"Tier":1,"UtilityNoise":0.15,"DisguiseRateMultiplier":0.70,"ReadingThreshold":0.50,"OpponentHistoryDepth":4,"ComboExecutionProbability":0.50,"AllowSecretUpgrade":true},
		{"Tier":2,"UtilityNoise":0.05,"DisguiseRateMultiplier":1.00,"ReadingThreshold":0.35,"OpponentHistoryDepth":9999,"ComboExecutionProbability":0.90,"AllowSecretUpgrade":true}],"Playbooks":[]}
