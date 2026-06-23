extends CanvasLayer
## Persistent overlay UI and the single facade gameplay scripts talk to:
##   await Hud.say(speaker, text)        -> blocking dialogue line
##   await Hud.say_sequence(lines)       -> blocking dialogue sequence
##   await Hud.choice(prompt, options)   -> blocking menu, returns chosen id
##   await Hud.announce(text)            -> the (lying) announcement banner
##   Hud.show_prompt / hide_prompt       -> "[E] Examine Poster"
##   Hud.toggle_ticket()                 -> glance at your ticket
##   await Hud.fade_out() / fade_in()    -> scene transitions
##   Hud.is_blocking()                   -> Player freezes while a menu/dialogue is up
##
## Built entirely in code so the scene file stays a one-liner and there are no fragile
## editor layouts to merge. Coordinates are in the 640x360 base resolution.

signal advance
signal choice_picked(id: String)

const BASE := Vector2(640, 360)

var _overlay_mat: ShaderMaterial
var _ann_panel: PanelContainer
var _ann_label: Label
var _objective: Label
var _pill_label: Label
var _prompt: Label
var _dialogue: PanelContainer
var _dialogue_name: Label
var _dialogue_text: Label
var _ticket_panel: PanelContainer
var _ticket_text: Label
var _choice_layer: Control
var _choice_prompt: Label
var _choice_box: VBoxContainer
var _fade: ColorRect

var _blocking := false
var _dialogue_active := false
var _advance_ready := false


func _ready() -> void:
	layer = 100
	_build()
	GameState.reality_changed.connect(_on_reality)
	GameState.pills_changed.connect(func(c: int) -> void: _pill_label.text = "PILLS  %d" % c)
	GameState.objective_changed.connect(func(t: String) -> void: _objective.text = t)
	GameState.truth_pulse.connect(func() -> void: flash(0.45))
	_on_reality(GameState.reality)
	_pill_label.text = "PILLS  %d" % GameState.pills


func is_blocking() -> bool:
	return _blocking


# ---------------------------------------------------------------- prompt
func show_prompt(text: String) -> void:
	_prompt.text = text
	_prompt.visible = true


func hide_prompt() -> void:
	_prompt.visible = false


# ---------------------------------------------------------------- dialogue
func say(speaker: String, text: String) -> void:
	await say_sequence([{"name": speaker, "text": text}])


## `lines` is an Array of either plain String, or { "name": ..., "text": ... }.
func say_sequence(lines: Array) -> void:
	if lines.is_empty():
		return
	_dialogue_active = true
	_set_block(true)
	_dialogue.visible = true
	for entry in lines:
		var nm := ""
		var tx := ""
		if entry is Dictionary:
			nm = str(entry.get("name", ""))
			tx = str(entry.get("text", ""))
		else:
			tx = str(entry)
		_dialogue_name.text = nm
		_dialogue_name.visible = nm != ""
		_dialogue_text.text = tx
		await _wait_advance()
	_dialogue.visible = false
	_dialogue_active = false
	_set_block(false)


func _wait_advance() -> void:
	# Skip the current frame so the same key press that opened/advanced the box isn't reused.
	_advance_ready = false
	await get_tree().process_frame
	_advance_ready = true
	await advance


func _process(_delta: float) -> void:
	if _dialogue_active and _advance_ready:
		if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_cancel"):
			_advance_ready = false
			advance.emit()


# ---------------------------------------------------------------- choice menu
## options: Array of { "id": String, "label": String }. Returns the chosen id.
func choice(prompt: String, options: Array) -> String:
	_set_block(true)
	_choice_prompt.text = prompt
	for c in _choice_box.get_children():
		c.queue_free()
	var first: Button = null
	for opt: Dictionary in options:
		var b := Button.new()
		b.text = str(opt.get("label", "?"))
		b.custom_minimum_size = Vector2(300, 0)
		var id := str(opt.get("id", ""))
		b.pressed.connect(func() -> void: choice_picked.emit(id))
		_choice_box.add_child(b)
		if first == null:
			first = b
	# wait a frame so the keypress that opened this menu can't instantly select an option
	await get_tree().process_frame
	_choice_layer.visible = true
	if first:
		first.grab_focus()
	var picked: String = await choice_picked
	_choice_layer.visible = false
	_set_block(false)
	return picked


# ---------------------------------------------------------------- announcement banner
## Run a station's scripted announcements. Lives on Hud (which is never freed) so it can't
## crash by resuming on a station node that the player already left.
func announce_sequence(lines: Array) -> void:
	await get_tree().create_timer(0.8).timeout
	for line in lines:
		await announce(str(line))
		await get_tree().create_timer(0.4).timeout


func announce(text: String) -> void:
	_ann_label.text = text
	_ann_panel.visible = true
	var tw := create_tween()
	tw.tween_property(_ann_panel, "modulate:a", 1.0, 0.4)
	await tw.finished
	await get_tree().create_timer(clampf(text.length() * 0.05, 1.4, 4.0)).timeout
	var tw2 := create_tween()
	tw2.tween_property(_ann_panel, "modulate:a", 0.0, 0.6)
	await tw2.finished
	_ann_panel.visible = false


# ---------------------------------------------------------------- ticket
func toggle_ticket() -> void:
	if _ticket_panel.visible:
		_ticket_panel.visible = false
		return
	var t := GameState.get_ticket()
	var action_line := "\n\nACTION REQUIRED: %s" % t["action"] if t["action"] != "" else ""
	_ticket_text.text = "— TICKET —\n\nFROM:  %s\nTO:    %s\nROLE:  %s%s" % [t["from"], t["to"], t["role"], action_line]
	_ticket_panel.visible = true


# ---------------------------------------------------------------- fades
func fade_out() -> void:
	_fade.visible = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.3)
	await tw.finished


func fade_in() -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.3)
	await tw.finished
	_fade.visible = false


# ---------------------------------------------------------------- reality post-process
func _on_reality(state: int) -> void:
	var amount := 0.32
	match state:
		GameState.Reality.STABLE:
			amount = 0.06
		GameState.Reality.MEMORY_LEAK:
			amount = 0.72
	if _overlay_mat:
		_overlay_mat.set_shader_parameter("intensity", amount)


## A red truth-leak pulse over the whole screen; fades out on its own.
func flash(amount: float) -> void:
	if _overlay_mat == null:
		return
	_overlay_mat.set_shader_parameter("flash", amount)
	var tw := create_tween()
	tw.tween_method(
		func(v: float) -> void: _overlay_mat.set_shader_parameter("flash", v),
		amount, 0.0, 0.5)


# ---------------------------------------------------------------- internals
func _set_block(b: bool) -> void:
	_blocking = b
	if b:
		hide_prompt()


func _build() -> void:
	# reality overlay -- behind the readable HUD but above the game world
	var overlay := ColorRect.new()
	overlay.size = BASE
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.color = Color(1, 1, 1, 1)
	var shader := load("res://shaders/reality_overlay.gdshader")
	if shader:
		_overlay_mat = ShaderMaterial.new()
		_overlay_mat.shader = shader
		overlay.material = _overlay_mat
	add_child(overlay)

	# objective (top-left)
	_objective = _make_label(Vector2(10, 8), 10, Color(0.70, 0.78, 0.86))
	add_child(_objective)

	# pills (top-right)
	_pill_label = _make_label(Vector2(540, 8), 10, Color(0.86, 0.70, 0.74))
	_pill_label.size = Vector2(92, 14)
	_pill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_pill_label)

	# announcement banner (top-centre)
	_ann_panel = _make_panel(Color(0.05, 0.06, 0.10, 0.88), Color(0.35, 0.5, 0.7, 0.6))
	_ann_panel.position = Vector2(90, 24)
	_ann_panel.custom_minimum_size = Vector2(460, 0)
	_ann_panel.modulate.a = 0.0
	_ann_panel.visible = false
	_ann_label = Label.new()
	_ann_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ann_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ann_label.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	_ann_label.add_theme_font_size_override("font_size", 11)
	_ann_panel.add_child(_ann_label)
	add_child(_ann_panel)

	# interaction prompt (bottom-centre)
	_prompt = _make_label(Vector2(220, 304), 11, Color(0.95, 0.95, 0.8))
	_prompt.size = Vector2(200, 16)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.visible = false
	add_child(_prompt)

	# dialogue box (bottom-wide)
	_dialogue = _make_panel(Color(0.04, 0.05, 0.08, 0.94), Color(0.4, 0.55, 0.7, 0.7))
	_dialogue.position = Vector2(60, 282)
	_dialogue.custom_minimum_size = Vector2(520, 66)
	_dialogue.visible = false
	var dbox := VBoxContainer.new()
	dbox.add_theme_constant_override("separation", 4)
	_dialogue.add_child(dbox)
	_dialogue_name = Label.new()
	_dialogue_name.add_theme_color_override("font_color", Color(0.55, 0.8, 0.95))
	_dialogue_name.add_theme_font_size_override("font_size", 9)
	dbox.add_child(_dialogue_name)
	_dialogue_text = Label.new()
	_dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_text.custom_minimum_size = Vector2(500, 0)
	_dialogue_text.add_theme_font_size_override("font_size", 11)
	dbox.add_child(_dialogue_text)
	add_child(_dialogue)

	# ticket panel (centre, toggled)
	_ticket_panel = _make_panel(Color(0.10, 0.09, 0.07, 0.96), Color(0.7, 0.6, 0.3, 0.7))
	_ticket_panel.position = Vector2(210, 96)
	_ticket_panel.custom_minimum_size = Vector2(220, 150)
	_ticket_panel.visible = false
	_ticket_text = Label.new()
	_ticket_text.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	_ticket_text.add_theme_font_size_override("font_size", 12)
	_ticket_panel.add_child(_ticket_text)
	add_child(_ticket_panel)

	# choice layer (full-screen modal)
	_choice_layer = Control.new()
	_choice_layer.size = BASE
	_choice_layer.visible = false
	var dim := ColorRect.new()
	dim.size = BASE
	dim.color = Color(0, 0, 0, 0.66)
	_choice_layer.add_child(dim)
	var cpanel := _make_panel(Color(0.05, 0.06, 0.09, 0.98), Color(0.4, 0.55, 0.7, 0.8))
	cpanel.position = Vector2(160, 90)
	cpanel.custom_minimum_size = Vector2(320, 0)
	_choice_layer.add_child(cpanel)
	var cbox := VBoxContainer.new()
	cbox.add_theme_constant_override("separation", 8)
	cpanel.add_child(cbox)
	_choice_prompt = Label.new()
	_choice_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_choice_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_choice_prompt.custom_minimum_size = Vector2(300, 0)
	_choice_prompt.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
	cbox.add_child(_choice_prompt)
	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 6)
	cbox.add_child(_choice_box)
	add_child(_choice_layer)

	# fade (on top of everything)
	_fade = ColorRect.new()
	_fade.size = BASE
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.visible = false
	add_child(_fade)


func _make_label(pos: Vector2, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _make_panel(bg: Color, border: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", sb)
	return p
