class_name ContractSystem
extends RefCounted

const STANDARD_ID := "standard"

const CONTRACTS: Array[Dictionary] = [
	{
		"id": STANDARD_ID,
		"name": "原初契约",
		"short": "标准规则",
		"description": "完整保留百金争夺的标准规则，适合学习与稳定竞技。",
		"reward_multiplier": 1.0,
	},
	{
		"id": "scarlet_pot",
		"name": "血色金池",
		"short": "更早失控",
		"description": "22 金即算大额轮；剩余 55 金后可能失忆。高收益伴随高波动。",
		"large_round_threshold": 22,
		"amnesia_gold_threshold": 55,
		"amnesia_chance": 0.68,
		"reward_multiplier": 1.35,
	},
	{
		"id": "fractured_oracle",
		"name": "破碎预言",
		"short": "三次六成读牌",
		"description": "共享读牌增至 3 次，但可信度降至 60%。更多情报，也有更多疑心。",
		"initial_readings": 3,
		"reading_accuracy": 0.60,
		"reward_multiplier": 1.20,
	},
	{
		"id": "true_names",
		"name": "真名戒律",
		"short": "双方禁止伪装",
		"description": "所有棋子必须展示真名。博弈转向钻石时机、留牌与反向预判。",
		"allow_disguise": false,
		"reward_multiplier": 1.25,
	},
	{
		"id": "public_oath",
		"name": "白昼誓约",
		"short": "钻石只能明牌",
		"description": "双方仍可伪装，但钻石升级必须公开宣告。谎言会变得更精细。",
		"allow_secret_upgrade": false,
		"reward_multiplier": 1.20,
	},
	{
		"id": "blind_pact",
		"name": "盲眼契约",
		"short": "禁用全部读牌",
		"description": "共享读牌归零，只能依靠公开历史、下注节奏和对手人格推理。",
		"initial_readings": 0,
		"reward_multiplier": 1.40,
	},
]

static func all() -> Array[Dictionary]:
	return CONTRACTS.duplicate(true)

static func get_contract(contract_id: String) -> Dictionary:
	for contract in CONTRACTS:
		if String(contract.id) == contract_id:
			return contract.duplicate(true)
	return CONTRACTS[0].duplicate(true)

static func apply_to_state(state: MatchState, contract_id: String) -> void:
	var contract := get_contract(contract_id)
	state.contract_id = String(contract.id)
	state.large_round_threshold = int(contract.get("large_round_threshold", 30))
	state.reading_accuracy = float(contract.get("reading_accuracy", 0.70))
	state.shared_readings_remaining = int(contract.get("initial_readings", 2))
	state.amnesia_gold_threshold = int(contract.get("amnesia_gold_threshold", 40))
	state.amnesia_chance = float(contract.get("amnesia_chance", 0.55))
	state.allow_disguise = bool(contract.get("allow_disguise", true))
	state.allow_open_upgrade = bool(contract.get("allow_open_upgrade", true))
	state.allow_secret_upgrade = bool(contract.get("allow_secret_upgrade", true))

static func daily_configuration(date_string: String) -> Dictionary:
	var seed_value := absi(date_string.hash() * 7919 + 0x6D2B79F5)
	var challenge_contracts := CONTRACTS.slice(1)
	var contract: Dictionary = challenge_contracts[posmod(seed_value, challenge_contracts.size())]
	return {
		"date": date_string,
		"seed": seed_value,
		"contract_id": String(contract.id),
		"personality": posmod(int(seed_value / 7), 4),
		"difficulty": GameRules.Difficulty.INTERMEDIATE if posmod(seed_value, 3) != 0 else GameRules.Difficulty.HELL,
	}
