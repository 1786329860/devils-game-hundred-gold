import sqlite3

connection = sqlite3.connect("/data/devils_game.db")
player_ids = [
    row[0]
    for row in connection.execute(
        "SELECT player_id FROM players WHERE display_name LIKE 'E2E-%' OR display_name LIKE 'Godot-Smoke-%' OR display_name LIKE 'Godot-Heartbeat%'"
    )
]
if player_ids:
    placeholders = ",".join("?" for _ in player_ids)
    connection.execute(
        f"DELETE FROM matches WHERE player_0 IN ({placeholders}) OR player_1 IN ({placeholders})",
        player_ids + player_ids,
    )
    connection.execute(f"DELETE FROM players WHERE player_id IN ({placeholders})", player_ids)
connection.commit()
print({"removed_test_players": len(player_ids)})
