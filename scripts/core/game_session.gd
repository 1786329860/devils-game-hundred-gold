class_name GameSession
extends Node

signal match_started
signal round_started(round_number: int, round_gold: int, ai_dialogue: String)
signal player_reading_ready(result: Dictionary)
signal round_resolved(result: Dictionary, ai_dialogue: String)
signal amnesia_triggered(ai_dialogue: String)
signal match_finished(summary: Dictionary, ai_dialogue: String)

var state := MatchState.new()
var ai: UtilityAI
var dialogue: DialogueEngine
var pending_ai_action: Dictionary = {}
var ai_used_reading_this_round := false
var last_ai_decision: Dictionary = {}

func start_match(personality: int, difficulty: int, seed_value: int = 0, contract_id: String = ContractSystem.STANDARD_ID) -> void:
	state.reset(personality, difficulty, seed_value, contract_id)
	ai = UtilityAI.new(personality, difficulty, state.seed_value ^ 0xA17E)
	dialogue = DialogueEngine.new(state.seed_value ^ 0xD1A1)
	match_started.emit()
	begin_round()

func begin_round() -> void:
	if not state.begin_next_round():
		_emit_match_finished()
		return
	ai_used_reading_this_round = false
	var public_state := state.public_ai_state()
	var reading_decision := ai.evaluate_reading(public_state)
	if reading_decision.should_read and state.shared_readings_remaining > 0:
		state.shared_readings_remaining -= 1
		state.ai_readings_used += 1
		ai_used_reading_this_round = true
		public_state.shared_readings = state.shared_readings_remaining
		public_state.last_reading = _create_ai_pattern_reading()
	last_ai_decision = ai.decide_action(public_state)
	pending_ai_action = last_ai_decision.action.duplicate(true)
	var event := DialogueEngine.Event.LARGE_ROUND if state.current_round_gold >= state.large_round_threshold else DialogueEngine.Event.ROUND_START
	var line := dialogue.pick(state.personality, event, state.round_number, state.current_round_gold, state.ai_gold - state.player_gold)
	round_started.emit(state.round_number, state.current_round_gold, line)

func can_player_read() -> bool:
	return not pending_ai_action.is_empty() and state.shared_readings_remaining > 0 and not state.match_over

func use_player_reading() -> Dictionary:
	if not can_player_read():
		return {}
	state.shared_readings_remaining -= 1
	state.player_readings_used += 1
	var topic := state.rng.randi_range(0, 1)
	var truth: bool = pending_ai_action.upgrade != GameRules.Upgrade.NONE if topic == 0 else pending_ai_action.display != pending_ai_action.piece
	var accurate := state.rng.randf() < state.reading_accuracy
	var result := {"topic": topic, "reported": truth if accurate else not truth, "reliability": state.reading_accuracy}
	player_reading_ready.emit(result)
	return result

func submit_player_action(action: Dictionary) -> Dictionary:
	if pending_ai_action.is_empty() or state.match_over:
		return {}
	if not state.validate_action(action, true):
		push_error("玩家行动非法。")
		return {}
	var result := state.resolve_round(action, pending_ai_action)
	result.ai_used_reading = ai_used_reading_this_round
	result.ai_decision_ms = last_ai_decision.get("elapsed_ms", 0.0)
	result.ai_playbook = last_ai_decision.get("playbook", "")
	result.ai_log = last_ai_decision.get("log", "")
	pending_ai_action.clear()
	var event: int
	match int(result.winner):
		GameRules.Winner.AI: event = DialogueEngine.Event.WIN
		GameRules.Winner.PLAYER: event = DialogueEngine.Event.LOSE
		_: event = DialogueEngine.Event.DRAW
	if bool(result.king_kill):
		event = DialogueEngine.Event.KING_KILLED
	var line := dialogue.pick(state.personality, event, state.round_number, state.current_round_gold, state.ai_gold - state.player_gold)
	round_resolved.emit(result, line)
	if state.amnesia_just_triggered:
		var amnesia_line := dialogue.pick(state.personality, DialogueEngine.Event.AMNESIA, state.round_number, state.current_round_gold, state.ai_gold - state.player_gold)
		amnesia_triggered.emit(amnesia_line)
	if state.match_over:
		_emit_match_finished()
	return result

func _create_ai_pattern_reading() -> Dictionary:
	var topic := state.rng.randi_range(0, 1)
	var truth: bool = false
	if not state.history.is_empty():
		var previous: Dictionary = state.history.back()
		truth = previous.player_upgrade != GameRules.Upgrade.NONE if topic == 0 else previous.player_display != previous.player_piece
	var accurate := state.rng.randf() < state.reading_accuracy
	return {"topic": topic, "reported": truth if accurate else not truth, "reliability": state.reading_accuracy}

func _emit_match_finished() -> void:
	if not state.match_over:
		state.finish_match()
	var summary := state.serialize()
	var event := DialogueEngine.Event.MATCH_WIN if state.final_winner == GameRules.Winner.AI else DialogueEngine.Event.MATCH_LOSE
	if state.final_winner == GameRules.Winner.DRAW:
		event = DialogueEngine.Event.DRAW
	var line := dialogue.pick(state.personality, event, state.round_number, 0, state.ai_gold - state.player_gold)
	match_finished.emit(summary, line)
