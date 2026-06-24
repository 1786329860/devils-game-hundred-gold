extends SceneTree

func _initialize() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.call("show_online_lobby", true)
	await process_frame
	if scene.current_screen != "online_lobby":
		printerr("[FAIL] online lobby did not build")
		quit(1)
		return
	var hand := {}
	for piece in GameRules.PIECES:
		hand[str(piece)] = {"available": true, "banned": false}
	scene.online_state = {
		"match_id": "ui-test", "names": ["甲", "乙"], "contract_id": "standard",
		"round": 1, "remaining_gold": 100, "current_gold": 20, "gold": [0, 0],
		"wasted_gold": 0, "shared_readings": 2, "phase": "intent", "history": [],
		"match_over": false, "winner": 0, "player_index": 0, "hand": hand,
		"diamond_used": false, "reading_used_this_round": false, "intent": null,
		"locked": false, "ready_next": false,
	}
	scene.call("_build_online_game_screen")
	await process_frame
	if scene.current_screen != "online_game":
		printerr("[FAIL] online game did not build")
		quit(1)
		return
	print("[PASS] online lobby and match UI build")
	quit(0)
