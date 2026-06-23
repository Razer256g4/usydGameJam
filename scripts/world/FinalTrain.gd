extends Station
## The final car. The victim sits opposite, face revealed. The ticket finally says ANSWER.
## One interaction -- the passenger -- opens the four-way final choice that picks the ending.

func _station_data() -> Dictionary:
	return {
		"title": "Actual Destination",
		"room_size": Vector2(640, 360),
		"floor_color": Color(0.08, 0.07, 0.10),
		"entries": {"from_platform": Vector2(120, 300), "entry": Vector2(120, 300)},
		"on_enter_reality": GameState.Reality.MEMORY_LEAK,
		"objective": "Answer them.",
		"announcements": ["Now arriving at: Actual Destination.", "This service terminates here."],
		"ambience": "res://audio/ambience/final.ogg",
		"props": [
			{
				"kind": Interactable.Kind.EXAMINE, "name": "Window", "pos": Vector2(150, 70),
				"size": Vector2(64, 28), "color": Color(0.16, 0.20, 0.30), "verb": "Look through the",
				"stable": "The glass shows the platform you finally remember.",
				"uncertain": "Outside, lit at last: the station name. WITNESS.",
				"leak": "Your reflection is missing from the glass. Only theirs remains.",
			},
			{
				"kind": Interactable.Kind.EXAMINE, "name": "Your Reflection", "pos": Vector2(150, 120),
				"size": Vector2(40, 24), "color": Color(0.18, 0.26, 0.34), "verb": "Look at",
				"stable": "You, in the dark glass. Calm. Composed.",
				"uncertain": "In the glass you are already sitting down. You are still standing.",
				"leak": "Your reflection turns to face the passenger a moment before you do.",
				"unseen_becomes": {"uncertain": "In the glass, your reflection did not turn back when you did."},
			},
			{
				"kind": Interactable.Kind.FINAL_CHOICE, "name": "Passenger", "pos": Vector2(360, 180),
				"size": Vector2(22, 28), "color": Color(0.70, 0.50, 0.50), "verb": "Answer the",
				"victim": true,
				"stage_sprites": [
					"res://assets/sprites/characters/victim_0.png",
					"res://assets/sprites/characters/victim_1.png",
					"res://assets/sprites/characters/victim_2.png",
					"res://assets/sprites/characters/victim_3.png",
				],
				"uncertain": "They have a face now. They look at you and say, simply: \"You saw me.\"",
				"leak": "They have a face now -- almost yours. \"You saw me,\" they say. \"You were there.\"",
				"prompt": "\"You saw me.\"",
				"options": [
					{"id": "accept", "label": "\"I saw you. I should have stayed.\""},
					{"id": "deny", "label": "\"I don't know you.\""},
					{"id": "pill", "label": "Take the last pill."},
					{"id": "stay", "label": "\"I'll stay until the next one.\""},
				],
			},
		],
	}


func _on_ready(_d: Dictionary) -> void:
	GameState.set_flag("final_scene")
	GameState.set_victim_stage(GameState.Victim.REVEALED)
