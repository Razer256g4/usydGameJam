extends Control
## Title screen. Press E to board.

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.02, 0.04)
	add_child(bg)

	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 12)
	add_child(v)

	_centered(v, "PLATFORM 0", 40, Color(0.9, 0.92, 0.95))
	_centered(v, "a train that won't reach your stop\nuntil you remember who was left behind", 13, Color(0.7, 0.72, 0.78))
	_centered(v, "\nWASD / Arrows  move      E  interact      Q  pill      T  ticket\n\nPress E to board", 12, Color(0.55, 0.57, 0.62))

	GameState.set_reality(GameState.Reality.STABLE)
	Audio.stop_ambience()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		GameState.reset()
		SceneDirector.change_scene("res://scenes/world/TrainCabin.tscn", "entry")


func _centered(parent: Node, text: String, font_size: int, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
