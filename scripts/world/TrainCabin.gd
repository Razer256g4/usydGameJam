extends Station
## The hub. The train *feels* safe but it is the denial loop -- you must keep leaving it.
## It routes you to the next unsolved location, and the faceless passenger grows clearer as
## you make progress (set centrally here so the victim logic lives in one place).

func _station_data() -> Dictionary:
	var next_scene := "res://scenes/world/StationForgets.tscn"
	if GameState.has_flag("station2_cleared"):
		next_scene = "res://scenes/world/FinalTrain.tscn"
	elif GameState.has_flag("station1_cleared"):
		next_scene = "res://scenes/world/StationWitness.tscn"

	var props: Array = [
		{
			"kind": Interactable.Kind.EXAMINE, "name": "Window", "pos": Vector2(150, 70),
			"size": Vector2(64, 28), "color": Color(0.16, 0.20, 0.30), "verb": "Look through",
			"stable": "Your reflection looks back. Tired, but fine.",
			"uncertain": "The platform outside is crowded, and not one of them is moving.",
			"leak": "Out of the whole frozen crowd, one person is staring straight back at you.",
		},
		{
			"kind": Interactable.Kind.EXAMINE, "name": "Seat", "pos": Vector2(250, 250),
			"size": Vector2(30, 22), "color": Color(0.30, 0.22, 0.18), "verb": "Sit on",
			"stable": "A warm seat. You could just stay. The train will take you home.",
			"uncertain": "If you sit, you get the feeling the doors will never open again.",
			"leak": "Sitting is how the loop keeps you. Stay on your feet.",
			"announce": "Please remain seated. This train is for your safety.",
		},
		{
			"kind": Interactable.Kind.EXAMINE, "name": "Emergency Brake", "pos": Vector2(95, 130),
			"size": Vector2(16, 24), "color": Color(0.55, 0.15, 0.15), "verb": "Pull the",
			"stable": "PULL IN EMERGENCY. A small printed line beneath: 'disabled for passenger safety'.",
			"uncertain": "You pull it. Nothing happens. It was never connected to anything.",
			"leak": "The only emergency is the one they would rather you didn't stop.",
			"announce": "Emergency brake disabled for your safety. Please remain seated.",
		},
		{
			"kind": Interactable.Kind.EXAMINE, "name": "Route Map", "pos": Vector2(330, 64),
			"size": Vector2(72, 20), "color": Color(0.20, 0.30, 0.35), "verb": "Study the",
			"stable": "The line map. Your stop is three stations from here.",
			"uncertain": "The line map. You can no longer find your stop on it.",
			"leak": "Every station printed on the map now bears the same name: WITNESS.",
			"unseen_becomes": {"uncertain": "While you weren't looking, every stop slid one closer to the end of the line."},
		},
		{
			"kind": Interactable.Kind.EXAMINE, "name": "Hand Strap", "pos": Vector2(395, 108),
			"size": Vector2(10, 22), "color": Color(0.30, 0.30, 0.32), "verb": "Hold the",
			"moves_when_unseen": true, "move_step": 13.0, "move_interval": 0.9, "move_min": 40.0,
			"stable": "A hanging hand strap, swaying with the motion of the train.",
			"uncertain": "A hand strap. It's swaying toward you, against the lean of the train.",
			"leak": "It swings toward you even when the train is standing perfectly still.",
		},
		{
			"kind": Interactable.Kind.DOOR, "name": "Doors", "pos": Vector2(560, 300),
			"size": Vector2(26, 32), "color": Color(0.20, 0.45, 0.40), "verb": "Step onto the platform through",
			"target_scene": next_scene, "target_spawn": "from_train",
		},
	]

	# The victim only exists in the cabin once you've started remembering (after Station 1).
	if GameState.has_flag("station1_cleared"):
		props.append({
			"kind": Interactable.Kind.EXAMINE, "name": "Passenger", "pos": Vector2(470, 180),
			"size": Vector2(20, 26), "color": Color(0.12, 0.12, 0.16), "verb": "Approach the",
			"provider": "victim",
			# drop in 4 sprites and the face resolves as you remember (box until then):
			"victim": true,
			"stage_sprites": [
				"res://assets/sprites/characters/victim_0.png",
				"res://assets/sprites/characters/victim_1.png",
				"res://assets/sprites/characters/victim_2.png",
				"res://assets/sprites/characters/victim_3.png",
			],
		})

	return {
		"title": "Train Cabin",
		"room_size": Vector2(640, 360),
		"floor_color": Color(0.09, 0.10, 0.13),
		"entries": {"entry": Vector2(320, 300), "from_platform": Vector2(560, 280)},
		"on_enter_reality": GameState.Reality.UNCERTAIN,
		"objective": _objective_for_progress(),
		"announcements": ["Please remain seated.", "This train is for your safety."],
		"ambience": "res://audio/ambience/train.ogg",
		"props": props,
	}


func _on_ready(_d: Dictionary) -> void:
	# Advance the victim toward being recognisable as the player progresses.
	if GameState.has_flag("station2_cleared"):
		GameState.set_victim_stage(GameState.Victim.PARTIAL)
	elif GameState.has_flag("station1_cleared"):
		GameState.set_victim_stage(GameState.Victim.FACELESS)


func _objective_for_progress() -> String:
	if not GameState.has_flag("station1_cleared"):
		return "Nobody else boarded. Something is wrong. Get off the train."
	if not GameState.has_flag("station2_cleared"):
		return "Find the platform that remembers what happened."
	return "Return to your seat. It is time to answer."


func _provide_victim() -> Array:
	match GameState.victim_stage:
		GameState.Victim.PARTIAL:
			return [{"name": "PASSENGER", "text": "You're starting to remember my face. Don't take another pill."}]
		GameState.Victim.FACELESS:
			return [{"name": "PASSENGER", "text": "...you got off at the wrong stop too. Didn't you."}]
		_:
			return [{"name": "", "text": "A passenger with no face sits perfectly still. Every instinct says look away."}]
