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

signal interacted(node: Node)


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	monitorable = true
	monitoring = false
	if not data.is_empty():
		_apply_data()
	_build_visual()
	GameState.reality_changed.connect(func(_s: int) -> void: queue_redraw())
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


func _draw() -> void:
	var r := Rect2(-size * 0.5, size)
	draw_rect(r, color)
	draw_rect(r, color.lightened(0.3), false, 1.0)
	# subtle "the truth is here" tell when reality has fully slipped
	if GameState.reality == GameState.Reality.MEMORY_LEAK and text_leak.strip_edges() != "":
		draw_rect(r.grow(2.0), Color(0.85, 0.1, 0.12, 0.5), false, 1.0)


# ---------------------------------------------------------------- player-facing API
func prompt_label() -> String:
	return str(data.get("verb", "Examine")) + " " + display_name


func can_interact() -> bool:
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
