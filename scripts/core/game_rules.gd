class_name GameRules
extends RefCounted

enum Piece { COMMONER, SOLDIER, KNIGHT, GENERAL, KING }
enum Upgrade { NONE, OPEN, SECRET }
enum Winner { NONE, PLAYER, AI, DRAW }
enum Personality { CONSERVATIVE, AGGRESSIVE, DECEPTIVE, TACTICAL }
enum Difficulty { BEGINNER, INTERMEDIATE, HELL }

const PIECES: Array[int] = [Piece.COMMONER, Piece.SOLDIER, Piece.KNIGHT, Piece.GENERAL, Piece.KING]
const PIECE_NAMES := {
	Piece.COMMONER: "平民",
	Piece.SOLDIER: "士兵",
	Piece.KNIGHT: "骑士",
	Piece.GENERAL: "将军",
	Piece.KING: "国王",
}
const PIECE_SHORT := {
	Piece.COMMONER: "民",
	Piece.SOLDIER: "兵",
	Piece.KNIGHT: "骑",
	Piece.GENERAL: "将",
	Piece.KING: "王",
}
const PIECE_DESCRIPTIONS := {
	Piece.COMMONER: "常规战力最低，却能弑杀国王。升级后可击杀二级国王并触发绝杀。",
	Piece.SOLDIER: "低战力、无额外代价，适合试探和虚张声势。",
	Piece.KNIGHT: "稳定的中坚棋子，没有特殊负面规则。",
	Piece.GENERAL: "仅次于国王；若与对手打平，会额外触发封禁警告。",
	Piece.KING: "常规最强棋子，但会被平民反杀。",
}
const PIECE_COLORS := {
	Piece.COMMONER: Color("#8d8371"),
	Piece.SOLDIER: Color("#758c9d"),
	Piece.KNIGHT: Color("#8b78ad"),
	Piece.GENERAL: Color("#b66f4d"),
	Piece.KING: Color("#c9a44b"),
}
const PRESERVATION := {
	Piece.COMMONER: 0.50,
	Piece.SOLDIER: 0.25,
	Piece.KNIGHT: 0.55,
	Piece.GENERAL: 0.70,
	Piece.KING: 0.85,
}

static func piece_name(piece: int) -> String:
	return PIECE_NAMES.get(piece, "未知")

static func upgrade_name(upgrade: int) -> String:
	match upgrade:
		Upgrade.OPEN: return "明牌升级"
		Upgrade.SECRET: return "暗牌升级"
		_: return "不升级"

static func personality_name(value: int) -> String:
	return ["保守型", "激进型", "欺诈型", "套路型"][clampi(value, 0, 3)]

static func difficulty_name(value: int) -> String:
	return ["入门", "进阶", "地狱"][clampi(value, 0, 2)]

static func resolve(ai_piece: int, ai_upgrade: int, player_piece: int, player_upgrade: int) -> Dictionary:
	var ai_up := ai_upgrade != Upgrade.NONE
	var player_up := player_upgrade != Upgrade.NONE
	var ai_kills_king := ai_piece == Piece.COMMONER and player_piece == Piece.KING and (not player_up or ai_up)
	var player_kills_king := player_piece == Piece.COMMONER and ai_piece == Piece.KING and (not ai_up or player_up)
	if ai_kills_king and not player_kills_king:
		return {"winner": Winner.AI, "instant_upset": ai_up and player_up, "king_kill": true}
	if player_kills_king and not ai_kills_king:
		return {"winner": Winner.PLAYER, "instant_upset": player_up and ai_up, "king_kill": true}

	var ai_power := combat_power(ai_piece, ai_upgrade)
	var player_power := combat_power(player_piece, player_upgrade)
	if ai_power > player_power:
		return {"winner": Winner.AI, "instant_upset": false, "king_kill": false}
	if player_power > ai_power:
		return {"winner": Winner.PLAYER, "instant_upset": false, "king_kill": false}
	return {"winner": Winner.DRAW, "instant_upset": false, "king_kill": false}

static func combat_power(piece: int, upgrade: int) -> int:
	# 平民升级只加强弑王能力，不让它跨阶碾压普通棋子。
	if piece == Piece.COMMONER:
		return 1
	return piece + 1 + (1 if upgrade != Upgrade.NONE else 0)

static func outcome_utility(ai_piece: int, ai_upgrade: int, opponent_piece: int, opponent_upgrade: int) -> float:
	var result := resolve(ai_piece, ai_upgrade, opponent_piece, opponent_upgrade)
	match result.winner:
		Winner.AI: return 1.0
		Winner.DRAW: return 0.3
		_: return 0.0

static func create_hand() -> Dictionary:
	var hand := {}
	for piece in PIECES:
		hand[piece] = {"available": true, "banned": false}
	return hand

static func available_pieces(hand: Dictionary) -> Array[int]:
	var result: Array[int] = []
	for piece in PIECES:
		if hand.has(piece) and hand[piece].available and not hand[piece].banned:
			result.append(piece)
	return result

static func high_available(hand: Dictionary) -> Array[int]:
	var result: Array[int] = []
	for piece in [Piece.KING, Piece.GENERAL, Piece.KNIGHT]:
		if hand.has(piece) and hand[piece].available and not hand[piece].banned:
			result.append(piece)
	return result

static func consume_piece(hand: Dictionary, piece: int) -> void:
	if hand.has(piece):
		hand[piece].available = false

static func ban_piece(hand: Dictionary, piece: int) -> void:
	if hand.has(piece):
		hand[piece].available = false
		hand[piece].banned = true

static func generate_round_gold(rng: RandomNumberGenerator, remaining_gold: int, available_rounds: int) -> int:
	if remaining_gold <= 0:
		return 0
	if available_rounds <= 1:
		return mini(45, remaining_gold)
	var minimum := maxi(1, remaining_gold - 45 * (available_rounds - 1))
	var maximum := mini(45, remaining_gold - (available_rounds - 1))
	if minimum > maximum:
		return mini(45, remaining_gold)
	# 混合小额试探与大额决胜，避免每局都均匀分布。
	var value := rng.randi_range(minimum, maximum)
	if rng.randf() < 0.38 and maximum >= 30:
		value = rng.randi_range(maxi(30, minimum), maximum)
	return value

static func validate_action(hand: Dictionary, diamond_used: bool, action: Dictionary) -> bool:
	if not action.has("piece") or not action.has("upgrade") or not action.has("display"):
		return false
	var piece: int = action.piece
	if not hand.has(piece) or not hand[piece].available or hand[piece].banned:
		return false
	if diamond_used and action.upgrade != Upgrade.NONE:
		return false
	return action.display in PIECES

