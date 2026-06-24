extends SceneTree

func _initialize() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var mode := "menu"
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		mode = args[0]
	if mode == "large_game":
		scene.save_data.settings.large_text = true
		scene.call("_apply_settings")
		scene.call("_start_match")
		await process_frame
		await process_frame
	elif mode in ["game", "reveal"]:
		scene.call("_start_match")
		await process_frame
		await process_frame
		if mode == "reveal":
			scene.call("_select_piece", GameRules.Piece.KNIGHT)
			scene.call("_commit_action")
			await create_timer(0.8).timeout
			await process_frame
	elif mode == "setup":
		scene.call("_show_setup")
	elif mode == "tutorial":
		scene.call("show_tutorial")
	elif mode == "settings":
		scene.call("show_settings")
	elif mode == "stats":
		scene.call("show_statistics")
	elif mode == "online_lobby":
		scene.call("show_online_lobby", true)
	elif mode == "online_game":
		var hand := {}
		for piece in GameRules.PIECES:
			hand[str(piece)] = {"available": true, "banned": false}
		scene.online_state = {
			"match_id": "visual-test",
			"names": ["夜行者", "白银赌徒"],
			"contract_id": "fractured_oracle",
			"round": 2,
			"remaining_gold": 71,
			"current_gold": 28,
			"gold": [18, 11],
			"wasted_gold": 0,
			"shared_readings": 2,
			"phase": "insight",
			"history": [],
			"match_over": false,
			"winner": 0,
			"player_index": 0,
			"hand": hand,
			"diamond_used": false,
			"reading_used_this_round": false,
			"intent": {"piece": 2, "upgrade": 0, "display": 2},
			"locked": false,
			"ready_next": false,
		}
		scene.call("_build_online_game_screen")
		scene.call("_online_enter_insight")
	await process_frame
	await create_timer(0.25).timeout
	var image := root.get_texture().get_image()
	var output := "res://qa/%s_capture.png" % mode
	var error := image.save_png(output)
	if error != OK:
		printerr("Unable to save capture: ", error)
		quit(1)
	else:
		print("Saved ", output, " ", image.get_width(), "x", image.get_height())
		quit(0)
