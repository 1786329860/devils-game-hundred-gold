extends Node

const OnlineClientScript := preload("res://scripts/core/online_client.gd")

var save_data: Dictionary
var root: Control
var backdrop: BackgroundArt
var content: MarginContainer
var session: GameSession
var online
var audio: AudioFeedback
var current_screen := ""
var setup_personality := GameRules.Personality.TACTICAL
var setup_difficulty := GameRules.Difficulty.INTERMEDIATE
var setup_contract_id := ContractSystem.STANDARD_ID
var game_mode := "standard"
var daily_date := ""
var last_progression_result: Dictionary = {}
var selected_piece := -1
var pending_summary: Dictionary = {}
var summary_recorded := false
var round_locked := false

# 对局界面引用
var score_label: Label
var round_label: Label
var pool_label: Label
var reading_label: Label
var pot_label: Label
var dialogue_label: Label
var ai_card_title: Label
var ai_card_detail: Label
var player_hand_box: HBoxContainer
var selected_detail: RichTextLabel
var disguise_option: OptionButton
var upgrade_option: OptionButton
var reading_button: Button
var commit_button: Button
var result_panel: PanelContainer
var result_title: Label
var result_detail: Label
var next_button: Button
var history_box: VBoxContainer
var debug_label: Label
var ai_status_label: Label

# 联机大厅与对局引用
var online_status_label: Label
var online_name_input: LineEdit
var online_contract_option: OptionButton
var online_room_input: LineEdit
var online_action_buttons: Array[Button] = []
var online_state: Dictionary = {}
var online_selected_piece := -1
var online_intent: Dictionary = {}
var online_score_label: Label
var online_phase_label: Label
var online_pot_label: Label
var online_reading_label: Label
var online_opponent_label: Label
var online_hand_box: HBoxContainer
var online_selected_detail: Label
var online_disguise_option: OptionButton
var online_upgrade_option: OptionButton
var online_read_button: Button
var online_primary_button: Button
var online_result_panel: PanelContainer
var online_result_title: Label
var online_result_detail: Label
var online_history_box: VBoxContainer

func _ready() -> void:
	save_data = SaveService.load_data()
	session = GameSession.new()
	add_child(session)
	online = OnlineClientScript.new()
	add_child(online)
	online.welcomed.connect(_on_online_welcomed)
	online.disconnected.connect(_on_online_disconnected)
	online.message_received.connect(_on_online_message)
	audio = AudioFeedback.new()
	add_child(audio)
	_connect_session()
	_build_shell()
	_apply_settings()
	show_main_menu()

func _connect_session() -> void:
	session.round_started.connect(_on_round_started)
	session.player_reading_ready.connect(_on_player_reading_ready)
	session.round_resolved.connect(_on_round_resolved)
	session.amnesia_triggered.connect(_on_amnesia)
	session.match_finished.connect(_on_match_finished)

func _build_shell() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = ThemeFactory.create_theme(bool(save_data.settings.large_text), bool(save_data.settings.high_contrast))
	add_child(root)
	var background_texture := TextureRect.new()
	background_texture.texture = load("res://assets/art/contract_table_background.png")
	background_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background_texture.modulate = Color(0.64, 0.61, 0.67, 0.72)
	background_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background_texture)
	backdrop = BackgroundArt.new()
	backdrop.high_contrast = bool(save_data.settings.high_contrast)
	root.add_child(backdrop)
	content = MarginContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_theme_constant_override("margin_left", 42)
	content.add_theme_constant_override("margin_right", 42)
	content.add_theme_constant_override("margin_top", 30)
	content.add_theme_constant_override("margin_bottom", 30)
	root.add_child(content)

func _apply_settings() -> void:
	var settings: Dictionary = save_data.settings
	audio.set_master_volume(float(settings.master_volume))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if bool(settings.fullscreen) else DisplayServer.WINDOW_MODE_WINDOWED)
	if root:
		root.theme = ThemeFactory.create_theme(bool(settings.large_text), bool(settings.high_contrast))
	if backdrop:
		backdrop.high_contrast = bool(settings.high_contrast)
		backdrop.queue_redraw()

func _set_screen(name: String, node: Control) -> void:
	current_screen = name
	for child in content.get_children():
		child.queue_free()
	content.add_child(node)

func show_main_menu() -> void:
	pending_summary.clear()
	last_progression_result.clear()
	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 16)
	var spacer_top := Control.new()
	spacer_top.custom_minimum_size.y = 18
	layout.add_child(spacer_top)
	var eyebrow := _label("一 场 关于 谎 言 与 贪 婪 的 契 约", 16, ThemeFactory.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	layout.add_child(eyebrow)
	var title := _label("恶魔游戏", 66, ThemeFactory.GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_constant_override("outline_size", 8)
	layout.add_child(title)
	var subtitle := _label("百 金 争 夺", 34, ThemeFactory.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	layout.add_child(subtitle)
	var rule := HSeparator.new()
	rule.custom_minimum_size.x = 460
	rule.add_theme_color_override("separator", Color(ThemeFactory.GOLD, 0.55))
	layout.add_child(rule)
	var tagline := _label("五枚棋子。一枚钻石。两次读牌。先看穿对手的人，未必是赢家。", 18, ThemeFactory.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	layout.add_child(tagline)
	var profile: Dictionary = save_data.profile
	var profile_line := _label("契约等级 %d  ·  契印 %d  ·  当前连胜 %d  ·  每日连签 %d" % [int(profile.level), int(profile.seals), int(profile.win_streak), int(profile.daily_streak)], 16, ThemeFactory.GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER)
	layout.add_child(profile_line)
	var gap := Control.new()
	gap.custom_minimum_size.y = 8
	layout.add_child(gap)
	var menu := VBoxContainer.new()
	menu.custom_minimum_size.x = 380
	menu.add_theme_constant_override("separation", 8)
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var play := _button("开始契约", _show_setup)
	ThemeFactory.accent_button(play)
	menu.add_child(play)
	var online_play := _button("联机对战", show_online_lobby)
	online_play.tooltip_text = "公开匹配或使用房间码邀请朋友，服务器权威结算。"
	menu.add_child(online_play)
	var today := Time.get_date_string_from_system()
	var daily_done := String(profile.last_daily_completed) == today
	var daily := _button("今日审判%s" % ("  ✓" if daily_done else "") , _start_daily_challenge)
	daily.tooltip_text = "所有玩家在同一天面对相同种子、人格、难度和契约。首次完成有额外奖励。"
	menu.add_child(daily)
	menu.add_child(_button("规则与教程", show_tutorial))
	menu.add_child(_button("契约档案", show_statistics))
	menu.add_child(_button("设置", show_settings))
	var quit := _button("离开游戏", _quit_game)
	menu.add_child(quit)
	layout.add_child(menu)
	var footer := _label("赛季零：深渊契约 · 离线公平挑战", 14, Color("#6e7080"), HORIZONTAL_ALIGNMENT_CENTER)
	footer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	footer.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	layout.add_child(footer)
	_set_screen("menu", layout)

func _show_setup() -> void:
	audio.play("select")
	var page := VBoxContainer.new()
	page.add_child(_page_header("选择你的对手", "人格决定策略，难度只决定执行精度。"))
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 22)
	var personality_panel := _panel()
	personality_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pv := VBoxContainer.new()
	personality_panel.add_child(pv)
	pv.add_child(_section_title("AI 人格"))
	var descriptions := [
		"谨慎保存高阶棋子，宁可放弃小利。适合第一次对局。",
		"大额轮强攻，落后时会进入疯狂模式。",
		"高频伪装与暗钻，擅长跨回合塑造假象。",
		"执行五套多轮战术，被打断后切换备用方案。",
	]
	var personality_info := _label("", 17, ThemeFactory.MUTED)
	personality_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for i in 4:
		var button := _button(GameRules.personality_name(i), func() -> void:
			setup_personality = i
			personality_info.text = descriptions[i]
			_update_setup_buttons(pv, "personality", i)
		)
		button.set_meta("group", "personality")
		button.set_meta("value", i)
		pv.add_child(button)
	pv.add_child(personality_info)
	personality_info.text = descriptions[setup_personality]
	body.add_child(personality_panel)

	var difficulty_panel := _panel()
	difficulty_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var dv := VBoxContainer.new()
	difficulty_panel.add_child(dv)
	dv.add_child(_section_title("执行难度"))
	var diff_desc := [
		"±0.30 噪声，不用暗牌升级，不执行完整连招。",
		"±0.15 噪声，学习最近四轮，连招执行率 50%。",
		"±0.05 微扰，使用全部历史，连招执行率 90%。",
	]
	var difficulty_info := _label("", 17, ThemeFactory.MUTED)
	difficulty_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for i in 3:
		var button := _button(GameRules.difficulty_name(i), func() -> void:
			setup_difficulty = i
			difficulty_info.text = diff_desc[i]
			_update_setup_buttons(dv, "difficulty", i)
		)
		button.set_meta("group", "difficulty")
		button.set_meta("value", i)
		dv.add_child(button)
	dv.add_child(difficulty_info)
	difficulty_info.text = diff_desc[setup_difficulty]
	body.add_child(difficulty_panel)
	page.add_child(body)

	var contract_panel := _panel(Color("#141721"), ThemeFactory.GOLD)
	var contract_v := VBoxContainer.new()
	contract_panel.add_child(contract_v)
	contract_v.add_child(_section_title("恶魔契约变体"))
	var contract_row := HBoxContainer.new()
	contract_row.add_child(_label("条款", 17, ThemeFactory.MUTED))
	var contract_option := OptionButton.new()
	contract_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var contracts := ContractSystem.all()
	var selected_contract_index := 0
	for index in contracts.size():
		var contract: Dictionary = contracts[index]
		contract_option.add_item("%s · %s · 奖励 x%.2f" % [String(contract.name), String(contract.short), float(contract.reward_multiplier)], index)
		if String(contract.id) == setup_contract_id:
			selected_contract_index = index
	contract_option.select(selected_contract_index)
	contract_row.add_child(contract_option)
	contract_v.add_child(contract_row)
	var contract_info := _label(String(contracts[selected_contract_index].description), 16, ThemeFactory.MUTED)
	contract_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contract_v.add_child(contract_info)
	contract_option.item_selected.connect(func(index: int) -> void:
		setup_contract_id = String(contracts[index].id)
		contract_info.text = String(contracts[index].description)
	)
	page.add_child(contract_panel)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_child(_button("返回", show_main_menu))
	var start := _button("签下契约", _start_match)
	ThemeFactory.accent_button(start)
	actions.add_child(start)
	page.add_child(actions)
	_set_screen("setup", page)
	_update_setup_buttons(pv, "personality", setup_personality)
	_update_setup_buttons(dv, "difficulty", setup_difficulty)

func _update_setup_buttons(container: Container, group: String, value: int) -> void:
	for child in container.get_children():
		if child is Button and child.get_meta("group", "") == group:
			var selected := int(child.get_meta("value")) == value
			child.text = ("◆ " if selected else "") + (GameRules.personality_name(value) if group == "personality" and selected else child.text.trim_prefix("◆ "))
			if selected:
				child.add_theme_color_override("font_color", ThemeFactory.GOLD_BRIGHT)
			else:
				child.remove_theme_color_override("font_color")

func _start_match() -> void:
	game_mode = "standard"
	daily_date = ""
	_launch_match()

func _start_daily_challenge() -> void:
	var config := ContractSystem.daily_configuration(Time.get_date_string_from_system())
	game_mode = "daily"
	daily_date = String(config.date)
	setup_personality = int(config.personality)
	setup_difficulty = int(config.difficulty)
	setup_contract_id = String(config.contract_id)
	_launch_match(int(config.seed))

func _launch_match(seed_value: int = 0) -> void:
	audio.play("confirm")
	pending_summary.clear()
	summary_recorded = false
	last_progression_result.clear()
	_build_game_screen()
	session.start_match(setup_personality, setup_difficulty, seed_value, setup_contract_id)

func _replay_match() -> void:
	if game_mode == "daily":
		var config := ContractSystem.daily_configuration(daily_date)
		_launch_match(int(config.seed))
	else:
		_launch_match()

func _build_game_screen() -> void:
	var active_contract := ContractSystem.get_contract(setup_contract_id)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	var top := HBoxContainer.new()
	var menu_button := _button("退出对局", _confirm_leave_match)
	menu_button.custom_minimum_size.x = 130
	top.add_child(menu_button)
	round_label = _label("今日审判" if game_mode == "daily" else "第 1 回合", 20, ThemeFactory.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	round_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(round_label)
	score_label = _label("你 0 : 0 AI", 24, ThemeFactory.GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER)
	score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(score_label)
	pool_label = _label("金池 100", 19, ThemeFactory.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	pool_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(pool_label)
	reading_label = _label("读牌 2", 19, ThemeFactory.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	reading_label.custom_minimum_size.x = 160
	top.add_child(reading_label)
	page.add_child(top)

	var arena := HBoxContainer.new()
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena.add_theme_constant_override("separation", 16)
	var history_panel := _panel()
	history_panel.custom_minimum_size.x = 265
	var history_scroll := ScrollContainer.new()
	history_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	history_panel.add_child(history_scroll)
	history_box = VBoxContainer.new()
	history_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history_scroll.add_child(history_box)
	history_box.add_child(_section_title("公开记录"))
	arena.add_child(history_panel)

	var table := VBoxContainer.new()
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table.alignment = BoxContainer.ALIGNMENT_CENTER
	dialogue_label = _label("……", 19, ThemeFactory.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.custom_minimum_size.y = 58
	table.add_child(dialogue_label)
	var ai_card := _panel(Color("#151722"), ThemeFactory.CRIMSON)
	ai_card.custom_minimum_size = Vector2(250, 190)
	ai_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var ai_card_v := VBoxContainer.new()
	ai_card_v.alignment = BoxContainer.ALIGNMENT_CENTER
	ai_card.add_child(ai_card_v)
	ai_card_title = _label("封印中", 42, ThemeFactory.CRIMSON.lightened(0.18), HORIZONTAL_ALIGNMENT_CENTER)
	ai_card_detail = _label("AI 已经提交暗牌", 16, ThemeFactory.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	ai_card_v.add_child(ai_card_title)
	ai_card_v.add_child(ai_card_detail)
	table.add_child(ai_card)
	pot_label = _label("本轮  ?  金", 40, ThemeFactory.GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER)
	table.add_child(pot_label)
	result_panel = _panel(Color("#181b26"), ThemeFactory.GOLD)
	result_panel.visible = false
	var result_v := VBoxContainer.new()
	result_panel.add_child(result_v)
	result_title = _label("", 27, ThemeFactory.GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER)
	result_detail = _label("", 16, ThemeFactory.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	result_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	next_button = _button("下一回合", _on_next_round)
	ThemeFactory.accent_button(next_button)
	result_v.add_child(result_title)
	result_v.add_child(result_detail)
	result_v.add_child(next_button)
	table.add_child(result_panel)
	arena.add_child(table)

	var intel_panel := _panel()
	intel_panel.custom_minimum_size.x = 285
	var intel := VBoxContainer.new()
	intel_panel.add_child(intel)
	intel.add_child(_section_title("对手档案"))
	intel.add_child(_label(GameRules.personality_name(setup_personality), 28, ThemeFactory.GOLD_BRIGHT))
	intel.add_child(_label(_personality_description(setup_personality), 16, ThemeFactory.MUTED))
	intel.add_child(HSeparator.new())
	intel.add_child(_section_title(String(active_contract.name)))
	var contract_rule := _label(String(active_contract.description), 15, ThemeFactory.MUTED)
	contract_rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intel.add_child(contract_rule)
	intel.add_child(HSeparator.new())
	ai_status_label = _label("正在评估局势……", 16, ThemeFactory.MUTED)
	ai_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intel.add_child(ai_status_label)
	intel.add_child(HSeparator.new())
	debug_label = _label("", 13, Color("#777b8c"))
	debug_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intel.add_child(debug_label)
	var rules := _button("查看规则", show_tutorial.bind(true))
	intel.add_child(rules)
	arena.add_child(intel_panel)
	page.add_child(arena)

	var controls := _panel(Color("#12151f"), Color("#3d4152"))
	var controls_v := VBoxContainer.new()
	controls.add_child(controls_v)
	var hand_title := HBoxContainer.new()
	hand_title.add_child(_section_title("你的棋子"))
	selected_detail = RichTextLabel.new()
	selected_detail.bbcode_enabled = true
	selected_detail.fit_content = true
	selected_detail.scroll_active = false
	selected_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_title.add_child(selected_detail)
	controls_v.add_child(hand_title)
	player_hand_box = HBoxContainer.new()
	player_hand_box.alignment = BoxContainer.ALIGNMENT_CENTER
	controls_v.add_child(player_hand_box)
	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_child(_label("展示名称", 16, ThemeFactory.MUTED))
	disguise_option = OptionButton.new()
	disguise_option.custom_minimum_size.x = 170
	for piece in GameRules.PIECES:
		disguise_option.add_item(GameRules.piece_name(piece), piece)
	action_row.add_child(disguise_option)
	action_row.add_child(_label("钻石", 16, ThemeFactory.MUTED))
	upgrade_option = OptionButton.new()
	upgrade_option.custom_minimum_size.x = 170
	upgrade_option.add_item("不升级", GameRules.Upgrade.NONE)
	if bool(active_contract.get("allow_open_upgrade", true)):
		upgrade_option.add_item("明牌升级", GameRules.Upgrade.OPEN)
	if bool(active_contract.get("allow_secret_upgrade", true)):
		upgrade_option.add_item("暗牌升级", GameRules.Upgrade.SECRET)
	action_row.add_child(upgrade_option)
	reading_button = _button("使用读牌", _use_reading)
	action_row.add_child(reading_button)
	commit_button = _button("提交暗牌", _commit_action)
	ThemeFactory.accent_button(commit_button)
	action_row.add_child(commit_button)
	controls_v.add_child(action_row)
	page.add_child(controls)
	_set_screen("game", page)

func _on_round_started(round_number: int, round_gold: int, line: String) -> void:
	selected_piece = -1
	round_locked = false
	result_panel.visible = false
	round_label.text = "第 %d 回合" % round_number
	pot_label.text = "本轮  %d  金" % round_gold
	dialogue_label.text = "“%s”" % line
	ai_card_title.text = "封印中"
	ai_card_detail.text = "对手的真实棋子尚未揭示"
	ai_status_label.text = "行动已锁定。%s" % ("AI 消耗了一次读牌。" if session.ai_used_reading_this_round else "AI 保留了读牌机会。")
	_update_game_status()
	_rebuild_hand()
	selected_detail.text = "[color=#aaa493]请选择一枚棋子。[/color]"
	disguise_option.disabled = true
	upgrade_option.disabled = true
	commit_button.disabled = true
	reading_button.disabled = not session.can_player_read()
	debug_label.text = "模式：%s\n难度：%s\n候选：%d\n决策：%.2f ms" % ["今日审判" if game_mode == "daily" else "自由契约", GameRules.difficulty_name(session.state.difficulty), session.last_ai_decision.get("candidates", []).size(), session.last_ai_decision.get("elapsed_ms", 0.0)]

func _rebuild_hand() -> void:
	for child in player_hand_box.get_children():
		child.queue_free()
	for piece in GameRules.PIECES:
		var status: Dictionary = session.state.player_hand[piece]
		var button := Button.new()
		button.custom_minimum_size = Vector2(168, 92)
		button.text = "%s\n%s" % [GameRules.PIECE_SHORT[piece], GameRules.piece_name(piece)]
		button.tooltip_text = GameRules.PIECE_DESCRIPTIONS[piece]
		button.disabled = not bool(status.available) or bool(status.banned) or round_locked
		var color: Color = GameRules.PIECE_COLORS[piece]
		button.add_theme_stylebox_override("normal", ThemeFactory.panel_style(Color("#202330"), color.darkened(0.20), 2, 10))
		button.add_theme_stylebox_override("hover", ThemeFactory.panel_style(Color("#292d3c"), color.lightened(0.25), 3, 10))
		button.add_theme_font_size_override("font_size", 19)
		button.pressed.connect(_select_piece.bind(piece))
		player_hand_box.add_child(button)

func _select_piece(piece: int) -> void:
	if round_locked:
		return
	selected_piece = piece
	audio.play("select")
	selected_detail.text = "[color=#f2d487][b]%s[/b][/color]  %s" % [GameRules.piece_name(piece), GameRules.PIECE_DESCRIPTIONS[piece]]
	disguise_option.disabled = not session.state.allow_disguise
	upgrade_option.disabled = false
	disguise_option.select(piece)
	upgrade_option.select(0)
	if session.state.player_diamond_used:
		upgrade_option.disabled = true
	commit_button.disabled = false
	for child in player_hand_box.get_children():
		if child is Button:
			var is_selected := child.get_index() == piece
			child.modulate = Color.WHITE if is_selected else Color(0.72, 0.72, 0.76, 1)

func _use_reading() -> void:
	if round_locked:
		return
	var result := session.use_player_reading()
	if not result.is_empty():
		audio.play("reading")
		reading_button.disabled = true
		_update_game_status()

func _on_player_reading_ready(result: Dictionary) -> void:
	var subject := "使用了钻石" if int(result.topic) == 0 else "使用了伪装"
	var answer := "是" if bool(result.reported) else "否"
	dialogue_label.text = "读牌结果：对手本轮%s？  [ %s ]\n结果可信度为 %d%%，它可能正在误导你。" % [subject, answer, roundi(float(result.reliability) * 100.0)]

func _commit_action() -> void:
	if selected_piece < 0 or round_locked:
		return
	var upgrade := upgrade_option.get_selected_id()
	if session.state.player_diamond_used:
		upgrade = GameRules.Upgrade.NONE
	var action := {"piece": selected_piece, "upgrade": upgrade, "display": disguise_option.get_selected_id()}
	if not session.state.validate_action(action, true):
		return
	round_locked = true
	audio.play("confirm")
	commit_button.disabled = true
	reading_button.disabled = true
	disguise_option.disabled = true
	upgrade_option.disabled = true
	for child in player_hand_box.get_children():
		if child is Button:
			child.disabled = true
	dialogue_label.text = "双方暗牌已经锁定……"
	var public_announcements: Array[String] = []
	if upgrade == GameRules.Upgrade.OPEN:
		public_announcements.append("你宣布使用钻石明牌升级")
	if session.pending_ai_action.upgrade == GameRules.Upgrade.OPEN:
		public_announcements.append("AI 宣布使用钻石明牌升级")
	if not public_announcements.is_empty():
		ai_card_detail.text = " · ".join(public_announcements)
		dialogue_label.text = "明牌升级公告：%s。\n真实棋子仍处于封印中。" % "；".join(public_announcements)
	var reveal_delay := 0.08 if bool(save_data.settings.reduced_motion) else 0.65
	await get_tree().create_timer(reveal_delay).timeout
	session.submit_player_action(action)

func _on_round_resolved(result: Dictionary, line: String) -> void:
	audio.play("reveal")
	ai_card_title.text = GameRules.piece_name(result.ai_piece)
	ai_card_title.add_theme_color_override("font_color", GameRules.PIECE_COLORS[result.ai_piece].lightened(0.18))
	var display_text := "展示为 %s" % GameRules.piece_name(result.ai_display)
	if result.ai_display == result.ai_piece:
		display_text = "未使用伪装"
	ai_card_detail.text = "%s · %s" % [GameRules.upgrade_name(result.ai_upgrade), display_text]
	dialogue_label.text = "“%s”" % line
	var player_text := "%s（%s，显%s）" % [GameRules.piece_name(result.player_piece), GameRules.upgrade_name(result.player_upgrade), GameRules.piece_name(result.player_display)]
	var ai_text := "%s（%s，显%s）" % [GameRules.piece_name(result.ai_piece), GameRules.upgrade_name(result.ai_upgrade), GameRules.piece_name(result.ai_display)]
	match int(result.winner):
		GameRules.Winner.PLAYER:
			result_title.text = "你赢下了 %d 金" % int(result.gold)
			result_title.add_theme_color_override("font_color", ThemeFactory.SUCCESS)
			audio.play("win")
		GameRules.Winner.AI:
			result_title.text = "对手赢下了 %d 金" % int(result.gold)
			result_title.add_theme_color_override("font_color", ThemeFactory.DANGER)
			audio.play("lose")
		_:
			result_title.text = "%d 金坠入深渊" % int(result.gold)
			result_title.add_theme_color_override("font_color", ThemeFactory.MUTED)
	var extra := ""
	if bool(result.instant_upset):
		extra = "\n二级平民击破二级国王，触发绝杀！败者金币归零。"
	elif not result.penalties.is_empty():
		var lost: Array[String] = []
		for penalty in result.penalties:
			lost.append(("你" if int(penalty.side) == GameRules.Winner.PLAYER else "AI") + "失去" + GameRules.piece_name(penalty.piece))
		extra = "\n大额平局惩罚：" + "，".join(lost)
	result_detail.text = "你：%s\nAI：%s%s" % [player_text, ai_text, extra]
	result_panel.visible = true
	next_button.text = "查看最终结算" if session.state.match_over else "下一回合"
	_update_game_status()
	_rebuild_history()

func _on_amnesia(line: String) -> void:
	audio.play("amnesia")
	dialogue_label.text = "失忆降临：一条公开记录被抹去。\n“%s”" % line

func _on_match_finished(summary: Dictionary, _line: String) -> void:
	pending_summary = summary

func _on_next_round() -> void:
	if not pending_summary.is_empty():
		show_end_screen(pending_summary)
	else:
		session.begin_round()

func _update_game_status() -> void:
	if not score_label:
		return
	score_label.text = "你  %d  :  %d  AI" % [session.state.player_gold, session.state.ai_gold]
	pool_label.text = "剩余 %d · 浪费 %d" % [session.state.remaining_gold, session.state.wasted_gold]
	reading_label.text = "共享读牌 %d" % session.state.shared_readings_remaining

func _rebuild_history() -> void:
	for child in history_box.get_children():
		if child.get_index() > 0:
			child.queue_free()
	if session.state.history.is_empty():
		history_box.add_child(_label("尚无揭示记录", 15, ThemeFactory.MUTED))
		return
	for record in session.state.history:
		var winner_text := "你胜" if int(record.winner) == GameRules.Winner.PLAYER else ("AI 胜" if int(record.winner) == GameRules.Winner.AI else "平局")
		var text := "第 %d 轮 · %d 金\n你 %s / AI %s\n%s" % [int(record.round), int(record.gold), GameRules.piece_name(record.player_piece), GameRules.piece_name(record.ai_piece), winner_text]
		var item := _label(text, 15, ThemeFactory.TEXT)
		item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		history_box.add_child(item)
		history_box.add_child(HSeparator.new())

func show_end_screen(summary: Dictionary) -> void:
	if not summary_recorded:
		SaveService.record_match(save_data, summary)
		last_progression_result = ProgressionService.record_result(save_data, summary, game_mode, daily_date)
		SaveService.save_data(save_data)
		summary_recorded = true
	var won := int(summary.winner) == GameRules.Winner.PLAYER
	var draw := int(summary.winner) == GameRules.Winner.DRAW
	var page := VBoxContainer.new()
	page.alignment = BoxContainer.ALIGNMENT_CENTER
	var heading := "契约成立" if won else ("无人获胜" if draw else "契约被夺")
	var heading_color := ThemeFactory.SUCCESS if won else (ThemeFactory.MUTED if draw else ThemeFactory.DANGER)
	page.add_child(_label(heading, 58, heading_color, HORIZONTAL_ALIGNMENT_CENTER))
	var subtitle := "二级平民完成绝杀" if bool(summary.instant_upset) else "%d 回合后，百金归于命运。" % int(summary.rounds)
	page.add_child(_label(subtitle, 20, ThemeFactory.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var result := _panel(Color("#171a24"), heading_color)
	result.custom_minimum_size = Vector2(680, 330)
	result.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var rv := VBoxContainer.new()
	result.add_child(rv)
	rv.add_child(_label("%d   :   %d" % [int(summary.player_gold), int(summary.ai_gold)], 62, ThemeFactory.GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER))
	rv.add_child(_label("你的金币                         AI 金币", 16, ThemeFactory.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	rv.add_child(HSeparator.new())
	rv.add_child(_label("浪费金币 %d · 对手 %s · 难度 %s" % [int(summary.wasted_gold), GameRules.personality_name(summary.personality), GameRules.difficulty_name(summary.difficulty)], 17, ThemeFactory.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var contract := ContractSystem.get_contract(String(summary.contract_id))
	rv.add_child(_label("%s · 奖励倍率 x%.2f" % [String(contract.name), float(contract.reward_multiplier)], 16, ThemeFactory.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	rv.add_child(_label("获得 %d 经验 · %d 契印 · 当前等级 %d" % [int(last_progression_result.xp), int(last_progression_result.seals), int(last_progression_result.level)], 20, ThemeFactory.GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER))
	if bool(last_progression_result.leveled_up):
		rv.add_child(_label("等级提升：新的契约称号已记录", 16, ThemeFactory.SUCCESS, HORIZONTAL_ALIGNMENT_CENTER))
	if not last_progression_result.unlocked.is_empty():
		rv.add_child(_label("新成就：" + " · ".join(last_progression_result.unlocked), 16, ThemeFactory.SUCCESS, HORIZONTAL_ALIGNMENT_CENTER))
	if game_mode == "daily" and bool(last_progression_result.daily_first):
		rv.add_child(_label("今日首次完成奖励已领取", 15, ThemeFactory.SUCCESS, HORIZONTAL_ALIGNMENT_CENTER))
	rv.add_child(_label("对局种子：%d" % int(summary.seed), 13, Color("#777b8c"), HORIZONTAL_ALIGNMENT_CENTER))
	page.add_child(result)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_child(_button("返回主菜单", show_main_menu))
	var again := _button("重演今日审判" if game_mode == "daily" else "再签一次", _replay_match)
	ThemeFactory.accent_button(again)
	actions.add_child(again)
	page.add_child(actions)
	_set_screen("end", page)

func show_online_lobby(skip_connect: bool = false) -> void:
	audio.play("select")
	var page := VBoxContainer.new()
	page.add_child(_page_header("联机契约", "双阶段密封博弈 · 公开匹配 · 私人房间 · 断线续局"))
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 22)
	var left_panel := _panel(Color("#151823"), ThemeFactory.GOLD)
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var left := VBoxContainer.new()
	left_panel.add_child(left)
	left.add_child(_section_title("你的联机身份"))
	online_name_input = LineEdit.new()
	online_name_input.max_length = 16
	online_name_input.text = String(save_data.online.display_name)
	online_name_input.placeholder_text = "输入 1-16 字昵称"
	left.add_child(online_name_input)
	left.add_child(_section_title("本局契约"))
	online_contract_option = OptionButton.new()
	for contract in ContractSystem.all():
		online_contract_option.add_item("%s · %s" % [String(contract.name), String(contract.short)])
		online_contract_option.set_item_metadata(online_contract_option.item_count - 1, String(contract.id))
	left.add_child(online_contract_option)
	var fairness := _label("服务器只接受合法行动并权威结算。双方先密封意图，再进入洞察阶段抢用共享读牌，最后同时锁定。", 16, ThemeFactory.MUTED)
	fairness.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(fairness)
	left.add_child(HSeparator.new())
	online_status_label = _label("正在连接联机服务器……", 17, ThemeFactory.GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER)
	online_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(online_status_label)
	body.add_child(left_panel)

	var right_panel := _panel()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var right := VBoxContainer.new()
	right_panel.add_child(right)
	right.add_child(_section_title("公开匹配"))
	right.add_child(_label("自动匹配另一位在线玩家。匹配期间可随时取消。", 16, ThemeFactory.MUTED))
	var match_button := _button("加入公开匹配", _online_join_queue)
	ThemeFactory.accent_button(match_button)
	right.add_child(match_button)
	var cancel_button := _button("取消匹配", _online_leave_queue)
	right.add_child(cancel_button)
	right.add_child(HSeparator.new())
	right.add_child(_section_title("私人房间"))
	right.add_child(_label("创建房间后，把 6 位房间码发给朋友。", 16, ThemeFactory.MUTED))
	right.add_child(_button("创建私人房间", _online_create_room))
	var join_row := HBoxContainer.new()
	online_room_input = LineEdit.new()
	online_room_input.max_length = 6
	online_room_input.placeholder_text = "房间码"
	online_room_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_row.add_child(online_room_input)
	join_row.add_child(_button("加入", _online_join_room))
	right.add_child(join_row)
	body.add_child(right_panel)
	page.add_child(body)
	page.add_child(_button("返回主菜单", _close_online_and_menu))
	_set_screen("online_lobby", page)
	online_action_buttons = [match_button, cancel_button]
	for child in right.get_children():
		if child is Button and child not in online_action_buttons:
			online_action_buttons.append(child)
	for button in online_action_buttons:
		button.disabled = true
	if skip_connect:
		online_status_label.text = "服务器已连接 · 协议 1.1.0"
		for button in online_action_buttons:
			button.disabled = false
	else:
		_connect_online()

func _connect_online() -> void:
	var online_data: Dictionary = save_data.online
	var error: Error = online.connect_server(String(online_name_input.text), String(online_data.resume_token), String(online_data.server_url))
	if error != OK:
		online_status_label.text = "无法启动连接：%s" % error_string(error)

func _on_online_welcomed(payload: Dictionary) -> void:
	save_data.online.display_name = online.player_name
	save_data.online.resume_token = String(payload.resume_token)
	SaveService.save_data(save_data)
	if online_status_label and current_screen == "online_lobby":
		var profile: Dictionary = payload.get("profile", {})
		online_status_label.text = "服务器已连接 · 评级 %d · 云端战绩 %d 胜 / %d 场" % [int(profile.get("rating", 1000)), int(profile.get("wins", 0)), int(profile.get("matches", 0))]
		for button in online_action_buttons:
			button.disabled = false

func _on_online_disconnected(reason: String) -> void:
	if current_screen == "online_lobby" and online_status_label:
		online_status_label.text = "连接已断开：%s" % (reason if not reason.is_empty() else "网络不可用")
	elif current_screen == "online_game" and online_phase_label:
		online_phase_label.text = "连接中断，返回大厅可自动续局"

func _online_save_name() -> void:
	var name := online_name_input.text.strip_edges().left(16)
	if not name.is_empty():
		save_data.online.display_name = name
		SaveService.save_data(save_data)
		if online.is_ready():
			online.send_message("profile_update", {"name": name})

func _online_contract_id() -> String:
	return String(online_contract_option.get_item_metadata(online_contract_option.selected))

func _online_join_queue() -> void:
	_online_save_name()
	online.send_message("queue_join", {"contract_id": _online_contract_id()})
	online_status_label.text = "正在寻找另一位契约者……"

func _online_leave_queue() -> void:
	online.send_message("queue_leave")
	online_status_label.text = "已取消匹配。"

func _online_create_room() -> void:
	_online_save_name()
	online.send_message("room_create", {"contract_id": _online_contract_id()})
	online_status_label.text = "正在创建私人房间……"

func _online_join_room() -> void:
	var code := online_room_input.text.strip_edges().to_upper()
	if code.length() != 6:
		online_status_label.text = "房间码应为 6 位。"
		return
	_online_save_name()
	online.send_message("room_join", {"code": code})
	online_status_label.text = "正在加入房间 %s……" % code

func _close_online_and_menu() -> void:
	online.close()
	show_main_menu()

func _on_online_message(message: Dictionary) -> void:
	var message_type := String(message.get("type", ""))
	match message_type:
		"error":
			var error_text := String(message.get("message", "联机请求失败。"))
			if current_screen == "online_lobby" and online_status_label:
				online_status_label.text = error_text
			elif current_screen == "online_game" and online_phase_label:
				online_phase_label.text = error_text
		"queue_status":
			if online_status_label:
				var position := int(message.get("position", 0))
				online_status_label.text = "匹配队列第 %d 位，等待对手……" % position if position > 0 else "已取消匹配。"
		"room_created":
			if online_status_label:
				online_status_label.text = "房间已创建：%s\n把房间码发给朋友，正在等待加入。" % String(message.code)
		"match_started", "state_sync":
			_online_receive_state(message.state, true)
		"round_started":
			_online_receive_state(message.state, false)
			_online_begin_round()
		"intent_accepted":
			_online_receive_state(message.state, false)
			online_phase_label.text = "意图已密封，等待对手提交……"
			online_primary_button.disabled = true
		"opponent_intent":
			if online_phase_label:
				online_phase_label.text = "对手已经密封意图，等待你的选择。"
		"insight_started":
			_online_receive_state(message.state, false)
			_online_enter_insight()
		"reading_result":
			_online_receive_state(message.state, false)
			var reading: Dictionary = message.reading
			var subject := "使用了钻石" if int(reading.topic) == 0 else "使用了伪装"
			online_phase_label.text = "读牌：对手%s？[%s]，可信度 %d%%。你仍可修改行动。" % [subject, "是" if bool(reading.reported) else "否", roundi(float(reading.reliability) * 100.0)]
		"shared_reading_used", "lock_status", "next_round_status":
			_online_receive_state(message.state, false)
			if message_type == "lock_status":
				var locked: Array = message.get("locked", [])
				if not locked.is_empty():
					online_phase_label.text = "最终行动已锁定，等待对手……" if bool(locked[int(online_state.player_index)]) else "对手已锁定，轮到你。"
			if message_type == "next_round_status":
				online_phase_label.text = "你已准备，等待对手进入下一回合……"
		"round_resolved":
			_online_receive_state(message.state, false)
			_online_show_round_result(message.result)
		"match_finished":
			_online_receive_state(message.state, false)
			_online_show_match_finished(message)
		"opponent_disconnected":
			if online_phase_label:
				online_phase_label.text = "对手断线，等待其在 %d 秒内重连……" % int(message.get("reconnect_seconds", 90))

func _online_receive_state(state: Dictionary, build_if_needed: bool) -> void:
	online_state = state.duplicate(true)
	if build_if_needed and current_screen != "online_game":
		_build_online_game_screen()
	if current_screen == "online_game":
		_update_online_game()

func _build_online_game_screen() -> void:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	var top := HBoxContainer.new()
	top.add_child(_button("认输离场", _confirm_online_surrender))
	online_opponent_label = _label("联机对手", 18, ThemeFactory.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	online_opponent_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(online_opponent_label)
	online_score_label = _label("0 : 0", 25, ThemeFactory.GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER)
	online_score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(online_score_label)
	online_pot_label = _label("金池 100", 18, ThemeFactory.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	online_pot_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(online_pot_label)
	online_reading_label = _label("共享读牌 2", 18, ThemeFactory.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	top.add_child(online_reading_label)
	page.add_child(top)

	var arena := HBoxContainer.new()
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena.add_theme_constant_override("separation", 18)
	var history_panel := _panel()
	history_panel.custom_minimum_size.x = 300
	var history_scroll := ScrollContainer.new()
	history_panel.add_child(history_scroll)
	online_history_box = VBoxContainer.new()
	online_history_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history_scroll.add_child(online_history_box)
	arena.add_child(history_panel)
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	online_phase_label = _label("同步对局状态……", 21, ThemeFactory.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	online_phase_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	online_phase_label.custom_minimum_size.y = 70
	center.add_child(online_phase_label)
	var seal := _panel(Color("#161924"), ThemeFactory.CRIMSON)
	seal.custom_minimum_size = Vector2(360, 220)
	seal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var seal_v := VBoxContainer.new()
	seal_v.alignment = BoxContainer.ALIGNMENT_CENTER
	seal.add_child(seal_v)
	seal_v.add_child(_label("双重封印", 40, ThemeFactory.CRIMSON.lightened(0.18), HORIZONTAL_ALIGNMENT_CENTER))
	seal_v.add_child(_label("意图密封后，双方才可读牌与改招", 16, ThemeFactory.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	center.add_child(seal)
	online_result_panel = _panel(Color("#181b26"), ThemeFactory.GOLD)
	online_result_panel.visible = false
	var result_v := VBoxContainer.new()
	online_result_panel.add_child(result_v)
	online_result_title = _label("", 28, ThemeFactory.GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER)
	online_result_detail = _label("", 16, ThemeFactory.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	online_result_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_v.add_child(online_result_title)
	result_v.add_child(online_result_detail)
	center.add_child(online_result_panel)
	arena.add_child(center)
	var rule_panel := _panel()
	rule_panel.custom_minimum_size.x = 300
	var rule_v := VBoxContainer.new()
	rule_panel.add_child(rule_v)
	rule_v.add_child(_section_title("真人契约"))
	var contract := ContractSystem.get_contract(String(online_state.contract_id))
	rule_v.add_child(_label(String(contract.name), 27, ThemeFactory.GOLD_BRIGHT))
	var desc := _label(String(contract.description), 15, ThemeFactory.MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule_v.add_child(desc)
	rule_v.add_child(HSeparator.new())
	rule_v.add_child(_label("1. 双方提交密封意图\n2. 洞察阶段可抢用共享读牌\n3. 可改招并最终锁定\n4. 双方准备后进入下轮", 16, ThemeFactory.TEXT))
	arena.add_child(rule_panel)
	page.add_child(arena)

	var controls := _panel(Color("#12151f"), Color("#3d4152"))
	var controls_v := VBoxContainer.new()
	controls.add_child(controls_v)
	var title_row := HBoxContainer.new()
	title_row.add_child(_section_title("你的棋子"))
	online_selected_detail = _label("请选择一枚棋子。", 16, ThemeFactory.MUTED)
	online_selected_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(online_selected_detail)
	controls_v.add_child(title_row)
	online_hand_box = HBoxContainer.new()
	online_hand_box.alignment = BoxContainer.ALIGNMENT_CENTER
	controls_v.add_child(online_hand_box)
	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_child(_label("展示", 16, ThemeFactory.MUTED))
	online_disguise_option = OptionButton.new()
	online_disguise_option.custom_minimum_size.x = 150
	for piece in GameRules.PIECES:
		online_disguise_option.add_item(GameRules.piece_name(piece), piece)
	action_row.add_child(online_disguise_option)
	action_row.add_child(_label("钻石", 16, ThemeFactory.MUTED))
	online_upgrade_option = OptionButton.new()
	online_upgrade_option.custom_minimum_size.x = 160
	online_upgrade_option.add_item("不升级", GameRules.Upgrade.NONE)
	if bool(contract.get("allow_open_upgrade", true)):
		online_upgrade_option.add_item("明牌升级", GameRules.Upgrade.OPEN)
	if bool(contract.get("allow_secret_upgrade", true)):
		online_upgrade_option.add_item("暗牌升级", GameRules.Upgrade.SECRET)
	action_row.add_child(online_upgrade_option)
	online_read_button = _button("使用共享读牌", _online_use_reading)
	action_row.add_child(online_read_button)
	online_primary_button = _button("密封意图", _online_primary_action)
	ThemeFactory.accent_button(online_primary_button)
	action_row.add_child(online_primary_button)
	controls_v.add_child(action_row)
	page.add_child(controls)
	_set_screen("online_game", page)
	_update_online_game()

func _online_hand_status(piece: int) -> Dictionary:
	var hand: Dictionary = online_state.get("hand", {})
	return hand.get(str(piece), hand.get(piece, {"available": false, "banned": false}))

func _rebuild_online_hand() -> void:
	for child in online_hand_box.get_children():
		child.queue_free()
	for piece in GameRules.PIECES:
		var status := _online_hand_status(piece)
		var button := Button.new()
		button.custom_minimum_size = Vector2(155, 86)
		button.text = "%s\n%s" % [GameRules.PIECE_SHORT[piece], GameRules.piece_name(piece)]
		button.disabled = not bool(status.available) or bool(status.banned) or String(online_state.phase) not in ["intent", "insight"]
		var color: Color = GameRules.PIECE_COLORS[piece]
		button.add_theme_stylebox_override("normal", ThemeFactory.panel_style(Color("#202330"), color.darkened(0.20), 2, 10))
		button.add_theme_stylebox_override("hover", ThemeFactory.panel_style(Color("#292d3c"), color.lightened(0.25), 3, 10))
		button.pressed.connect(_online_select_piece.bind(piece))
		online_hand_box.add_child(button)

func _online_select_piece(piece: int) -> void:
	online_selected_piece = piece
	online_selected_detail.text = "%s · %s" % [GameRules.piece_name(piece), GameRules.PIECE_DESCRIPTIONS[piece]]
	online_disguise_option.select(piece)
	online_upgrade_option.select(0)
	_online_refresh_controls()

func _online_current_action() -> Dictionary:
	if online_selected_piece < 0:
		return {}
	return {"piece": online_selected_piece, "upgrade": online_upgrade_option.get_selected_id(), "display": online_disguise_option.get_selected_id()}

func _online_primary_action() -> void:
	var phase := String(online_state.get("phase", ""))
	if phase == "intent":
		var action := _online_current_action()
		if action.is_empty():
			return
		online_intent = action
		online.send_message("intent_submit", {"action": action})
		online_primary_button.disabled = true
	elif phase == "insight":
		var final_action := _online_current_action()
		if final_action.is_empty():
			final_action = online_intent
		online.send_message("action_lock", {"action": final_action})
		online_primary_button.disabled = true
	elif phase == "resolved":
		online.send_message("next_round_ready")
		online_primary_button.disabled = true
	elif phase == "finished":
		_close_online_and_menu()

func _online_use_reading() -> void:
	online.send_message("reading_use")
	online_read_button.disabled = true

func _online_begin_round() -> void:
	online_selected_piece = -1
	online_intent.clear()
	online_result_panel.visible = false
	online_selected_detail.text = "请选择一枚棋子并密封意图。"
	_update_online_game()

func _online_enter_insight() -> void:
	online_phase_label.text = "双方意图已密封。现在可抢用共享读牌、修改行动并最终锁定。"
	if online_intent.is_empty() and online_state.get("intent") is Dictionary:
		online_intent = online_state.intent
	if not online_intent.is_empty():
		online_selected_piece = int(online_intent.piece)
		online_disguise_option.select(int(online_intent.display))
		for index in online_upgrade_option.item_count:
			if online_upgrade_option.get_item_id(index) == int(online_intent.upgrade):
				online_upgrade_option.select(index)
	_update_online_game()

func _online_refresh_controls() -> void:
	var phase := String(online_state.get("phase", ""))
	var can_choose := phase in ["intent", "insight"] and not bool(online_state.get("locked", false))
	var contract := ContractSystem.get_contract(String(online_state.get("contract_id", "standard")))
	online_disguise_option.disabled = not can_choose or not bool(contract.get("allow_disguise", true))
	online_upgrade_option.disabled = not can_choose or bool(online_state.get("diamond_used", false))
	online_primary_button.disabled = (online_selected_piece < 0 and online_intent.is_empty()) or not can_choose
	online_primary_button.text = "密封意图" if phase == "intent" else "最终锁定"
	if phase == "resolved":
		online_primary_button.text = "准备下一回合"
		online_primary_button.disabled = bool(online_state.get("ready_next", false))
	if phase == "finished":
		online_primary_button.text = "返回主菜单"
		online_primary_button.disabled = false
	online_read_button.disabled = phase != "insight" or int(online_state.get("shared_readings", 0)) <= 0 or bool(online_state.get("reading_used_this_round", false)) or bool(online_state.get("locked", false))

func _update_online_game() -> void:
	if current_screen != "online_game" or online_state.is_empty():
		return
	var player := int(online_state.get("player_index", 0))
	var opponent := 1 - player
	var names: Array = online_state.get("names", ["你", "对手"])
	var gold: Array = online_state.get("gold", [0, 0])
	online_opponent_label.text = "对手：%s" % String(names[opponent])
	online_score_label.text = "你 %d  :  %d %s" % [int(gold[player]), int(gold[opponent]), String(names[opponent])]
	online_pot_label.text = "第 %d 轮 · 本轮 %d · 剩余 %d" % [int(online_state.get("round", 0)), int(online_state.get("current_gold", 0)), int(online_state.get("remaining_gold", 0))]
	online_reading_label.text = "共享读牌 %d" % int(online_state.get("shared_readings", 0))
	var phase := String(online_state.get("phase", ""))
	if phase == "intent" and online_phase_label.text.find("对手") < 0:
		online_phase_label.text = "意图阶段：选择棋子、展示名与钻石方式，然后密封。"
	_rebuild_online_hand()
	_rebuild_online_history()
	_online_refresh_controls()

func _rebuild_online_history() -> void:
	for child in online_history_box.get_children():
		child.queue_free()
	online_history_box.add_child(_section_title("公开记录"))
	var history: Array = online_state.get("history", [])
	if history.is_empty():
		online_history_box.add_child(_label("尚无揭示记录", 15, ThemeFactory.MUTED))
		return
	var player := int(online_state.player_index)
	for record in history:
		var actions: Array = record.actions
		var mine: Dictionary = actions[player]
		var theirs: Dictionary = actions[1 - player]
		var winner := int(record.winner)
		var result_text := "你胜" if winner == player else ("平局" if winner == GameRules.Winner.DRAW else "对手胜")
		var text := "第 %d 轮 · %d 金\n你 %s / 对手 %s\n%s" % [int(record.round), int(record.gold), GameRules.piece_name(int(mine.piece)), GameRules.piece_name(int(theirs.piece)), result_text]
		online_history_box.add_child(_label(text, 15, ThemeFactory.TEXT))
		online_history_box.add_child(HSeparator.new())

func _online_show_round_result(result: Dictionary) -> void:
	var player := int(online_state.player_index)
	var actions: Array = result.actions
	var mine: Dictionary = actions[player]
	var theirs: Dictionary = actions[1 - player]
	var winner := int(result.winner)
	if winner == player:
		online_result_title.text = "你赢下了 %d 金" % int(result.gold)
		online_result_title.add_theme_color_override("font_color", ThemeFactory.SUCCESS)
		audio.play("win")
	elif winner == GameRules.Winner.DRAW:
		online_result_title.text = "%d 金坠入深渊" % int(result.gold)
		online_result_title.add_theme_color_override("font_color", ThemeFactory.MUTED)
	else:
		online_result_title.text = "对手赢下了 %d 金" % int(result.gold)
		online_result_title.add_theme_color_override("font_color", ThemeFactory.DANGER)
		audio.play("lose")
	online_result_detail.text = "你：%s（%s，显%s）\n对手：%s（%s，显%s）%s" % [GameRules.piece_name(int(mine.piece)), GameRules.upgrade_name(int(mine.upgrade)), GameRules.piece_name(int(mine.display)), GameRules.piece_name(int(theirs.piece)), GameRules.upgrade_name(int(theirs.upgrade)), GameRules.piece_name(int(theirs.display)), "\n触发二级平民绝杀！" if bool(result.instant_upset) else ""]
	online_result_panel.visible = true
	online_phase_label.text = "回合揭示完毕。双方准备后进入下一轮。"
	_update_online_game()

func _online_show_match_finished(message: Dictionary) -> void:
	var player := int(online_state.get("player_index", 0))
	var winner := int(online_state.get("winner", GameRules.Winner.DRAW))
	if winner == player:
		online_result_title.text = "联机契约胜利"
		online_result_title.add_theme_color_override("font_color", ThemeFactory.SUCCESS)
	elif winner == GameRules.Winner.DRAW:
		online_result_title.text = "联机契约平局"
	else:
		online_result_title.text = "联机契约失败"
		online_result_title.add_theme_color_override("font_color", ThemeFactory.DANGER)
	if message.has("surrendered"):
		online_result_detail.text += "\n一方主动认输。"
	elif message.has("disconnected_forfeit"):
		online_result_detail.text += "\n一方超过 90 秒未重连，判定负场。"
	online_result_panel.visible = true
	online_phase_label.text = "对局已由服务器结算并写入云端战绩。"
	_update_online_game()

func _confirm_online_surrender() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "确认认输？"
	dialog.dialog_text = "主动离开正在进行的联机对局会被服务器记为失败。"
	dialog.ok_button_text = "认输"
	dialog.cancel_button_text = "继续对局"
	dialog.confirmed.connect(_online_surrender)
	root.add_child(dialog)
	dialog.popup_centered(Vector2i(480, 230))

func _online_surrender() -> void:
	online.send_message("surrender")
	await get_tree().create_timer(0.15).timeout
	_close_online_and_menu()

func show_tutorial(as_overlay: bool = false) -> void:
	var page := VBoxContainer.new()
	page.add_child(_page_header("规则与教程", "完整规则可以在对局中随时打开。"))
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(_tutorial_tab("胜负规则", "[b]目标[/b]\n处理完 100 枚金币后，金币更多者获胜。平局金币会被浪费。\n\n[b]棋子层级[/b]\n国王 > 将军 > 骑士 > 士兵 > 平民。每枚棋子只能使用一次。\n\n[b]唯一反制[/b]\n平民可以击杀国王。二级平民击败二级国王时立刻绝杀，败者金币归零。"))
	tabs.add_child(_tutorial_tab("钻石与伪装", "[b]钻石[/b]\n每方只有一枚，可把本轮棋子升级。明牌升级会提前暴露，暗牌升级直到揭示才公开。\n\n[b]伪装[/b]\n你可以让任何棋子显示成另一名称。展示名称不会改变战力，只改变对手看到的信息。\n\n[b]提示[/b]\n强装弱适合诱敌，弱装强适合施压；始终伪装也会形成可读模式。"))
	tabs.add_child(_tutorial_tab("读牌与失忆", "[b]共享读牌[/b]\n整局双方合计只有两次。结果只有 70% 准确，会报告对手是否用了钻石或伪装。\n\n[b]失忆[/b]\n剩余金币低于 40 时可能触发，随机抹去一条公开历史。AI 的模型置信度也会随之下降。\n\n[b]公平性[/b]\nAI 不能读取你的手牌或当前选择，只能使用公开记录和合法的模糊读牌。"))
	tabs.add_child(_tutorial_tab("平局与策略", "[b]普通平局[/b]\n双方真实战力相同，金币直接浪费。\n\n[b]大额平局[/b]\n本轮至少 30 金时，双方还会随机失去一枚仍在手中的国王、将军或骑士。\n\n[b]五种对手[/b]\n四种人格会采用不同权重；套路型与欺诈型还会运行平民钓鱼、欺诈耗牌、钻石骗招、将军突击和残局收割。"))
	tabs.add_child(_tutorial_tab("契约与成长", "[b]契约变体[/b]\n自由契约可选择原初、血色金池、破碎预言、真名戒律、白昼誓约或盲眼契约。规则越危险，经验与契印倍率越高。\n\n[b]今日审判[/b]\n每天生成固定的对手、难度、契约与随机种子。首次完成可领取额外奖励并延续每日连签；重复挑战仍可刷新当日最佳分差。\n\n[b]长期档案[/b]\n每局获得经验和契印。胜利会累积连胜，特殊打法会解锁八项成就。成长只记录荣誉与收藏，不出售战斗数值。"))
	page.add_child(tabs)
	if as_overlay:
		var shade := ColorRect.new()
		shade.color = Color(0.01, 0.01, 0.02, 0.92)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shade.z_index = 100
		root.add_child(shade)
		var overlay_margin := MarginContainer.new()
		overlay_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		overlay_margin.add_theme_constant_override("margin_left", 90)
		overlay_margin.add_theme_constant_override("margin_right", 90)
		overlay_margin.add_theme_constant_override("margin_top", 55)
		overlay_margin.add_theme_constant_override("margin_bottom", 55)
		shade.add_child(overlay_margin)
		var overlay_panel := _panel(Color("#11141e"), ThemeFactory.GOLD)
		overlay_panel.add_child(page)
		overlay_margin.add_child(overlay_panel)
		page.add_child(_button("关闭规则", shade.queue_free))
	else:
		page.add_child(_button("返回", show_main_menu))
		_set_screen("tutorial", page)

func _tutorial_tab(name: String, bbcode: String) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = name
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	scroll.add_child(margin)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.text = bbcode
	text.fit_content = true
	text.custom_minimum_size.x = 900
	text.add_theme_font_size_override("normal_font_size", 22)
	text.add_theme_font_size_override("bold_font_size", 24)
	margin.add_child(text)
	return scroll

func show_statistics() -> void:
	var stats: Dictionary = save_data.stats
	var profile: Dictionary = save_data.profile
	var page := VBoxContainer.new()
	page.add_child(_page_header("契约档案", "成长提供目标与荣誉，不提供付费战力。"))
	var profile_panel := _panel(Color("#171a24"), ThemeFactory.GOLD)
	var profile_v := VBoxContainer.new()
	profile_panel.add_child(profile_v)
	profile_v.add_child(_label("契约等级 %d" % int(profile.level), 30, ThemeFactory.GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER))
	profile_v.add_child(_label("经验 %d / %d  ·  契印 %d  ·  当前连胜 %d  ·  最佳连胜 %d  ·  每日连签 %d" % [ProgressionService.level_progress(int(profile.xp)), ProgressionService.XP_PER_LEVEL, int(profile.seals), int(profile.win_streak), int(profile.best_win_streak), int(profile.daily_streak)], 16, ThemeFactory.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	page.add_child(profile_panel)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for item in [["总对局", stats.matches], ["胜利", stats.wins], ["失败", stats.losses], ["平局", stats.draws], ["平民绝杀", stats.upsets], ["单局最高金币", stats.best_gold]]:
		var panel := _panel()
		panel.custom_minimum_size = Vector2(300, 150)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		panel.add_child(v)
		v.add_child(_label(str(item[1]), 48, ThemeFactory.GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER))
		v.add_child(_label(str(item[0]), 17, ThemeFactory.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		grid.add_child(panel)
	page.add_child(grid)
	var wins := _label("击败各人格：保守 %d · 激进 %d · 欺诈 %d · 套路 %d" % stats.personality_wins, 18, ThemeFactory.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	page.add_child(wins)
	var achievement_names: Array[String] = []
	var unlocked_count := 0
	for achievement in ProgressionService.achievement_catalog():
		var unlocked := bool(save_data.achievements.get(String(achievement.id), false))
		if unlocked:
			unlocked_count += 1
		achievement_names.append(("◆ " if unlocked else "◇ ") + String(achievement.name))
	var achievement_text := _label("成就 %d / %d　%s" % [unlocked_count, achievement_names.size(), "　".join(achievement_names)], 15, ThemeFactory.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	achievement_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(achievement_text)
	page.add_child(_button("返回", show_main_menu))
	_set_screen("stats", page)

func show_settings() -> void:
	var settings: Dictionary = save_data.settings
	var page := VBoxContainer.new()
	page.add_child(_page_header("设置", "所有选项会即时保存。"))
	var panel := _panel()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	panel.add_child(v)
	v.add_child(_section_title("声音"))
	var volume_row := HBoxContainer.new()
	volume_row.add_child(_label("主音量", 18, ThemeFactory.TEXT))
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = float(settings.master_volume)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(value: float) -> void:
		settings.master_volume = value
		audio.set_master_volume(value)
		SaveService.save_data(save_data)
	)
	volume_row.add_child(slider)
	v.add_child(volume_row)
	v.add_child(HSeparator.new())
	v.add_child(_section_title("显示与无障碍"))
	v.add_child(_setting_toggle("全屏显示", bool(settings.fullscreen), func(value: bool) -> void: settings.fullscreen = value; _save_and_apply()))
	v.add_child(_setting_toggle("减少动态效果", bool(settings.reduced_motion), func(value: bool) -> void: settings.reduced_motion = value; _save_and_apply()))
	v.add_child(_setting_toggle("大号文字", bool(settings.large_text), func(value: bool) -> void: settings.large_text = value; _save_and_apply()))
	v.add_child(_setting_toggle("高对比度", bool(settings.high_contrast), func(value: bool) -> void: settings.high_contrast = value; _save_and_apply()))
	page.add_child(panel)
	page.add_child(_button("返回", show_main_menu))
	_set_screen("settings", page)

func _setting_toggle(text: String, value: bool, callback: Callable) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.text = text
	toggle.button_pressed = value
	toggle.toggled.connect(callback)
	return toggle

func _save_and_apply() -> void:
	SaveService.save_data(save_data)
	_apply_settings()

func _confirm_leave_match() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "放弃当前契约？"
	dialog.dialog_text = "本局进度不会计入战绩。"
	dialog.ok_button_text = "放弃"
	dialog.cancel_button_text = "继续对局"
	dialog.confirmed.connect(show_main_menu)
	root.add_child(dialog)
	dialog.popup_centered(Vector2i(460, 220))

func _quit_game() -> void:
	get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel"):
		match current_screen:
			"menu": _quit_game()
			"game": _confirm_leave_match()
			"online_game": _confirm_online_surrender()
			"online_lobby": _close_online_and_menu()
			_: show_main_menu()

func _personality_description(value: int) -> String:
	return [
		"保留资源，规避高风险。",
		"追求大额收益，落后时更凶猛。",
		"以信息不对称和多轮诱导取胜。",
		"执行预设剧本并动态切换分支。",
	][value]

func _panel(color: Color = ThemeFactory.PANEL, border: Color = Color("#35394a")) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeFactory.panel_style(color, border, 1, 14))
	return panel

func _page_header(title_text: String, subtitle_text: String) -> VBoxContainer:
	var header := VBoxContainer.new()
	header.add_child(_label(title_text, 40, ThemeFactory.GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER))
	header.add_child(_label(subtitle_text, 17, ThemeFactory.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	header.add_child(HSeparator.new())
	return header

func _section_title(text: String) -> Label:
	return _label(text, 21, ThemeFactory.GOLD_BRIGHT)

func _label(text: String, size: int = 18, color: Color = ThemeFactory.TEXT, alignment: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = alignment
	return label

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	return button
