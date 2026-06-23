extends Node2D
class_name Station
## Builds a whole explorable location from a single content Dictionary returned by
## _station_data(). Every location (train, stations, the final car) is THIS code driven by
## different data -- to add content you edit a data array, no new systems.
##
## Supports, all data-driven and optional:
##   - multi-room / hallway layouts (floors + interior walls), camera scrolls the whole world
##   - reality-gated geometry: walls that OPEN and holes that APPEAR as the truth leaks in
##   - holes / pits: fall in -> you're dropped back at the entry (disorienting, not lethal)
##   - event zones with effects (move a prop, open a wall, spawn a hole, reveal a figure,
##     shake, flash, sound, announce...) -> "looks safe, betrays you" traps in one line
##   - darkness + a player lantern (runtime-generated, no art)
##
## A subclass scene only overrides:
##   _station_data() -> Dictionary   (required) the world + its props/holes/events
##   _on_ready(data)                 (optional) any per-room scripted logic
##   _provide_<name>() -> Array      (optional) live dialogue for a prop with "provider": name

const PLAYER := preload("res://scenes/player/Player.tscn")
const INTERACTABLE := preload("res://scenes/prefabs/Interactable.tscn")

var _entries := {}
var _world_size := Vector2(640, 360)
var _player                   # the Player instance (untyped so we can call shake()/etc.)
var _by_id := {}              # id -> node (props, walls, holes) for events to target
var _reality_walls := []      # wall holders that toggle solidity with reality
var _reality_holes := []      # hole holders that toggle existence with reality


func _ready() -> void:
	var d := _station_data()
	_build_world(d)
	_spawn_player(d)
	_spawn_props(d)
	_spawn_holes(d)
	_spawn_events(d)
	_setup_darkness(d)
	GameState.reality_changed.connect(_on_world_reality)
	if d.has("on_enter_reality"):
		GameState.set_reality(d["on_enter_reality"])
	if d.has("objective"):
		GameState.set_objective(d["objective"])
	GameState.input_mode = str(d.get("input_mode", "normal"))   # resets each room unless set
	GameState.set_drift(float(d.get("sanity_drift", 0.0)))
	Audio.play_ambience(str(d.get("ambience", "")))
	_on_ready(d)
	if d.has("announcements"):
		Hud.announce_sequence(d["announcements"])


# ---- override points -------------------------------------------------------
func _station_data() -> Dictionary:
	return {}


func _on_ready(_d: Dictionary) -> void:
	pass


# ---- world construction ----------------------------------------------------
func _build_world(d: Dictionary) -> void:
	var layout: Dictionary = d.get("layout", {})
	_world_size = layout.get("world_size", d.get("room_size", Vector2(640, 360)))

	var floors: Array = layout.get("floors", [])
	if floors.is_empty():
		floors = [{"rect": Rect2(Vector2.ZERO, _world_size), "color": d.get("floor_color", Color(0.10, 0.11, 0.14))}]
	for f: Dictionary in floors:
		var poly := Polygon2D.new()
		poly.polygon = _rect_points(f.get("rect", Rect2(Vector2.ZERO, _world_size)))
		poly.color = f.get("color", d.get("floor_color", Color(0.10, 0.11, 0.14)))
		poly.z_index = -10
		add_child(poly)

	for w: Dictionary in layout.get("walls", []):
		_build_wall(w)

	_build_border(_world_size)
	_entries = d.get("entries", {"entry": _world_size * 0.5})


## A visible interior wall block. Options:
##   "id"            -- so events can open/close it
##   "solid_in"      -- array of reality states it is solid in (a passage the truth can open)
##   "fake": true    -- looks solid, has NO collision (walk straight through the wall)
##   "invisible_solid": true -- collision with NO visual (an unseen wall in open space)
func _build_wall(w: Dictionary) -> void:
	var rect: Rect2 = w.get("rect", Rect2())
	var holder := Node2D.new()
	add_child(holder)

	if not bool(w.get("invisible_solid", false)):
		var poly := Polygon2D.new()
		poly.polygon = _rect_points(rect)
		poly.color = w.get("color", Color(0.05, 0.05, 0.08))
		poly.z_index = -6
		holder.add_child(poly)

	if not bool(w.get("fake", false)):
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		holder.add_child(body)
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		cs.shape = shape
		cs.position = rect.position + rect.size * 0.5
		body.add_child(cs)

	if w.has("id"):
		_by_id[str(w["id"])] = holder
	if w.has("solid_in"):
		holder.set_meta("solid_in", w["solid_in"])
		_reality_walls.append(holder)
		_apply_wall_reality(holder)


## Invisible collision around the world bounds.
func _build_border(size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var t := 12.0
	var rects := [
		Rect2(-t, -t, size.x + 2.0 * t, t),
		Rect2(-t, size.y, size.x + 2.0 * t, t),
		Rect2(-t, 0, t, size.y),
		Rect2(size.x, 0, t, size.y),
	]
	for r: Rect2 in rects:
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = r.size
		cs.shape = shape
		cs.position = r.position + r.size * 0.5
		body.add_child(cs)


# ---- props / holes / events ------------------------------------------------
func _spawn_props(d: Dictionary) -> void:
	for p: Dictionary in d.get("props", []):
		var node: Interactable = INTERACTABLE.instantiate()
		node.data = p
		node.position = p.get("pos", Vector2.ZERO)
		add_child(node)
		if p.has("provider"):
			node.lines_provider = Callable(self, "_provide_" + str(p["provider"]))
		if p.has("id"):
			_by_id[str(p["id"])] = node


func _spawn_holes(d: Dictionary) -> void:
	for h: Dictionary in d.get("holes", []):
		_build_hole(h)


## A pit. Walk in and you're dropped back at the entry (Iron-Lung disorientation, not death).
## "reality_min" makes it a Trap-Adventure floor that only opens up once the truth leaks in.
func _build_hole(h: Dictionary) -> void:
	var rect: Rect2 = h.get("rect", Rect2())
	var holder := Node2D.new()
	add_child(holder)

	var poly := Polygon2D.new()
	poly.polygon = _rect_points(rect)
	poly.color = h.get("color", Color(0.0, 0.0, 0.0, 1.0))
	poly.z_index = -7
	holder.add_child(poly)

	var zone := Area2D.new()
	zone.collision_layer = 0
	zone.collision_mask = 2
	zone.position = rect.position + rect.size * 0.5
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	cs.shape = shape
	zone.add_child(cs)
	holder.add_child(zone)
	zone.body_entered.connect(func(b: Node2D) -> void: _on_hole(b, h))

	if h.has("id"):
		_by_id[str(h["id"])] = holder
	if h.has("reality_min"):
		holder.set_meta("reality_min", h["reality_min"])
		_reality_holes.append(holder)
		_apply_hole_reality(holder)


func _on_hole(body: Node, h: Dictionary) -> void:
	if not body.is_in_group("player"):
		return
	# A "trap" is just a region with a look (its color) and a behaviour. Because the look is
	# fully free, you can paint a harmless floor to look deadly (lava) and a deadly trap to look
	# safe (a tidy walkway) -- the Trap-Adventure inversion. Default behaviour drops the player
	# back at a respawn point; "no_fall" runs only the effects.
	if not bool(h.get("no_fall", false)) and _player:
		var respawn: Vector2 = h.get("respawn", _entries.get("respawn", _entries.get("entry", _world_size * 0.5)))
		_player.global_position = respawn
		_player.shake(float(h.get("shake", 7.0)), 0.4)
	Hud.flash(float(h.get("flash", 0.55)))
	Audio.play_sfx(str(h.get("sound", "")))
	if h.has("announce"):
		Hud.announce(str(h["announce"]))
	if bool(h.get("nudge_truth", false)):
		GameState.nudge_truth()
	if h.has("effects"):
		_run_effects(h["effects"])


func _spawn_events(d: Dictionary) -> void:
	for e: Dictionary in d.get("events", []):
		_build_event(e)


## An invisible trigger zone. When the player enters and conditions pass, it runs its effects.
## This is the trap toolkit: a safe-looking spot that betrays you in one data entry.
func _build_event(e: Dictionary) -> void:
	var rect: Rect2 = e.get("rect", Rect2())
	var zone := Area2D.new()
	zone.collision_layer = 0
	zone.collision_mask = 2
	zone.position = rect.position + rect.size * 0.5
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	cs.shape = shape
	zone.add_child(cs)
	add_child(zone)
	zone.set_meta("data", e)
	zone.set_meta("fired", false)
	zone.body_entered.connect(func(b: Node2D) -> void: _on_event_zone(zone, b))


func _on_event_zone(zone: Area2D, body: Node) -> void:
	if not body.is_in_group("player"):
		return
	var e: Dictionary = zone.get_meta("data")
	if bool(zone.get_meta("fired")) and bool(e.get("once", true)):
		return
	if e.has("requires_flag") and not GameState.has_flag(str(e["requires_flag"])):
		return
	zone.set_meta("fired", true)
	_run_effects(e.get("effects", []))


func _run_effects(effects: Array) -> void:
	for fx: Dictionary in effects:
		_run_effect(fx)


func _run_effect(fx: Dictionary) -> void:
	match str(fx.get("do", "")):
		"move":
			_fx_move(fx)
		"open":
			_fx_set_wall(fx, false)
		"close":
			_fx_set_wall(fx, true)
		"reveal":
			_fx_reveal(fx)
		"hole":
			_build_hole(fx)
		"shake":
			if _player:
				_player.shake(float(fx.get("amount", 6.0)), float(fx.get("time", 0.4)))
		"flash":
			Hud.flash(float(fx.get("amount", 0.5)))
		"sound":
			Audio.play_sfx(str(fx.get("path", "")))
		"announce":
			Hud.announce(str(fx.get("text", "")))
		"set_flag":
			GameState.set_flag(str(fx.get("flag", "")))
		"nudge_truth":
			GameState.nudge_truth()
		"objective":
			GameState.set_objective(str(fx.get("text", "")))
		"controls":
			GameState.input_mode = str(fx.get("mode", "normal"))
		"tilt":
			if _player:
				_player.lurch_tilt(float(fx.get("deg", 8.0)), float(fx.get("time", 0.6)))
		"zoom":
			if _player:
				_player.set_zoom(float(fx.get("to", 1.15)), float(fx.get("time", 0.6)))


func _fx_move(fx: Dictionary) -> void:
	var node = _by_id.get(str(fx.get("target", "")), null)
	if node == null:
		return
	var to: Vector2 = node.position + fx["by"] if fx.has("by") else fx.get("to", node.position)
	var tw := create_tween()
	tw.tween_property(node, "position", to, float(fx.get("time", 0.4)))


func _fx_set_wall(fx: Dictionary, solid: bool) -> void:
	var holder = _by_id.get(str(fx.get("target", "")), null)
	if holder != null:
		_set_wall_solid(holder, solid)


func _fx_reveal(fx: Dictionary) -> void:
	var node = _by_id.get(str(fx.get("target", "")), null)
	if node and node.has_method("force_reveal"):
		node.force_reveal()


# ---- reality-gated geometry ------------------------------------------------
func _on_world_reality(_state: int) -> void:
	for w in _reality_walls:
		_apply_wall_reality(w)
	for h in _reality_holes:
		_apply_hole_reality(h)


func _apply_wall_reality(holder: Node) -> void:
	var solid_in: Array = holder.get_meta("solid_in")
	_set_wall_solid(holder, solid_in.has(GameState.reality))


func _set_wall_solid(holder: Node, solid: bool) -> void:
	for c in holder.get_children():
		var poly := c as Polygon2D
		if poly:
			poly.visible = solid
			continue
		var body := c as StaticBody2D
		if body:
			for cc in body.get_children():
				var col := cc as CollisionShape2D
				if col:
					col.disabled = not solid


func _apply_hole_reality(holder: Node) -> void:
	var active := GameState.reality >= int(holder.get_meta("reality_min"))
	for c in holder.get_children():
		var poly := c as Polygon2D
		if poly:
			poly.visible = active
			continue
		var zone := c as Area2D
		if zone:
			zone.monitoring = active


# ---- player + camera -------------------------------------------------------
func _spawn_player(d: Dictionary) -> void:
	_player = PLAYER.instantiate()
	var spawn: String = SceneDirector.pending_spawn
	_player.position = _entries.get(spawn, _entries.get("entry", _world_size * 0.5))
	add_child(_player)

	var cam: Camera2D = _player.get_node_or_null("Camera2D")
	if cam:
		cam.limit_left = 0
		cam.limit_top = 0
		cam.limit_right = int(_world_size.x)
		cam.limit_bottom = int(_world_size.y)
		cam.make_current()


# ---- darkness + lantern ----------------------------------------------------
## Optional darkness + a lantern that follows the player. The light texture is generated at
## runtime so this needs NO art. Enable per-room with data "dark": true. UI stays lit.
func _setup_darkness(d: Dictionary) -> void:
	if not bool(d.get("dark", false)):
		return
	var cm := CanvasModulate.new()
	cm.color = d.get("dark_color", Color(0.40, 0.40, 0.46))
	add_child(cm)

	var light := PointLight2D.new()
	light.texture = _make_light_texture(int(d.get("light_radius", 120)))
	light.energy = float(d.get("light_energy", 1.3))
	light.z_index = -5
	_player.add_child(light)


func _make_light_texture(radius: int) -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = radius * 2
	tex.height = radius * 2
	return tex


# ---- helpers ---------------------------------------------------------------
func _rect_points(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		r.position,
		r.position + Vector2(r.size.x, 0),
		r.position + r.size,
		r.position + Vector2(0, r.size.y),
	])
