from __future__ import annotations

import random
from dataclasses import dataclass, field

PIECES = tuple(range(5))
COMMONER, SOLDIER, KNIGHT, GENERAL, KING = PIECES
NONE, OPEN, SECRET = range(3)
# Winner values for online matches are player indexes for real winners.
# DRAW stays aligned with the Godot GameRules.Winner.DRAW value used by the UI.
NO_WINNER = -1
PLAYER_0 = 0
PLAYER_1 = 1
DRAW = 3

CONTRACTS = {
    "standard": {},
    "scarlet_pot": {
        "large_round_threshold": 22,
        "amnesia_gold_threshold": 55,
        "amnesia_chance": 0.68,
    },
    "fractured_oracle": {"initial_readings": 3, "reading_accuracy": 0.60},
    "true_names": {"allow_disguise": False},
    "public_oath": {"allow_secret_upgrade": False},
    "blind_pact": {"initial_readings": 0},
}


def combat_power(piece: int, upgrade: int) -> int:
    return 1 if piece == COMMONER else piece + 1 + int(upgrade != NONE)


def resolve(piece_0: int, upgrade_0: int, piece_1: int, upgrade_1: int) -> dict:
    up_0 = upgrade_0 != NONE
    up_1 = upgrade_1 != NONE
    kills_0 = piece_0 == COMMONER and piece_1 == KING and (not up_1 or up_0)
    kills_1 = piece_1 == COMMONER and piece_0 == KING and (not up_0 or up_1)
    if kills_0 and not kills_1:
        return {"winner": PLAYER_0, "instant_upset": up_0 and up_1, "king_kill": True}
    if kills_1 and not kills_0:
        return {"winner": PLAYER_1, "instant_upset": up_0 and up_1, "king_kill": True}
    power_0 = combat_power(piece_0, upgrade_0)
    power_1 = combat_power(piece_1, upgrade_1)
    if power_0 > power_1:
        return {"winner": PLAYER_0, "instant_upset": False, "king_kill": False}
    if power_1 > power_0:
        return {"winner": PLAYER_1, "instant_upset": False, "king_kill": False}
    return {"winner": DRAW, "instant_upset": False, "king_kill": False}


def generate_round_gold(rng: random.Random, remaining: int, available_rounds: int) -> int:
    if remaining <= 0:
        return 0
    if available_rounds <= 1:
        return min(45, remaining)
    minimum = max(1, remaining - 45 * (available_rounds - 1))
    maximum = min(45, remaining - (available_rounds - 1))
    if minimum > maximum:
        return min(45, remaining)
    value = rng.randint(minimum, maximum)
    if rng.random() < 0.38 and maximum >= 30:
        value = rng.randint(max(30, minimum), maximum)
    return value


@dataclass
class OnlineMatch:
    match_id: str
    players: list[str]
    names: list[str]
    contract_id: str = "standard"
    seed: int = 1
    rng: random.Random = field(init=False)
    round_number: int = 0
    remaining_gold: int = 100
    current_gold: int = 0
    gold: list[int] = field(default_factory=lambda: [0, 0])
    wasted_gold: int = 0
    hands: list[dict[int, dict]] = field(default_factory=list)
    diamond_used: list[bool] = field(default_factory=lambda: [False, False])
    readings_used: list[int] = field(default_factory=lambda: [0, 0])
    shared_readings: int = 2
    intents: list[dict | None] = field(default_factory=lambda: [None, None])
    locked: list[bool] = field(default_factory=lambda: [False, False])
    ready_next: list[bool] = field(default_factory=lambda: [False, False])
    phase: str = "waiting"
    history: list[dict] = field(default_factory=list)
    amnesia_triggered: bool = False
    winner: int = NO_WINNER
    match_over: bool = False

    def __post_init__(self) -> None:
        if self.contract_id not in CONTRACTS:
            self.contract_id = "standard"
        self.rng = random.Random(self.seed)
        self.hands = [self._new_hand(), self._new_hand()]
        self.shared_readings = int(self.rule("initial_readings", 2))

    @staticmethod
    def _new_hand() -> dict[int, dict]:
        return {piece: {"available": True, "banned": False} for piece in PIECES}

    def rule(self, key: str, default):
        return CONTRACTS[self.contract_id].get(key, default)

    def available(self, player: int) -> list[int]:
        return [p for p in PIECES if self.hands[player][p]["available"] and not self.hands[player][p]["banned"]]

    def start_round(self) -> dict:
        if self.match_over:
            raise ValueError("match is over")
        rounds = min(len(self.available(0)), len(self.available(1)))
        if self.remaining_gold <= 0 or rounds <= 0:
            self.finish()
            return self.public_state()
        self.round_number += 1
        self.current_gold = generate_round_gold(self.rng, self.remaining_gold, rounds)
        self.intents = [None, None]
        self.locked = [False, False]
        self.ready_next = [False, False]
        self.readings_used = [0, 0]
        self.phase = "intent"
        return self.public_state()

    def validate_action(self, player: int, action: dict) -> bool:
        try:
            piece = int(action["piece"])
            upgrade = int(action["upgrade"])
            display = int(action["display"])
        except (KeyError, TypeError, ValueError):
            return False
        if piece not in PIECES or display not in PIECES or upgrade not in (NONE, OPEN, SECRET):
            return False
        status = self.hands[player][piece]
        if not status["available"] or status["banned"]:
            return False
        if self.diamond_used[player] and upgrade != NONE:
            return False
        if not self.rule("allow_disguise", True) and display != piece:
            return False
        if not self.rule("allow_secret_upgrade", True) and upgrade == SECRET:
            return False
        return True

    def submit_intent(self, player: int, action: dict) -> bool:
        if self.phase != "intent" or self.intents[player] is not None:
            return False
        if not self.validate_action(player, action):
            return False
        self.intents[player] = {key: int(action[key]) for key in ("piece", "upgrade", "display")}
        if all(intent is not None for intent in self.intents):
            self.phase = "insight"
        return True

    def use_reading(self, player: int) -> dict:
        if self.phase != "insight" or self.shared_readings <= 0 or self.readings_used[player] > 0:
            raise ValueError("reading unavailable")
        opponent = 1 - player
        intent = self.intents[opponent]
        if intent is None:
            raise ValueError("opponent intent unavailable")
        self.shared_readings -= 1
        self.readings_used[player] += 1
        topic = self.rng.randint(0, 1)
        truth = intent["upgrade"] != NONE if topic == 0 else intent["display"] != intent["piece"]
        accuracy = float(self.rule("reading_accuracy", 0.70))
        reported = truth if self.rng.random() < accuracy else not truth
        return {"topic": topic, "reported": reported, "reliability": accuracy}

    def lock_action(self, player: int, replacement: dict | None = None) -> dict | None:
        if self.phase != "insight" or self.locked[player]:
            raise ValueError("lock unavailable")
        if replacement is not None:
            if not self.validate_action(player, replacement):
                raise ValueError("invalid replacement")
            self.intents[player] = {key: int(replacement[key]) for key in ("piece", "upgrade", "display")}
        self.locked[player] = True
        if all(self.locked):
            return self.resolve_round()
        return None

    def resolve_round(self) -> dict:
        actions = [self.intents[0], self.intents[1]]
        assert actions[0] is not None and actions[1] is not None
        for player, action in enumerate(actions):
            self.hands[player][action["piece"]]["available"] = False
            if action["upgrade"] != NONE:
                self.diamond_used[player] = True
        combat = resolve(actions[0]["piece"], actions[0]["upgrade"], actions[1]["piece"], actions[1]["upgrade"])
        result = {
            "round": self.round_number,
            "gold": self.current_gold,
            "actions": actions,
            "winner": combat["winner"],
            "instant_upset": combat["instant_upset"],
            "king_kill": combat["king_kill"],
            "penalties": [],
        }
        self.remaining_gold = max(0, self.remaining_gold - self.current_gold)
        if combat["winner"] in (PLAYER_0, PLAYER_1):
            self.gold[combat["winner"]] += self.current_gold
        else:
            self.wasted_gold += self.current_gold
            self._apply_draw_penalties(result)
        if combat["instant_upset"]:
            loser = 1 - combat["winner"]
            self.gold[loser] = 0
            self.winner = combat["winner"]
            self.match_over = True
        self.history.append(result.copy())
        self._maybe_amnesia(result)
        if self.remaining_gold <= 0 or not self.available(0) or not self.available(1):
            if self.remaining_gold > 0:
                self.wasted_gold += self.remaining_gold
                self.remaining_gold = 0
            self.finish()
        self.phase = "finished" if self.match_over else "resolved"
        return result

    def _apply_draw_penalties(self, result: dict) -> None:
        if self.current_gold < int(self.rule("large_round_threshold", 30)):
            return
        for player in (0, 1):
            choices = [p for p in (KING, GENERAL, KNIGHT) if p in self.available(player)]
            if choices:
                lost = self.rng.choice(choices)
                self.hands[player][lost] = {"available": False, "banned": True}
                result["penalties"].append({"player": player, "piece": lost})

    def _maybe_amnesia(self, result: dict) -> None:
        result["amnesia"] = False
        threshold = int(self.rule("amnesia_gold_threshold", 40))
        chance = float(self.rule("amnesia_chance", 0.55))
        if self.amnesia_triggered or self.remaining_gold >= threshold or len(self.history) < 2:
            return
        if self.rng.random() <= chance:
            self.amnesia_triggered = True
            self.history.pop(self.rng.randrange(0, len(self.history) - 1))
            result["amnesia"] = True

    def finish(self) -> None:
        self.match_over = True
        if self.gold[0] > self.gold[1]:
            self.winner = PLAYER_0
        elif self.gold[1] > self.gold[0]:
            self.winner = PLAYER_1
        else:
            self.winner = DRAW
        self.phase = "finished"

    def public_state(self) -> dict:
        return {
            "match_id": self.match_id,
            "names": self.names,
            "contract_id": self.contract_id,
            "round": self.round_number,
            "remaining_gold": self.remaining_gold,
            "current_gold": self.current_gold,
            "gold": self.gold,
            "wasted_gold": self.wasted_gold,
            "shared_readings": self.shared_readings,
            "phase": self.phase,
            "history": self.history,
            "match_over": self.match_over,
            "winner": self.winner,
        }

    def private_state(self, player: int) -> dict:
        state = self.public_state()
        state.update({
            "player_index": player,
            "hand": self.hands[player],
            "diamond_used": self.diamond_used[player],
            "reading_used_this_round": self.readings_used[player] > 0,
            "intent": self.intents[player],
            "locked": self.locked[player],
            "ready_next": self.ready_next[player],
        })
        return state
