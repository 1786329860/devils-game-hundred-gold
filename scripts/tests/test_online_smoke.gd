extends SceneTree

const URL := "wss://tucao.aixiaolv.icu/ws"
var peers: Array[WebSocketPeer] = [WebSocketPeer.new(), WebSocketPeer.new()]
var inboxes: Array[Array] = [[], []]

func _initialize() -> void:
	for peer in peers:
		var error := peer.connect_to_url(URL)
		if error != OK:
			return _fail("connect_to_url failed: %s" % error_string(error))
	var connected := await _wait_for_open()
	if not connected:
		return _fail("Godot TLS WebSocket connection timed out")
	_send(0, "hello", {"name": "Godot-Smoke-A", "client_version": "1.1.0"})
	_send(1, "hello", {"name": "Godot-Smoke-B", "client_version": "1.1.0"})
	if (await _wait_for(0, "welcome")).is_empty() or (await _wait_for(1, "welcome")).is_empty():
		return _fail("server welcome not received")
	_send(0, "room_create", {"contract_id": "standard"})
	var room := await _wait_for(0, "room_created")
	if room.is_empty():
		return _fail("room creation failed")
	_send(1, "room_join", {"code": room.code})
	if (await _wait_for(0, "match_started")).is_empty() or (await _wait_for(1, "match_started")).is_empty():
		return _fail("private room did not start a match")
	_send(0, "surrender")
	await _wait_for(1, "match_finished")
	for peer in peers:
		peer.close(1000, "smoke complete")
	print("[PASS] Godot public WSS handshake, private room, match start, surrender")
	quit(0)

func _wait_for_open() -> bool:
	var deadline := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < deadline:
		for peer in peers:
			peer.poll()
		if peers.all(func(peer: WebSocketPeer) -> bool: return peer.get_ready_state() == WebSocketPeer.STATE_OPEN):
			return true
		await process_frame
	return false

func _wait_for(index: int, wanted: String) -> Dictionary:
	var deadline := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < deadline:
		for peer_index in peers.size():
			var peer := peers[peer_index]
			peer.poll()
			while peer.get_available_packet_count() > 0:
				var parsed = JSON.parse_string(peer.get_packet().get_string_from_utf8())
				if parsed is Dictionary:
					inboxes[peer_index].append(parsed)
		for message in inboxes[index]:
			if String(message.get("type", "")) == "error":
				return _fail_dictionary(String(message.get("message", "server error")))
			if String(message.get("type", "")) == wanted:
				inboxes[index].erase(message)
				return message
		await process_frame
	return {}

func _send(index: int, message_type: String, payload: Dictionary = {}) -> void:
	var message := payload.duplicate(true)
	message.type = message_type
	peers[index].send_text(JSON.stringify(message))

func _fail(message: String) -> void:
	printerr("[FAIL] " + message)
	quit(1)

func _fail_dictionary(message: String) -> Dictionary:
	printerr("[FAIL] " + message)
	return {}
