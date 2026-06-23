extends Area2D
class_name Interactable
## The one reusable "thing you can interact with". This is where the Flip the Script theme
## actually lives: the SAME object shows different truth depending on the current reality
## state. Pills hide clues; chasing the truth reveals them.
##
## Configured by a `data` Dictionary (set by Station when spawned from content data) or by the
## @export fields when hand-placed in the editor. Behaviour is picked by `kind`; the line(s)
## shown are picked by GameState.reality.

enum Kind { EXAMINE, DOOR, FRAGMENT, ROLE_TERMINAL, SCREEN_TERMINAL, FINAL_CHOICE, FLAG_SET }

@export var display_name: String = "Object"
@export var kind: int = Kind.EXAMINE
@export var size: Vector2 = Vector2(20, 24)
@export var color: Color = Color(0.4, 0.42, 0.5)
@export_multiline var text_stable: String = ""
@export_multiline var text_uncertain: String = ""
@export_multiline var text_leak: String = ""

## Filled in from content data when spawned by a Station (see Station.gd / the *.gd scenes).
var data := {}
## Optional: a Callable returning an Array of dialogue lines, evaluated at interact time.
## Used for things whose text depends on live state (e.g. the victim's changing dialogue).
var lines_provider: Callable

var _used := false
var _label: Label
var _sprite: Sprite2D       # optional art; null = placeholder box is drawn instead
var _has_sprite := false    # true only once a real texture has loaded

# uncanny behaviours (data-driven, all optional)
var _hidden := false                       # hidden_until_flag / hidden_until_reality
var _dyn := false                          # moves_when_unseen
var _notifier: VisibleOnScreenNotifier2D
var _player: Node2D
var _move_accum := 0.0
var _cycle_idx := 0                         # for "cycle": the sign never says the same thing twice
var _was_on_screen := true
var _unseen_applied := false               # for "unseen_becomes": change once, when you look back

signal interacted(node: Node)


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	monitorable = true
	monitoring = false
	if not data.is_empty():
		_apply_data()
	_build_visual()
	GameState.reality_changed.connect(_on_reality_changed)
	if bool(data.get("victim", false)):
		GameState.victim_changed.connect(func(_st: int) -> void: _refresh_sprite())
	_refresh_sprite()
	_setup_hidden()
	_setup_dynamic()
	queue_redraw()


func _on_reality_changed(_s: int) -> void:
	_refresh_sprite()
	if _hidden and _reveal_met():
		_reveal()
	queue_redraw()


func _apply_data() -> void:
	display_name = data.get("name", display_name)
	kind = data.get("kind", kind)
	size = data.get("size", size)
	color = data.get("color", color)
	text_stable = data.get("stable", "")
	text_uncertain = data.get("uncertain", "")
	text_leak = data.get("leak", "")


func _build_visual() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	add_child(shape)

	_label = Label.new()
	_label.text = display_name
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_color", Color(0.8, 0.82, 0.9, 0.8))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = Vector2(90, 12)
	_label.position = Vector2(-45, -size.y * 0.5 - 14)
	add_child(_label)

	# optional art node -- drops in over the placeholder box (box stays as fallback)
	if _declares_sprite():
		_sprite = Sprite2D.new()
		_sprite.centered = true
		_sprite.z_index = 1
		add_child(_sprite)


## Pick the texture for the current reality / victim stage; falls back to the box if the file
## isn't present yet, so declaring sprite paths never makes a prop vanish.
func _refresh_sprite() -> void:
	if _sprite == null:
		return
	var tex := _load_tex(_sprite_path_for_state())
	_sprite.texture = tex
	_sprite.visible = tex != null
	_has_sprite = tex != null
	queue_redraw()


func _sprite_path_for_state() -> String:
	if bool(data.get("victim", false)):
		var stages: Array = data.get("stage_sprites", [])
		if stages.is_empty():
			return ""
		return str(stages[clampi(GameState.victim_stage, 0, stages.size() - 1)])
	match GameState.reality:
		GameState.Reality.STABLE:
			return str(data.get("sprite_stable", data.get("sprite", "")))
		GameState.Reality.MEMORY_LEAK:
			return str(data.get("sprite_leak", data.get("sprite", "")))
		_:
			return str(data.get("sprite", data.get("sprite_stable", "")))


func _declares_sprite() -> bool:
	return data.has("sprite") or data.has("sprite_stable") or data.has("sprite_leak") or data.has("stage_sprites")


func _load_tex(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path)


func _draw() -> void:
	if _has_sprite:
		return   # real art is showing; skip the placeholder
	var r := Rect2(-size * 0.5, size)
	draw_rect(r, color)
	draw_rect(r, color.lightened(0.3), false, 1.0)
	# subtle "the truth is here" tell when reality has fully slipped
	if GameState.reality == GameState.Reality.MEMORY_LEAK and text_leak.strip_edges() != "":
		draw_rect(r.grow(2.0), Color(0.85, 0.1, 0.12, 0.5), false, 1.0)


# ---------------------------------------------------------------- player-facing API
func prompt_label() -> String:
	# "prompt_name" lets the prompt lie about what a thing is (it reads as a bench; it isn't)
	return str(data.get("verb", "Examine")) + " " + str(data.get("prompt_name", display_name))


func can_interact() -> bool:
	if _hidden:
		return false
	if _used and bool(data.get("one_shot", _default_one_shot())):
		return false
	if not _requirements_met():
		# only interactable (to show the "locked" line) if we have one to show
		return data.has("locked")
	return true


func interact() -> void:
	if not _requirements_met():
		var locked := str(data.get("locked", ""))
		if locked != "":
			await Hud.say(display_name, locked)
		return
	await _show_text()
	await _perform()
	_used = true
	# reactive announcer: a prop can make the PA respond when you touch it
	# (e.g. the seat -> "Please remain seated."). Fire-and-forget over the banner.
	if data.has("announce"):
		Hud.announce(str(data["announce"]))
	interacted.emit(self)


# ---------------------------------------------------------------- internals
func _requirements_met() -> bool:
	var req := str(data.get("requires_flag", ""))
	if req != "" and not GameState.has_flag(req):
		return false
	var reqf := str(data.get("requires_fragments", ""))
	if reqf != "" and not GameState.fragments_complete(reqf):
		return false
	return true


func _default_one_shot() -> bool:
	return kind == Kind.FRAGMENT


func _show_text() -> void:
	if lines_provider.is_valid():
		await Hud.say_sequence(lines_provider.call())
		return
	# "cycle": a sign / voice that refuses to say the same thing twice
	if data.has("cycle"):
		var arr: Array = data["cycle"]
		if not arr.is_empty():
			await Hud.say(display_name, str(arr[_cycle_idx % arr.size()]))
			_cycle_idx += 1
			return
	var t := _reality_text()
	if t.strip_edges() != "":
		await Hud.say(display_name, t)


func _reality_text() -> String:
	match GameState.reality:
		GameState.Reality.STABLE:
			return text_stable if text_stable != "" else text_uncertain
		GameState.Reality.MEMORY_LEAK:
			return text_leak if text_leak != "" else text_uncertain
		_:
			return text_uncertain if text_uncertain != "" else text_stable


func _perform() -> void:
	match kind:
		Kind.DOOR:
			# don't await -- this node gets freed by the scene change
			SceneDirector.change_scene(str(data.get("target_scene", "")), str(data.get("target_spawn", "entry")))
		Kind.FRAGMENT:
			GameState.collect_fragment(str(data.get("set_id", "frag")), str(data.get("piece", "?")), int(data.get("total", 3)))
			if bool(data.get("nudge_truth", false)):
				GameState.nudge_truth()
			queue_free()
		Kind.FLAG_SET:
			_apply_success_effects()
			if data.has("becomes_name"):
				display_name = str(data["becomes_name"])
				if _label:
					_label.text = display_name
				_refresh_sprite()
				queue_redraw()
		Kind.ROLE_TERMINAL:
			await _do_role()
		Kind.SCREEN_TERMINAL:
			await _do_screens()
		Kind.FINAL_CHOICE:
			await _do_final()


## Shared "you did the right thing" effects, data-driven so any object can grant them.
func _apply_success_effects() -> void:
	if data.has("sets_flag"):
		GameState.set_flag(str(data["sets_flag"]))
	if bool(data.get("nudge_truth", false)):
		GameState.nudge_truth()
	if data.has("then_objective"):
		GameState.set_objective(str(data["then_objective"]))


func _do_role() -> void:
	var options: Array = data.get("options", [])
	var picked: String = await Hud.choice(str(data.get("prompt", "SELECT ROLE")), options)
	if picked == str(data.get("correct", "witness")):
		GameState.set_flag("accepted_witness")
		_apply_success_effects()
		data["one_shot"] = true   # lock the machine once you've answered honestly
		if data.has("on_correct"):
			await Hud.say("TICKET MACHINE", str(data["on_correct"]))
	else:
		if data.has("on_wrong"):
			await Hud.say("TICKET MACHINE", str(data["on_wrong"]))
		_used = false   # let the player try again


func _do_screens() -> void:
	var lines: Array = []
	for s: Dictionary in data.get("screens", []):
		var req := str(s.get("req", ""))
		if req != "" and not GameState.has_flag(req):
			continue
		var req_reality := int(s.get("req_reality", -1))
		if req_reality != -1 and GameState.reality < req_reality:
			continue
		lines.append({"name": s.get("name", "MONITOR"), "text": s.get("text", "")})
	if lines.is_empty():
		lines.append({"name": "MONITOR", "text": "The screens show only static."})
	await Hud.say_sequence(lines)
	_apply_success_effects()


func _do_final() -> void:
	var options: Array = data.get("options", [])
	var picked: String = await Hud.choice(str(data.get("prompt", "...")), options)
	GameState.pending_ending = GameState.get_ending(picked)
	SceneDirector.change_scene("res://scenes/ui/EndingScreen.tscn")


# ---------------------------------------------------------------- uncanny: hidden until revealed
## A prop that doesn't exist until a flag/reality condition is met, then "appears" -- the
## friendly thing that arrives wrong. Set "hidden_until_flag" and/or "hidden_until_reality".
func _setup_hidden() -> void:
	if not (data.has("hidden_until_flag") or data.has("hidden_until_reality")):
		return
	if data.has("hidden_until_flag"):
		GameState.flag_changed.connect(_on_flag_for_reveal)
	_hidden = not _reveal_met()
	_apply_hidden()


func _on_flag_for_reveal(_flag: String, _value: Variant) -> void:
	if _hidden and _reveal_met():
		_reveal()


func _reveal_met() -> bool:
	if data.has("hidden_until_flag") and not GameState.has_flag(str(data["hidden_until_flag"])):
		return false
	if data.has("hidden_until_reality") and GameState.reality < int(data["hidden_until_reality"]):
		return false
	return true


func _apply_hidden() -> void:
	visible = not _hidden
	monitorable = not _hidden   # the player's detector ignores it while hidden


func _reveal() -> void:
	if not _hidden:
		return
	_hidden = false
	_apply_hidden()
	if data.has("reveal_sound"):
		Audio.play_sfx(str(data["reveal_sound"]))
	if data.has("reveal_announce"):
		Hud.announce(str(data["reveal_announce"]))
	Hud.flash(float(data.get("reveal_flash", 0.35)))
	_refresh_sprite()
	queue_redraw()


## Called by Station events to force a reveal regardless of condition.
func force_reveal() -> void:
	_hidden = true   # ensure _reveal() runs its stinger
	_reveal()


# ---------------------------------------------------------------- uncanny: moves when unseen
## SCP-173 / "that wasn't there before": creeps toward you only while off-screen. Set
## "moves_when_unseen": true; tune "move_step", "move_interval", "move_min".
func _setup_dynamic() -> void:
	_dyn = bool(data.get("moves_when_unseen", false))
	if not _dyn and not data.has("unseen_becomes"):
		set_process(false)
		return
	_notifier = VisibleOnScreenNotifier2D.new()
	_notifier.rect = Rect2(-size * 0.5, size)
	add_child(_notifier)
	set_process(true)


func _process(delta: float) -> void:
	if _hidden or _notifier == null:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	var on_screen := _notifier.is_on_screen()

	# changes-when-unseen: it's different when you look back
	if not _unseen_applied and data.has("unseen_becomes") and on_screen and not _was_on_screen:
		_apply_unseen_becomes()
	_was_on_screen = on_screen

	# moves-when-unseen: creeps closer only while you aren't looking
	if _dyn and _player != null and not on_screen:
		_move_accum += delta
		if _move_accum >= float(data.get("move_interval", 0.6)):
			_move_accum -= float(data.get("move_interval", 0.6))
			var to_player := _player.global_position - global_position
			if to_player.length() > float(data.get("move_min", 28.0)):
				global_position += to_player.normalized() * float(data.get("move_step", 26.0))
				queue_redraw()
	elif on_screen:
		_move_accum = 0.0


func _apply_unseen_becomes() -> void:
	_unseen_applied = true
	var u: Dictionary = data["unseen_becomes"]
	if u.has("name"):
		display_name = str(u["name"])
		if _label:
			_label.text = display_name
	if u.has("color"):
		color = u["color"]
	if u.has("stable"):
		text_stable = str(u["stable"])
	if u.has("uncertain"):
		text_uncertain = str(u["uncertain"])
	if u.has("leak"):
		text_leak = str(u["leak"])
	if bool(u.get("flash", true)):
		Hud.flash(0.3)
	_refresh_sprite()
	queue_redraw()
