extends Station
## Station 1 -- "The Station That Forgets". Core fear: absence / wrong familiarity.
## Inversion: the blank, useless-looking sign IS the objective; the safety poster becomes an
## accusation; the announcement tells you to leave (so you must stay and dig).
## Puzzle: collect 3 name fragments -> restore the sign (WITNESS) -> the doors open.

func _station_data() -> Dictionary:
	return {
		"title": "The Station That Forgets",
		"room_size": Vector2(640, 360),
		"floor_color": Color(0.07, 0.08, 0.10),
		"entries": {"from_train": Vector2(60, 300), "entry": Vector2(60, 300)},
		"on_enter_reality": GameState.Reality.UNCERTAIN,
		"objective": "This station forgot its own name. Find the missing letters.",
		"announcements": ["This station is not in service.", "Please return to the train."],
		"ambience": "res://audio/ambience/station1.ogg",
		"props": [
			{
				"kind": Interactable.Kind.FRAGMENT, "name": "Torn Notice", "pos": Vector2(150, 95),
				"size": Vector2(18, 20), "color": Color(0.62, 0.60, 0.50), "verb": "Take a fragment from",
				"set_id": "name", "piece": "WIT", "total": 3, "nudge_truth": true,
				"uncertain": "A scrap torn from the station sign. It reads: 'WIT'.",
			},
			{
				"kind": Interactable.Kind.FRAGMENT, "name": "Wet Paper", "pos": Vector2(480, 110),
				"size": Vector2(18, 20), "color": Color(0.62, 0.60, 0.50), "verb": "Take a fragment from",
				"set_id": "name", "piece": "NES", "total": 3, "nudge_truth": true,
				"uncertain": "Another scrap. The letters look wet, like they're still bleeding: 'NES'.",
			},
			{
				"kind": Interactable.Kind.FRAGMENT, "name": "Under the Bench", "pos": Vector2(320, 300),
				"size": Vector2(18, 20), "color": Color(0.62, 0.60, 0.50), "verb": "Reach under",
				"set_id": "name", "piece": "S", "total": 3, "nudge_truth": true,
				"uncertain": "One last letter, half-buried in grime: 'S'.",
			},
			{
				"kind": Interactable.Kind.EXAMINE, "name": "Poster", "pos": Vector2(110, 185),
				"size": Vector2(34, 46), "color": Color(0.50, 0.30, 0.30), "verb": "Read the",
				"stable": "SEE SOMETHING, SAY SOMETHING.",
				"uncertain": "SEE SOMETHING, SAY SOMETHING.",
				"leak": "SAW SOMETHING. SAID NOTHING.",
			},
			{
				"kind": Interactable.Kind.EXAMINE, "name": "Vending Machine", "pos": Vector2(548, 215),
				"size": Vector2(30, 46), "color": Color(0.25, 0.35, 0.40), "verb": "Inspect the",
				"stable": "Out of order. Every slot behind the glass is empty.",
				"uncertain": "Every slot behind the glass holds the exact same object.",
				"leak": "Every slot holds the same ticket. Your ticket.",
			},
			{
				"kind": Interactable.Kind.EXAMINE, "name": "Intercom", "pos": Vector2(330, 70),
				"size": Vector2(20, 20), "color": Color(0.30, 0.30, 0.35), "verb": "Listen to the",
				"stable": "\"This station is not in service.\"",
				"uncertain": "\"This station is not in service.\"",
				"leak": "Under the announcement, another voice: \"Then why did you get off here?\"",
			},
			{
				"kind": Interactable.Kind.EXAMINE, "name": "Clock", "pos": Vector2(220, 70),
				"size": Vector2(22, 22), "color": Color(0.40, 0.40, 0.45), "verb": "Check the",
				"stable": "The clock has no hands.",
				"uncertain": "No hands. But something, somewhere, is ticking.",
				"leak": "The ticking is coming from your own pocket. From the ticket.",
			},
			{
				"kind": Interactable.Kind.FLAG_SET, "name": "Blank Sign", "pos": Vector2(320, 150),
				"size": Vector2(84, 22), "color": Color(0.15, 0.16, 0.20), "verb": "Restore the",
				"one_shot": true, "requires_fragments": "name",
				"locked": "The station sign is blank. Pieces of its name are missing.",
				"uncertain": "You press the fragments back into place. The sign remembers its name: WITNESS.",
				"sets_flag": "station1_cleared", "nudge_truth": true, "becomes_name": "WITNESS",
				"then_objective": "The doors are open. Return to the train.",
			},
			{
				"kind": Interactable.Kind.DOOR, "name": "Train Doors", "pos": Vector2(60, 300),
				"size": Vector2(26, 32), "color": Color(0.20, 0.45, 0.40), "verb": "Board through the",
				"target_scene": "res://scenes/world/TrainCabin.tscn", "target_spawn": "from_platform",
				"requires_flag": "station1_cleared",
				"locked": "The doors won't open. You haven't found what this station forgot.",
			},
		],
	}
