extends CharacterBody2D
## Top-down 8-direction movement + "interact with the nearest thing" detection.
## Draws itself as a placeholder so the game runs before any art exists; swap the _draw()
## for a Sprite2D/AnimatedSprite2D child when art lands (movement/detection stay the same).

const SPEED := 80.0
const ACCEL := 900.0
const FRICTION := 1100.0

var _facing := Vector2.DOWN
var _current: Node = null   # nearest interactable in reach

@onready var _detector: Area2D = $InteractionDetector


func _ready() -> void:
	_detector.area_entered.connect(func(_a: Area2D) -> void: _update_nearest())
	_detector.area_exited.connect(func(_a: Area2D) -> void: _update_nearest())


func _physics_process(delta: float) -> void:
	# Freeze while a dialogue / menu is up so the same key can't double-trigger.
	if Hud.is_blocking():
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
		move_and_slide()
		return

	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir != Vector2.ZERO:
		velocity = velocity.move_toward(dir * SPEED, ACCEL * delta)
		_facing = dir
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	move_and_slide()
	queue_redraw()

	_update_nearest()

	if Input.is_action_just_pressed("pill"):
		_try_pill()
	if Input.is_action_just_pressed("ticket"):
		Hud.toggle_ticket()
	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept"):
		_try_interact()


func _update_nearest() -> void:
	var best: Node = null
	var best_dist := INF
	for a in _detector.get_overlapping_areas():
		if not a.has_method("interact") or not a.can_interact():
			continue
		var d := global_position.distance_squared_to(a.global_position)
		if d < best_dist:
			best_dist = d
			best = a
	if best != _current:
		_current = best
		if _current:
			Hud.show_prompt("[E] " + _current.prompt_label())
		else:
			Hud.hide_prompt()


func _try_interact() -> void:
	if _current and _current.can_interact():
		var target: Node = _current
		Hud.hide_prompt()
		await target.interact()
		_update_nearest()


func _try_pill() -> void:
	if GameState.use_pill():
		Audio.play_sfx("res://audio/sfx/pill.ogg")
		await Hud.say("", "You swallow the pill. The edges of the world go quiet, and something you were about to notice is gone.")
	else:
		await Hud.say("", "The bottle is empty. There is nothing left to forget with.")


func _draw() -> void:
	var body := Rect2(-6, -8, 12, 16)
	draw_rect(body, Color(0.86, 0.86, 0.92))
	draw_rect(body, Color(0.10, 0.10, 0.13), false, 1.0)
	draw_circle(_facing.normalized() * 7.0, 2.0, Color(0.25, 0.7, 0.9))
