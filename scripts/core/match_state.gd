class_name MatchState
extends RefCounted

var rng := RandomNumberGenerator.new()
var round_number := 0
var total_gold := 100
var remaining_gold := 100
var current_round_gold := 0
var player_gold := 0
var ai_gold := 0
var wasted_gold := 0
var player_hand: Dictionary = GameRules.create_hand()
var ai_hand: Dictionary = GameRules.create_hand()
var player_diamond_used := false
var ai_diamond_used := false
var shared_readings_remaining := 2
var player_readings_used := 0
var ai_readings_used := 0
var history: Array[Dictionary] = []
var amnesia_triggered := false
var amnesia_just_triggered := false
var personality := GameRules.Personality.TACTICAL
var difficulty := GameRules.Difficulty.INTERMEDIATE
var match_over := false
var final_winner := GameRules.Winner.NONE
var instant_upset := false
var seed_value := 0
var contract_id := ContractSystem.STANDARD_ID
var large_round_threshold := 30
var reading_accuracy := 0.70
var amnesia_gold_threshold := 40
var amnesia_chance := 0.55
var allow_disguise := true
var allow_open_upgrade := true
var allow_secret_upgrade := true
var player_disguises := 0
var player_king_kills := 0

func _init(seed_override: int = 0) -> void:
	seed_value = seed_override if seed_override != 0 else int(Time.get_unix_time_from_system() * 1000.0) ^ randi()
	rng.seed = seed_value

func reset(new_personality: int, new_difficulty: int, seed_override: int = 0, new_contract_id: String = ContractSystem.STANDARD_ID) -> void:
	round_number = 0
	remaining_gold = 100
	current_round_gold = 0
	player_gold = 0
	ai_gold = 0
	wasted_gold = 0
	player_hand = GameRules.create_hand()
	ai_hand = GameRules.create_hand()
	player_diamond_used = false
	ai_diamond_used = false
	shared_readings_remaining = 2
	player_readings_used = 0
	ai_readings_used = 0
	history.clear()
	amnesia_triggered = false
	amnesia_just_triggered = false
	personality = new_personality
	difficulty = new_difficulty
	match_over = false
	final_winner = GameRules.Winner.NONE
	instant_upset = false
	large_round_threshold = 30
	reading_accuracy = 0.70
	amnesia_gold_threshold = 40
	amnesia_chance = 0.55
	allow_disguise = true
	allow_open_upgrade = true
	allow_secret_upgrade = true
	player_disguises = 0
	player_king_kills = 0
	ContractSystem.apply_to_state(self, new_contract_id)
	seed_value = seed_override if seed_override != 0 else int(Time.get_unix_time_from_system() * 1000.0) ^ randi()
	rng.seed = seed_value

func begin_next_round() -> bool:
	if match_over or remaining_gold <= 0:
		finish_match()
		return false
	var common_rounds := mini(GameRules.available_pieces(player_hand).size(), GameRules.available_pieces(ai_hand).size())
	if common_rounds <= 0:
		wasted_gold += remaining_gold
		remaining_gold = 0
		finish_match()
		return false
	round_number += 1
	current_round_gold = GameRules.generate_round_gold(rng, remaining_gold, common_rounds)
	return true

func public_ai_state() -> Dictionary:
	return {
		"round": round_number,
		"remaining_gold": remaining_gold,
		"current_gold": current_round_gold,
		"ai_gold": ai_gold,
		"opponent_gold": player_gold,
		"ai_hand": ai_hand,
		"ai_diamond_used": ai_diamond_used,
		"opponent_diamond_known_used": player_diamond_used,
		"shared_readings": shared_readings_remaining,
		"history": history.duplicate(true),
		"amnesia": amnesia_triggered,
		"personality": personality,
		"difficulty": difficulty,
		"large_round_threshold": large_round_threshold,
		"reading_accuracy": reading_accuracy,
		"allow_disguise": allow_disguise,
		"allow_open_upgrade": allow_open_upgrade,
		"allow_secret_upgrade": allow_secret_upgrade,
	}

func validate_action(action: Dictionary, is_player: bool) -> bool:
	var hand := player_hand if is_player else ai_hand
	var diamond_used := player_diamond_used if is_player else ai_diamond_used
	if not GameRules.validate_action(hand, diamond_used, action):
		return false
	if not allow_disguise and int(action.display) != int(action.piece):
		return false
	if int(action.upgrade) == GameRules.Upgrade.OPEN and not allow_open_upgrade:
		return false
	if int(action.upgrade) == GameRules.Upgrade.SECRET and not allow_secret_upgrade:
		return false
	return true

func resolve_round(player_action: Dictionary, ai_action: Dictionary) -> Dictionary:
	assert(validate_action(player_action, true))
	assert(validate_action(ai_action, false))
	GameRules.consume_piece(player_hand, player_action.piece)
	GameRules.consume_piece(ai_hand, ai_action.piece)
	if player_action.upgrade != GameRules.Upgrade.NONE:
		player_diamond_used = true
	if ai_action.upgrade != GameRules.Upgrade.NONE:
		ai_diamond_used = true
	if player_action.display != player_action.piece:
		player_disguises += 1

	var combat := GameRules.resolve(ai_action.piece, ai_action.upgrade, player_action.piece, player_action.upgrade)
	var result := {
		"round": round_number,
		"gold": current_round_gold,
		"player_piece": player_action.piece,
		"player_upgrade": player_action.upgrade,
		"player_display": player_action.display,
		"ai_piece": ai_action.piece,
		"ai_upgrade": ai_action.upgrade,
		"ai_display": ai_action.display,
		"winner": combat.winner,
		"instant_upset": combat.instant_upset,
		"king_kill": combat.king_kill,
		"penalties": [],
	}

	remaining_gold = maxi(0, remaining_gold - current_round_gold)
	match combat.winner:
		GameRules.Winner.PLAYER:
			player_gold += current_round_gold
		GameRules.Winner.AI:
			ai_gold += current_round_gold
		GameRules.Winner.DRAW:
			wasted_gold += current_round_gold
			if player_action.piece == GameRules.Piece.GENERAL:
				player_hand[GameRules.Piece.GENERAL].banned = true
			if ai_action.piece == GameRules.Piece.GENERAL:
				ai_hand[GameRules.Piece.GENERAL].banned = true
			_apply_draw_penalties(result)

	if combat.instant_upset:
		instant_upset = true
		if combat.winner == GameRules.Winner.PLAYER:
			ai_gold = 0
		else:
			player_gold = 0
		final_winner = combat.winner
		match_over = true
	if combat.king_kill and combat.winner == GameRules.Winner.PLAYER:
		player_king_kills += 1

	history.append(result.duplicate(true))
	_maybe_apply_amnesia()
	if remaining_gold <= 0 or GameRules.available_pieces(player_hand).is_empty() or GameRules.available_pieces(ai_hand).is_empty():
		if remaining_gold > 0:
			wasted_gold += remaining_gold
			remaining_gold = 0
		finish_match()
	return result

func _apply_draw_penalties(result: Dictionary) -> void:
	if current_round_gold < large_round_threshold:
		return
	var player_high := GameRules.high_available(player_hand)
	var ai_high := GameRules.high_available(ai_hand)
	if not player_high.is_empty():
		var lost: int = player_high[rng.randi_range(0, player_high.size() - 1)]
		GameRules.ban_piece(player_hand, lost)
		result.penalties.append({"side": GameRules.Winner.PLAYER, "piece": lost})
	if not ai_high.is_empty():
		var lost: int = ai_high[rng.randi_range(0, ai_high.size() - 1)]
		GameRules.ban_piece(ai_hand, lost)
		result.penalties.append({"side": GameRules.Winner.AI, "piece": lost})

func _maybe_apply_amnesia() -> void:
	amnesia_just_triggered = false
	if amnesia_triggered or remaining_gold >= amnesia_gold_threshold or history.size() < 2:
		return
	if rng.randf() <= amnesia_chance:
		amnesia_triggered = true
		amnesia_just_triggered = true
		var forgotten_index := rng.randi_range(0, history.size() - 2)
		history.remove_at(forgotten_index)

func finish_match() -> void:
	if match_over and final_winner != GameRules.Winner.NONE:
		return
	match_over = true
	if player_gold > ai_gold:
		final_winner = GameRules.Winner.PLAYER
	elif ai_gold > player_gold:
		final_winner = GameRules.Winner.AI
	else:
		final_winner = GameRules.Winner.DRAW

func use_player_reading() -> Dictionary:
	if shared_readings_remaining <= 0:
		return {}
	shared_readings_remaining -= 1
	player_readings_used += 1
	var topic := rng.randi_range(0, 1)
	var truth: bool
	if topic == 0:
		truth = ai_diamond_used
	else:
		truth = not history.is_empty() and history.back().ai_display != history.back().ai_piece
	var accurate := rng.randf() < reading_accuracy
	return {
		"topic": topic,
		"reported": truth if accurate else not truth,
		"reliability": reading_accuracy,
	}

func serialize() -> Dictionary:
	return {
		"rounds": round_number,
		"player_gold": player_gold,
		"ai_gold": ai_gold,
		"wasted_gold": wasted_gold,
		"winner": final_winner,
		"personality": personality,
		"difficulty": difficulty,
		"instant_upset": instant_upset,
		"seed": seed_value,
		"contract_id": contract_id,
		"player_readings_used": player_readings_used,
		"player_disguises": player_disguises,
		"player_king_kills": player_king_kills,
	}
