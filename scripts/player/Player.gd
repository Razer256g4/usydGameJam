extends CharacterBody2D
## Top-down 8-direction movement + "interact with the nearest thing" detection.
## Draws a placeholder box so the game runs before any art exists. To use real art, assign a
## SpriteFrames to `sprite_frames` on Player.tscn (animations named idle_/walk_ + down/up/
## left/right); movement and detection are untouched.

const SPEED := 80.0
const ACCEL := 900.0
const FRICTION := 1100.0

## Drop-in art: assign in the editor on Player.tscn. Null -> placeholder box.
@export var sprite_frames: SpriteFrames

var _facing := Vector2.DOWN
var _current: Node = null   # nearest interactable in reach
var _anim: AnimatedSprite2D
var _has_anim := false
var _shake_amp := 0.0
var _shake_dur := 0.0
var _shake_time := 0.0

@onready var _detector: Area2D = $InteractionDetector
@onready var _camera: Camera2D = $Camera2D


func _ready() -> void:
	add_to_group("player")   # so props / events can find the player
	_detector.area_entered.connect(func(_a: Area2D) -> void: _update_nearest())
	_detector.area_exited.connect(func(_a: Area2D) -> void: _update_nearest())
	if sprite_frames:
		_anim = AnimatedSprite2D.new()
		_anim.sprite_frames = sprite_frames
		add_child(_anim)
		_has_anim = true


func _physics_process(delta: float) -> void:
	_update_shake(delta)
	# Freeze while a dialogue / menu is up so the same key can't double-trigger.
	if Hud.is_blocking():
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
		move_and_slide()
		_update_anim(false)
		return

	var dir := _apply_input_mode(Input.get_vector("move_left", "move_right", "move_up", "move_down"))
	if dir != Vector2.ZERO:
		velocity = velocity.move_toward(dir * SPEED, ACCEL * delta)
		_facing = dir
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	move_and_slide()
	_update_anim(dir != Vector2.ZERO)
	if not _has_anim:
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


func _update_anim(moving: bool) -> void:
	if not _has_anim:
		return
	var dir := _facing_name()
	var anim := ("walk_" if moving else "idle_") + dir
	if not _anim.sprite_frames.has_animation(anim):
		anim = "walk_" + dir                      # fall back to walk set if no idle set
	if not _anim.sprite_frames.has_animation(anim):
		var names := _anim.sprite_frames.get_animation_names()
		anim = names[0] if names.size() > 0 else ""
	if anim != "" and _anim.animation != anim:
		_anim.play(anim)


func _facing_name() -> String:
	if absf(_facing.x) > absf(_facing.y):
		return "right" if _facing.x > 0.0 else "left"
	return "down" if _facing.y > 0.0 else "up"


## The world doesn't move the way you tell it to. Driven by GameState.input_mode.
func _apply_input_mode(v: Vector2) -> Vector2:
	match GameState.input_mode:
		"mirror":
			return Vector2(-v.x, v.y)
		"invert":
			return -v
		"swap":
			return Vector2(v.y, v.x)
		_:
			return v


## A brief camera tip-and-return -- the floor lurches under you, then settles.
func lurch_tilt(degrees: float = 8.0, time: float = 0.6) -> void:
	if _camera == null:
		return
	var tw := create_tween()
	tw.tween_property(_camera, "rotation_degrees", degrees, time * 0.5)
	tw.tween_property(_camera, "rotation_degrees", 0.0, time * 0.5)


## Push the camera in/out -- "the walls feel closer". 1.0 = normal, >1 zooms in.
func set_zoom(factor: float = 1.15, time: float = 0.6) -> void:
	if _camera == null:
		return
	var tw := create_tween()
	tw.tween_property(_camera, "zoom", Vector2(factor, factor), time)


## Camera shake -- used by trap stings (holes, things lunging, lights failing).
func shake(amount: float = 5.0, duration: float = 0.35) -> void:
	_shake_amp = amount
	_shake_dur = maxf(duration, 0.01)
	_shake_time = _shake_dur


func _update_shake(delta: float) -> void:
	if _camera == null:
		return
	if _shake_time > 0.0:
		_shake_time -= delta
		var k := _shake_time / _shake_dur
		_camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_amp * k
	elif _camera.offset != Vector2.ZERO:
		_camera.offset = Vector2.ZERO


func _draw() -> void:
	if _has_anim:
		return   # real art is showing
	var body := Rect2(-6, -8, 12, 16)
	draw_rect(body, Color(0.86, 0.86, 0.92))
	draw_rect(body, Color(0.10, 0.10, 0.13), false, 1.0)
	draw_circle(_facing.normalized() * 7.0, 2.0, Color(0.25, 0.7, 0.9))
