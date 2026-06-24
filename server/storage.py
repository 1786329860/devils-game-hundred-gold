from __future__ import annotations

import json
import sqlite3
import threading
from pathlib import Path


class Storage:
    def __init__(self, path: str) -> None:
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        self.connection = sqlite3.connect(path, check_same_thread=False)
        self.connection.row_factory = sqlite3.Row
        self.lock = threading.Lock()
        with self.connection:
            self.connection.executescript(
                """
                PRAGMA journal_mode=WAL;
                CREATE TABLE IF NOT EXISTS players (
                    player_id TEXT PRIMARY KEY,
                    display_name TEXT NOT NULL,
                    resume_token TEXT NOT NULL UNIQUE,
                    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    last_seen_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    matches INTEGER NOT NULL DEFAULT 0,
                    wins INTEGER NOT NULL DEFAULT 0,
                    rating INTEGER NOT NULL DEFAULT 1000
                );
                CREATE TABLE IF NOT EXISTS matches (
                    match_id TEXT PRIMARY KEY,
                    player_0 TEXT NOT NULL,
                    player_1 TEXT NOT NULL,
                    contract_id TEXT NOT NULL,
                    seed INTEGER NOT NULL,
                    winner INTEGER NOT NULL,
                    gold_0 INTEGER NOT NULL,
                    gold_1 INTEGER NOT NULL,
                    rounds INTEGER NOT NULL,
                    history_json TEXT NOT NULL,
                    finished_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
                );
                """
            )
            columns = {row[1] for row in self.connection.execute("PRAGMA table_info(players)")}
            if "rating" not in columns:
                self.connection.execute("ALTER TABLE players ADD COLUMN rating INTEGER NOT NULL DEFAULT 1000")

    def upsert_player(self, player_id: str, name: str, token: str) -> None:
        with self.lock, self.connection:
            self.connection.execute(
                """INSERT INTO players(player_id, display_name, resume_token)
                VALUES (?, ?, ?)
                ON CONFLICT(player_id) DO UPDATE SET
                    display_name=excluded.display_name,
                    resume_token=excluded.resume_token,
                    last_seen_at=CURRENT_TIMESTAMP""",
                (player_id, name, token),
            )

    def find_by_token(self, token: str):
        with self.lock:
            return self.connection.execute(
                "SELECT player_id, display_name, resume_token FROM players WHERE resume_token=?", (token,)
            ).fetchone()

    def record_match(self, match) -> None:
        with self.lock, self.connection:
            self.connection.execute(
                """INSERT OR IGNORE INTO matches
                (match_id, player_0, player_1, contract_id, seed, winner, gold_0, gold_1, rounds, history_json)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                (
                    match.match_id,
                    match.players[0],
                    match.players[1],
                    match.contract_id,
                    match.seed,
                    match.winner,
                    match.gold[0],
                    match.gold[1],
                    match.round_number,
                    json.dumps(match.history, ensure_ascii=False),
                ),
            )
            ratings = [
                self.connection.execute("SELECT rating FROM players WHERE player_id=?", (player_id,)).fetchone()[0]
                for player_id in match.players
            ]
            expected_0 = 1.0 / (1.0 + 10 ** ((ratings[1] - ratings[0]) / 400.0))
            score_0 = 0.5 if match.winner == 3 else (1.0 if match.winner == 0 else 0.0)
            new_ratings = [round(ratings[0] + 24 * (score_0 - expected_0)), 0]
            new_ratings[1] = ratings[0] + ratings[1] - new_ratings[0]
            for index, player_id in enumerate(match.players):
                won = int(match.winner == index)
                self.connection.execute(
                    "UPDATE players SET matches=matches+1, wins=wins+?, rating=? WHERE player_id=?",
                    (won, new_ratings[index], player_id),
                )

    def player_profile(self, player_id: str) -> dict:
        with self.lock:
            row = self.connection.execute(
                "SELECT display_name, matches, wins, rating FROM players WHERE player_id=?", (player_id,)
            ).fetchone()
        return dict(row) if row else {"display_name": "旅人", "matches": 0, "wins": 0, "rating": 1000}

    def leaderboard(self, limit: int = 50) -> list[dict]:
        with self.lock:
            rows = self.connection.execute(
                "SELECT display_name, matches, wins, rating FROM players WHERE matches > 0 ORDER BY rating DESC, wins DESC LIMIT ?",
                (limit,),
            ).fetchall()
        return [dict(row) for row in rows]

    def stats(self) -> dict:
        with self.lock:
            players = self.connection.execute("SELECT COUNT(*) FROM players").fetchone()[0]
            matches = self.connection.execute("SELECT COUNT(*) FROM matches").fetchone()[0]
        return {"players": players, "matches": matches}
