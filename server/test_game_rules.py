import unittest

from game_rules import DRAW, PLAYER_0, OnlineMatch, resolve


class GameRulesTests(unittest.TestCase):
    def test_commoner_upset(self):
        result = resolve(0, 2, 4, 1)
        self.assertEqual(result["winner"], PLAYER_0)
        self.assertTrue(result["instant_upset"])

    def test_two_phase_round(self):
        match = OnlineMatch("m", ["a", "b"], ["A", "B"], "standard", 10)
        match.start_round()
        self.assertTrue(match.submit_intent(0, {"piece": 1, "upgrade": 0, "display": 1}))
        self.assertTrue(match.submit_intent(1, {"piece": 1, "upgrade": 0, "display": 1}))
        self.assertEqual(match.phase, "insight")
        self.assertIsNone(match.lock_action(0))
        result = match.lock_action(1)
        self.assertEqual(result["winner"], DRAW)
        self.assertEqual(match.gold, [0, 0])
        self.assertEqual(match.phase, "resolved")

    def test_non_draw_winner_gets_gold_without_disconnect_bug(self):
        match = OnlineMatch("m", ["a", "b"], ["A", "B"], "standard", 10)
        match.start_round()
        gold = match.current_gold
        self.assertTrue(match.submit_intent(0, {"piece": 4, "upgrade": 0, "display": 4}))
        self.assertTrue(match.submit_intent(1, {"piece": 1, "upgrade": 0, "display": 1}))
        self.assertIsNone(match.lock_action(0))
        result = match.lock_action(1)
        self.assertEqual(result["winner"], PLAYER_0)
        self.assertEqual(match.gold, [gold, 0])
        self.assertEqual(sum(match.gold) + match.wasted_gold + match.remaining_gold, 100)

    def test_contract_enforcement(self):
        match = OnlineMatch("m", ["a", "b"], ["A", "B"], "true_names", 11)
        match.start_round()
        self.assertFalse(match.validate_action(0, {"piece": 1, "upgrade": 0, "display": 4}))
        blind = OnlineMatch("b", ["a", "b"], ["A", "B"], "blind_pact", 12)
        self.assertEqual(blind.shared_readings, 0)

    def test_gold_conservation(self):
        match = OnlineMatch("m", ["a", "b"], ["A", "B"], "standard", 13)
        while not match.match_over:
            match.start_round()
            pieces_0 = match.available(0)
            pieces_1 = match.available(1)
            if not pieces_0 or not pieces_1:
                break
            match.submit_intent(0, {"piece": pieces_0[0], "upgrade": 0, "display": pieces_0[0]})
            match.submit_intent(1, {"piece": pieces_1[0], "upgrade": 0, "display": pieces_1[0]})
            match.lock_action(0)
            match.lock_action(1)
        self.assertEqual(sum(match.gold) + match.wasted_gold, 100)


if __name__ == "__main__":
    unittest.main()
