class_name ProgressionService
extends RefCounted

const XP_PER_LEVEL := 250

static func level_from_xp(xp: int) -> int:
	return maxi(1, floori(float(xp) / float(XP_PER_LEVEL)) + 1)

static func level_progress(xp: int) -> int:
	return posmod(xp, XP_PER_LEVEL)

static func record_result(data: Dictionary, summary: Dictionary, mode: String, daily_date: String = "") -> Dictionary:
	var profile: Dictionary = data.profile
	var previous_level := level_from_xp(int(profile.xp))
	var won := int(summary.winner) == GameRules.Winner.PLAYER
	var draw := int(summary.winner) == GameRules.Winner.DRAW
	var multiplier := float(ContractSystem.get_contract(String(summary.contract_id)).reward_multiplier)
	var xp_reward := 35 + int(summary.player_gold) / 2.0 + int(summary.difficulty) * 20
	if won:
		xp_reward += 60
	elif draw:
		xp_reward += 20
	if bool(summary.instant_upset):
		xp_reward += 40
	var seal_reward := 4 + int(summary.difficulty) * 3 + (10 if won else 0)
	xp_reward = roundi(xp_reward * multiplier)
	seal_reward = roundi(seal_reward * multiplier)

	var daily_first := false
	if mode == "daily":
		daily_first = String(profile.last_daily_completed) != daily_date
		if daily_first:
			var yesterday := _previous_date(daily_date)
			profile.daily_streak = int(profile.daily_streak) + 1 if String(profile.last_daily_completed) == yesterday else 1
			profile.best_daily_streak = maxi(int(profile.best_daily_streak), int(profile.daily_streak))
			profile.last_daily_completed = daily_date
			xp_reward += 75
			seal_reward += 12
		else:
			xp_reward = maxi(10, int(xp_reward / 4.0))
			seal_reward = maxi(1, int(seal_reward / 4.0))
		var score := int(summary.player_gold) - int(summary.ai_gold)
		if String(data.daily.best_date) != daily_date or score > int(data.daily.best_score):
			data.daily.best_date = daily_date
			data.daily.best_score = score

	profile.xp = int(profile.xp) + xp_reward
	profile.seals = int(profile.seals) + seal_reward
	if won:
		profile.win_streak = int(profile.win_streak) + 1
		profile.best_win_streak = maxi(int(profile.best_win_streak), int(profile.win_streak))
	else:
		profile.win_streak = 0
	profile.level = level_from_xp(int(profile.xp))

	var unlocked := _update_achievements(data, summary)
	return {
		"xp": xp_reward,
		"seals": seal_reward,
		"level": int(profile.level),
		"leveled_up": int(profile.level) > previous_level,
		"daily_first": daily_first,
		"unlocked": unlocked,
	}

static func achievement_catalog() -> Array[Dictionary]:
	return [
		{"id": "first_win", "name": "第一份灵魂", "description": "赢得第一场契约。"},
		{"id": "king_slayer", "name": "弑王者", "description": "用平民击杀国王。"},
		{"id": "wealthy", "name": "贪婪之手", "description": "单局获得至少 70 金。"},
		{"id": "mind_reader", "name": "无眼先知", "description": "不使用读牌并赢得对局。"},
		{"id": "hell_winner", "name": "地狱签字人", "description": "击败地狱难度对手。"},
		{"id": "four_faces", "name": "四面皆敌", "description": "击败全部四种 AI 人格。"},
		{"id": "streak_three", "name": "三重契约", "description": "取得三连胜。"},
		{"id": "daily_three", "name": "守夜人", "description": "连续三天完成今日审判。"},
	]

static func _update_achievements(data: Dictionary, summary: Dictionary) -> Array[String]:
	var unlocked: Array[String] = []
	var won := int(summary.winner) == GameRules.Winner.PLAYER
	var conditions := {
		"first_win": won,
		"king_slayer": int(summary.player_king_kills) > 0,
		"wealthy": int(summary.player_gold) >= 70,
		"mind_reader": won and int(summary.player_readings_used) == 0,
		"hell_winner": won and int(summary.difficulty) == GameRules.Difficulty.HELL,
		"four_faces": data.stats.personality_wins.all(func(value: Variant) -> bool: return int(value) > 0),
		"streak_three": int(data.profile.win_streak) >= 3,
		"daily_three": int(data.profile.daily_streak) >= 3,
	}
	for achievement in achievement_catalog():
		var id := String(achievement.id)
		if bool(conditions[id]) and not bool(data.achievements.get(id, false)):
			data.achievements[id] = true
			unlocked.append(String(achievement.name))
	return unlocked

static func _previous_date(date_string: String) -> String:
	var timestamp := Time.get_unix_time_from_datetime_string(date_string + "T00:00:00")
	return Time.get_date_string_from_unix_time(int(timestamp) - 86400)
