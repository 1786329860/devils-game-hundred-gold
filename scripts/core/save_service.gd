class_name SaveService
extends RefCounted

const PATH := "user://save.json"

static func default_data() -> Dictionary:
	return {
		"settings": {"master_volume": 0.80, "fullscreen": false, "reduced_motion": false, "large_text": false, "high_contrast": false},
		"stats": {"matches": 0, "wins": 0, "losses": 0, "draws": 0, "upsets": 0, "best_gold": 0, "personality_wins": [0, 0, 0, 0]},
		"profile": {"xp": 0, "level": 1, "seals": 0, "win_streak": 0, "best_win_streak": 0, "daily_streak": 0, "best_daily_streak": 0, "last_daily_completed": ""},
		"daily": {"best_date": "", "best_score": -999},
		"achievements": {},
		"online": {"display_name": "旅人", "resume_token": "", "server_url": "wss://tucao.aixiaolv.icu/ws"},
		"tutorial_seen": false,
	}

static func load_data() -> Dictionary:
	var data := default_data()
	if not FileAccess.file_exists(PATH):
		return data
	var file := FileAccess.open(PATH, FileAccess.READ)
	if not file:
		return data
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_merge_dictionary(data, parsed)
	return data

static func save_data(data: Dictionary) -> bool:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if not file:
		return false
	file.store_string(JSON.stringify(data, "  "))
	return true

static func record_match(data: Dictionary, summary: Dictionary) -> void:
	var stats: Dictionary = data.stats
	stats.matches = int(stats.matches) + 1
	match int(summary.winner):
		GameRules.Winner.PLAYER:
			stats.wins = int(stats.wins) + 1
			var personality := int(summary.personality)
			stats.personality_wins[personality] = int(stats.personality_wins[personality]) + 1
		GameRules.Winner.AI:
			stats.losses = int(stats.losses) + 1
		_:
			stats.draws = int(stats.draws) + 1
	if bool(summary.instant_upset) and int(summary.winner) == GameRules.Winner.PLAYER:
		stats.upsets = int(stats.upsets) + 1
	stats.best_gold = maxi(int(stats.best_gold), int(summary.player_gold))
	save_data(data)

static func _merge_dictionary(target: Dictionary, source: Dictionary) -> void:
	for key in source:
		if target.has(key) and target[key] is Dictionary and source[key] is Dictionary:
			_merge_dictionary(target[key], source[key])
		else:
			target[key] = source[key]
