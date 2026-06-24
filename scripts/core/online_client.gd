class_name OnlineClient
extends Node

signal connected
signal welcomed(payload: Dictionary)
signal disconnected(reason: String)
signal message_received(payload: Dictionary)

const DEFAULT_URL := "wss://tucao.aixiaolv.icu/ws"
const CLIENT_VERSION := "1.1.1"
const HEARTBEAT_INTERVAL_MS := 20000

var socket := WebSocketPeer.new()
var server_url := DEFAULT_URL
var player_name := "旅人"
var resume_token := ""
var connect_started_ms := 0
var last_heartbeat_ms := 0
var welcomed_by_server := false
var hello_sent := false
var manually_closed := false

func connect_server(name: String, token: String = "", url: String = DEFAULT_URL) -> Error:
	close()
	server_url = url
	player_name = name.strip_edges().left(16)
	if player_name.is_empty():
		player_name = "旅人"
	resume_token = token
	manually_closed = false
	welcome_reset()
	connect_started_ms = Time.get_ticks_msec()
	last_heartbeat_ms = connect_started_ms
	set_process(true)
	return socket.connect_to_url(server_url)

func welcome_reset() -> void:
	welcomed_by_server = false
	hello_sent = false

func close() -> void:
	manually_closed = true
	if socket.get_ready_state() in [WebSocketPeer.STATE_CONNECTING, WebSocketPeer.STATE_OPEN]:
		socket.close(1000, "client closed")
	socket = WebSocketPeer.new()
	set_process(false)

func send_message(message_type: String, payload: Dictionary = {}) -> bool:
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return false
	var message := payload.duplicate(true)
	message.type = message_type
	return socket.send_text(JSON.stringify(message)) == OK

func is_ready() -> bool:
	return socket.get_ready_state() == WebSocketPeer.STATE_OPEN and welcomed_by_server

func _process(_delta: float) -> void:
	socket.poll()
	var state := socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not hello_sent:
			hello_sent = true
			connected.emit()
			send_message("hello", {"name": player_name, "resume_token": resume_token, "client_version": CLIENT_VERSION})
		if welcomed_by_server and Time.get_ticks_msec() - last_heartbeat_ms >= HEARTBEAT_INTERVAL_MS:
			last_heartbeat_ms = Time.get_ticks_msec()
			send_message("ping")
		while socket.get_available_packet_count() > 0:
			var parsed = JSON.parse_string(socket.get_packet().get_string_from_utf8())
			if parsed is not Dictionary:
				continue
			var message: Dictionary = parsed
			if String(message.get("type", "")) == "welcome":
				welcomed_by_server = true
				resume_token = String(message.get("resume_token", ""))
				welcomed.emit(message)
			elif String(message.get("type", "")) == "pong":
				pass
			else:
				message_received.emit(message)
	elif state == WebSocketPeer.STATE_CONNECTING:
		if Time.get_ticks_msec() - connect_started_ms > 12000:
			socket.close(4000, "connect timeout")
	elif state == WebSocketPeer.STATE_CLOSED:
		set_process(false)
		if not manually_closed:
			disconnected.emit(socket.get_close_reason())

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		close()
