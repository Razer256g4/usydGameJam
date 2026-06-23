extends Control
## Shows the ending card chosen by GameState.pending_ending, then offers a restart.

const ENDINGS := {
	"good": {
		"title": "YOU STAYED",
		"body": "\"I saw you. I should have stayed.\"\n\nThe train reaches the actual destination. They step off first -- and this time, you follow.",
	},
	"bittersweet": {
		"title": "TOO LATE, BUT TRUE",
		"body": "You remembered, even through everything you took to forget. It doesn't undo it.\n\nBut they heard you say it.",
	},
	"loop": {
		"title": "NOT YOUR PROBLEM",
		"body": "\"I don't know you.\"\n\nThe doors close. The face fades. The train pulls out of a station with no name, and begins again.",
	},
	"denial": {
		"title": "FACTORY RESET",
		"body": "You took the last pill. The world goes clean and quiet, and you reach your stop.\n\nIn the dark window, you cast no reflection.",
	},
	"conductor": {
		"title": "THE NEXT ONE",
		"body": "You stayed. A new passenger boards with no face. The announcement begins --\n\nand it is your voice now.",
	},
}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Audio.stop_ambience()
	GameState.set_reality(GameState.Reality.STABLE)   # keep the ending card readable
	var data: Dictionary = ENDINGS.get(GameState.pending_ending, ENDINGS["loop"])

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.03, 0.05)
	add_child(bg)

	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 18)
	add_child(v)

	_label(v, data["title"], 30, Color(0.92, 0.9, 0.85), 0)
	_label(v, data["body"], 13, Color(0.78, 0.8, 0.85), 480)
	_label(v, "\nPress E to ride again", 12, Color(0.5, 0.52, 0.58), 0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		GameState.reset()
		SceneDirector.change_scene("res://scenes/world/TrainCabin.tscn", "entry")


func _label(parent: Node, text: String, font_size: int, color: Color, wrap_width: int) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if wrap_width > 0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(wrap_width, 0)
	parent.add_child(l)
