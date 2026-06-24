class_name DialogueEngine
extends RefCounted

enum Event { ROUND_START, PLAY, WIN, LOSE, DRAW, DIAMOND_USED, DISGUISE_EXPOSED, KING_KILLED, LARGE_ROUND, MATCH_WIN, MATCH_LOSE, AMNESIA, READING }

var lines: Array = []
var cooldowns := {}
var rng := RandomNumberGenerator.new()

func _init(seed_value: int = 1) -> void:
	rng.seed = seed_value
	var file := FileAccess.open("res://data/dialogue_zh_cn.json", FileAccess.READ)
	if file:
		var parsed = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			lines = parsed.get("Lines", [])

func reset() -> void:
	cooldowns.clear()

func pick(personality: int, event: int, round_number: int, round_gold: int, gold_difference: int) -> String:
	var eligible: Array = []
	var best_priority := -999
	for entry in lines:
		if int(entry.Personality) != personality or int(entry.Event) != event:
			continue
		if round_gold < int(entry.MinimumRoundGold) or round_gold > int(entry.MaximumRoundGold):
			continue
		if gold_difference < int(entry.MinimumGoldDifferential) or gold_difference > int(entry.MaximumGoldDifferential):
			continue
		var last_round := int(cooldowns.get(entry.Id, -999))
		if round_number - last_round <= int(entry.CooldownRounds):
			continue
		var priority := int(entry.Priority)
		if priority > best_priority:
			eligible.clear()
			best_priority = priority
		if priority == best_priority:
			eligible.append(entry)
	if eligible.is_empty():
		return _fallback_line(personality, event)
	var selected: Dictionary = eligible[rng.randi_range(0, eligible.size() - 1)]
	cooldowns[selected.Id] = round_number
	return str(selected.Text)

func _fallback_line(personality: int, event: int) -> String:
	var defaults := [
		["再谨慎一点……", "这一轮，先观察。", "我接受这个结果。"],
		["来吧！", "金币归我。", "下一轮更重！"],
		["你看到的，是真的吗？", "答案不一定在牌面上。", "猜猜下一步……"],
		["参数已更新。", "行动进入下一节点。", "结果已记录。"],
	]
	return defaults[clampi(personality, 0, 3)][event % 3]

