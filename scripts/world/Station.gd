extends Node2D
class_name Station
## Builds a whole playable room from a single content Dictionary returned by _station_data().
##
## This is the heart of the "clean, reusable baseline": every location (train, both stations,
## the final car) is the same Station code driven by different data. To add content during the
## jam you edit a data array -- no new systems, no fragile scene wiring, no boilerplate.
##
## A subclass scene only overrides:
##   _station_data() -> Dictionary   (required) the room + its props
##   _on_ready(data)                 (optional) any per-room scripted logic
##   _provide_<name>() -> Array      (optional) live dialogue for a prop with "provider": name

const PLAYER := preload("res://scenes/player/Player.tscn")
const INTERACTABLE := preload("res://scenes/prefabs/Interactable.tscn")

var _entries := {}
var _player: Node2D


func _ready() -> void:
	var d := _station_data()
	_build_room(d)
	_spawn_props(d)
	_spawn_player(d)
	if d.has("on_enter_reality"):
		GameState.set_reality(d["on_enter_reality"])
	if d.has("objective"):
		GameState.set_objective(d["objective"])
	Audio.play_ambience(str(d.get("ambience", "")))
	_on_ready(d)
	if d.has("announcements"):
		Hud.announce_sequence(d["announcements"])


# ---- override points -------------------------------------------------------
func _station_data() -> Dictionary:
	return {}


func _on_ready(_d: Dictionary) -> void:
	pass


# ---- construction ----------------------------------------------------------
func _build_room(d: Dictionary) -> void:
	var size: Vector2 = d.get("room_size", Vector2(640, 360))

	var floor := Polygon2D.new()
	floor.polygon = PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])
	floor.color = d.get("floor_color", Color(0.10, 0.11, 0.14))
	floor.z_index = -10
	add_child(floor)

	_build_walls(size)
	_entries = d.get("entries", {"entry": size * 0.5})


func _build_walls(size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var t := 8.0
	var rects := [
		Rect2(-t, -t, size.x + 2.0 * t, t),       # top
		Rect2(-t, size.y, size.x + 2.0 * t, t),   # bottom
		Rect2(-t, 0, t, size.y),                  # left
		Rect2(size.x, 0, t, size.y),              # right
	]
	for r: Rect2 in rects:
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = r.size
		cs.shape = shape
		cs.position = r.position + r.size * 0.5
		body.add_child(cs)


func _spawn_props(d: Dictionary) -> void:
	for p: Dictionary in d.get("props", []):
		var node: Interactable = INTERACTABLE.instantiate()
		node.data = p
		node.position = p.get("pos", Vector2.ZERO)
		add_child(node)
		if p.has("provider"):
			node.lines_provider = Callable(self, "_provide_" + str(p["provider"]))


func _spawn_player(d: Dictionary) -> void:
	_player = PLAYER.instantiate()
	var size: Vector2 = d.get("room_size", Vector2(640, 360))
	var spawn: String = SceneDirector.pending_spawn
	_player.position = _entries.get(spawn, _entries.get("entry", size * 0.5))
	add_child(_player)

	var cam: Camera2D = _player.get_node_or_null("Camera2D")
	if cam:
		cam.limit_left = 0
		cam.limit_top = 0
		cam.limit_right = int(size.x)
		cam.limit_bottom = int(size.y)
		cam.make_current()
