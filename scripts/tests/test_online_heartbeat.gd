extends SceneTree

const OnlineClientScript := preload("res://scripts/core/online_client.gd")

var client
var welcomed := false
var disconnected := false

func _initialize() -> void:
	client = OnlineClientScript.new()
	root.add_child(client)
	client.welcomed.connect(func(_payload: Dictionary) -> void: welcomed = true)
	client.disconnected.connect(func(_reason: String) -> void: disconnected = true)
	var error: Error = client.connect_server("Godot-Heartbeat")
	if error != OK:
		printerr("[FAIL] connect_server failed: " + error_string(error))
		quit(1)
		return
	var deadline := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < deadline and not welcomed and not disconnected:
		await process_frame
	if not welcomed:
		printerr("[FAIL] welcome not received")
		quit(1)
		return
	await create_timer(25.0).timeout
	if disconnected or not client.is_ready():
		printerr("[FAIL] online client disconnected during heartbeat window")
		quit(1)
		return
	client.close()
	print("[PASS] online client heartbeat kept WSS connection open")
	quit(0)
