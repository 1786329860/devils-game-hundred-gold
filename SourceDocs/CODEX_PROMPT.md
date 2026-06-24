# Codex Task Prompt: AI Utility System for "Devil's Game: Battle for Hundred Gold"

> This file is the complete task specification for Codex. Copy the content below and feed it directly to Codex as your prompt.
> The design document (AI_System_Design.md) should be placed in the same repository so Codex can reference it.

---

## Instructions for Codex

### Your Role

You are implementing the complete AI decision system for a Unity C# game called "Devil's Game: Battle for Hundred Gold" (恶魔游戏：百金争夺). This is NOT a prototype or demo — it is production-ready code for a game that will ship on Steam. Write clean, maintainable, well-structured code with proper separation of concerns.

### Game Overview

This is a 1v1 turn-based psychological warfare card game. The player faces an AI opponent across multiple rounds. Each round, both sides secretly play a piece (card), and the higher-power piece wins that round's gold. The game's core tension comes from bluffing, deception, and mind games — not raw power.

### Complete Game Rules

**Setup:**
- 1v1 match, total gold pool = 100 coins, distributed across multiple rounds (random amounts per round, 1-45 per round)
- Each side starts with: 5 Owl pieces (one-use each, permanently consumed after play) + 1 Diamond (one-use, global)
- Piece hierarchy: King > General > Knight > Soldier > Commoner
- Special counter: Commoner kills King (both normal and upgraded versions)

**Piece-Specific Rules:**
- King: Highest power. Vulnerable to Commoner.
- General: Second highest. If the round ends in a draw, the General is permanently banned (not just consumed — banned AND wasted).
- Knight: No special drawback. Core piece for probing and bluffing.
- Soldier: Lowest combat power. No penalty for draws. Used for early probing.
- Commoner: Normally weakest. Can kill any King. Upgraded Commoner (Tier-2 Commoner) can kill any King including Tier-2 King.

**Diamond Rules:**
- Can upgrade any played piece by one tier
- Upgrading King → Tier-2 King (beats everything except Tier-2 Commoner)
- Upgrading Commoner → Tier-2 Commoner (only beats Kings, loses to everything else)
- Two usage modes:
  - Open Upgrade: Announced before reveal, opponent sees it
  - Secret Upgrade: Hidden until reveal, opponent doesn't know

**Bluff/Disguise System:**
- Before playing, each side can set a "display name" for their piece (can be any piece name)
- Opponent only sees the disguise name until reveal
- Both sides play simultaneously (dark cards), then reveal

**Reading (Scouting) System:**
- 2 shared reading chances per match (both sides share the same pool of 2)
- Using a reading gives fuzzy info: "opponent used diamond?" / "opponent used disguise?"
- 70% accuracy, 30% misleading

**Draw Rules:**
- If both pieces have equal power → draw → gold is wasted
- Small round draw (<30 gold): no penalty
- Large round draw (≥30 gold): each side randomly loses one high-tier piece (King/General/Knight)

**Amnesia Debuff:**
- When remaining gold < 40, randomly triggers. Each side loses 1 historical play record.

**Win Condition:**
- When all 100 gold is distributed, whoever has more gold wins
- Instant Win (Upset): If Tier-2 Commoner beats Tier-2 King, the Commoner's owner instantly wins (opponent loses ALL gold)

**Round Flow:**
1. System reveals this round's gold amount
2. Optional: use reading chance
3. Choose piece, set disguise, decide diamond usage
4. Both sides reveal simultaneously
5. Resolve: winner takes gold, used pieces consumed, draw penalties applied
6. Repeat until all gold distributed

---

### What To Build

Read the detailed AI system design in `AI_System_Design.md` in the repository. Implement the complete system described there. Here is a summary of what "complete" means:

**Core Systems:**

1. **Game State Model** — Data structures representing the full game state (what AI can see). Strict information boundary: AI must NEVER access player's hidden hand, disguise choice, or diamond decision.

2. **Utility Scoring Engine** — The core evaluation loop. For each candidate action (piece + upgrade mode + disguise combination), compute a weighted utility score across all factors described in the design doc. The 10 evaluation factors, their formulas, and how they interact are all documented there.

3. **AI Personality System** — 4 personalities (Conservative, Aggressive, Deceptive, Tactical), each with different weight configurations and behavioral modifiers. Personality affects not just weights but also special behaviors (e.g., Deceptive AI executes multi-round combo plays, Tactical AI follows scripted playbooks).

4. **Difficulty System** — 3 tiers (Beginner, Intermediate, Hell) that modify execution precision via noise, not strategy. Include the specific parameters from the design doc (noise ranges, disguise rate modifiers, combo execution probability, etc.).

5. **Opponent Behavior Model** — AI tracks and models the player's behavior over the course of a match. Statistics tracking, pattern detection, confidence levels. This model feeds into the utility evaluation (Factor F10).

6. **Special Decision Modules:**
   - Reading decision (when to use scouting)
   - Commoner-kingkill evaluation (when to gamble on the upset)
   - Draw-seeking strategy (when and how to force a draw)
   - Amnesia adaptation (how to cope with lost information)

7. **Scripted Playbooks (for Tactical AI)** — At least 5 pre-defined multi-round tactical sequences (fishing, bluff-drain, diamond-feint, general-assault, endgame-harvest), with fallback logic when the script is disrupted.

8. **Dialogue System** — Per-personality dialogue lines triggered by game events. Each personality has distinct speech style. Lines are stored in data (not hardcoded) and support cooldown/priority/conditions.

**Architecture Requirements:**

- Use ScriptableObject or JSON config files for all tunable parameters (weights, thresholds, personality configs, dialogue lines). A game designer should be able to tweak AI behavior WITHOUT touching code.
- Clean separation: GameState → Evaluator → DecisionMaker → ActionExecutor. The AI brain should be testable in isolation without any Unity MonoBehaviour dependencies (use plain C# classes for core logic, wrap with a MonoBehaviour adapter for Unity integration).
- Logging: Every decision should produce a readable log showing all candidates, their scores per factor, and the final selection. This is critical for debugging and balancing.
- Performance: Full decision cycle must complete in <500ms. Use lookup tables for piece matchup results.

**What I'm leaving to your judgment:**

- Exact C# architecture patterns (you choose: interfaces, abstract classes, strategy pattern, etc.)
- How to structure the evaluation pipeline (sequential, parallel, cached)
- How to represent and serialize configs (ScriptableObject vs JSON vs hybrid)
- Naming conventions and file organization within the AI module
- How to implement the opponent probability estimation (Bayesian, heuristic, or hybrid)
- Specific mathematical formulations where the design doc gives a range or guideline rather than an exact formula

---

### Project Context

- Engine: Unity (C#)
- Target: Standalone Windows (Steam)
- Team: 1-2 person indie
- This AI system is one module in a larger game. Design it to be self-contained and integratable.
- No networking, no multiplayer, no monetization systems — this task is purely the single-player AI brain.

---

### Quality Standards

- Production-ready: proper null checks, edge case handling, no TODOs or placeholder logic
- Well-commented in Chinese (zh-CN) — the game's dev team is Chinese
- XML documentation on all public APIs
- Unit-testable core logic (provide at least a test harness or example test cases)
- No external dependencies beyond Unity standard libraries (DOTween, etc. are NOT needed for AI logic)

---

### Deliverables

1. Complete C# source files for the AI system
2. ScriptableObject/JSON config files for all 4 personalities × 3 difficulties
3. Dialogue data file (with sample lines for each personality, in Chinese)
4. A brief README.md (in Chinese) explaining the file structure, how to integrate into a Unity project, and how to tune parameters
5. Example usage: a simple MonoBehaviour script showing how to initialize and call the AI system in a game loop

---

### File Structure Suggestion

You may organize differently if you have a better approach, but here's a reasonable starting point:

```
Assets/Scripts/AI/
├── Core/                  # Core utility system engine
├── Data/                  # Game state models, piece definitions
├── Personalities/         # Personality configs and modifiers
├── Strategy/              # Special decision modules, playbooks
├── Model/                 # Opponent behavior model
├── Dialogue/              # Dialogue system
├── Config/                # ScriptableObject / JSON configs
├── Logging/               # Decision logging
├── Integration/           # Unity MonoBehaviour wrappers
└── README.md
```

---

### Important Notes

- The AI must feel "human" — it should make plausible mistakes at lower difficulties, show personality through its choices, and occasionally surprise the player.
- The most important gameplay moment is the "Commoner Upset" (平民弑王). The AI should create situations where this can happen (both for and against the player) at a dramatically satisfying rate — not too often (loses impact) and not too rarely (players miss the best moment).
- Deceptive AI is the most complex personality. Its multi-round combos need to work as coherent sequences, not just random actions. Take extra care here.
- The reading system's 70/30 accuracy means AI must handle uncertain information gracefully — don't let AI treat reading results as facts.
- Test your implementation mentally against the scenarios in Section 十 of the design doc before considering it complete.
