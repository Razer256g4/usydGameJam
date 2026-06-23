extends Station
## Station 2 -- "The Witness Platform". Core fear: being watched / the official lie.
## Inversion: the CCTV (objective evidence) shows the lie first; the crowd is a wall of
## indifference; the ticket machine is a confession machine. The dropped phone -- a dead,
## useless object -- carries more truth than the entire official system.
## Puzzle: find the phone (truth leaks in) -> read the truth on Monitor C -> at the ticket
## machine, choose WITNESS (not Passenger) -> the doors open.

func _station_data() -> Dictionary:
	return {
		"title": "The Witness Platform",
		"room_size": Vector2(640, 360),
		"floor_color": Color(0.06, 0.07, 0.09),
		"entries": {"from_train": Vector2(60, 300), "entry": Vector2(60, 300)},
		"on_enter_reality": GameState.Reality.UNCERTAIN,
		"objective": "They say nothing happened here, and the footage agrees. Prove otherwise.",
		"announcements": ["Evidence confirmed. No incident occurred.", "Do not interact with unattended passengers."],
		"ambience": "res://audio/ambience/station2.ogg",
		"props": [
			{
				"kind": Interactable.Kind.EXAMINE, "name": "Safety Line", "pos": Vector2(320, 332),
				"size": Vector2(140, 12), "color": Color(0.50, 0.45, 0.10), "verb": "Read the",
				"stable": "MIND THE GAP", "uncertain": "MIND THE GAP", "leak": "MIND WHAT YOU MISSED",
			},
			{
				"kind": Interactable.Kind.EXAMINE, "name": "Commuter", "pos": Vector2(180, 150),
				"size": Vector2(18, 26), "color": Color(0.20, 0.20, 0.24), "verb": "Speak to the",
				"stable": "\"Late.\"", "uncertain": "\"Busy. Not my problem.\"",
				"leak": "\"I didn't see anything. Neither did you.\"",
			},
			{
				"kind": Interactable.Kind.EXAMINE, "name": "Commuter", "pos": Vector2(240, 150),
				"size": Vector2(18, 26), "color": Color(0.20, 0.20, 0.24), "verb": "Speak to the",
				"stable": "\"Move along.\"", "uncertain": "\"Didn't see.\"",
				"leak": "\"You were standing right there.\"",
			},
			{
				"kind": Interactable.Kind.FLAG_SET, "name": "Dropped Phone", "pos": Vector2(430, 265),
				"size": Vector2(14, 18), "color": Color(0.10, 0.10, 0.12), "verb": "Pick up the",
				"one_shot": true, "sets_flag": "found_phone", "nudge_truth": true,
				"stable": "The phone is blank. Factory reset.",
				"uncertain": "No signal. A draft message is still open on the screen.",
				"leak": "Unsent message: \"Can you stay with me until the train comes?\"",
			},
			{
				"kind": Interactable.Kind.SCREEN_TERMINAL, "name": "CCTV Bank", "pos": Vector2(120, 95),
				"size": Vector2(44, 32), "color": Color(0.15, 0.20, 0.25), "verb": "Review the",
				"sets_flag": "truth_seen",
				"screens": [
					{"name": "MONITOR A", "text": "Official footage: no incident recorded on this platform."},
					{"name": "MONITOR B", "text": "Corrupted footage: a single figure stands at the very edge."},
					{"name": "MONITOR C", "text": "Truth: they reach out and ask for help. The passenger turns away. The passenger is you.", "req": "found_phone", "req_reality": GameState.Reality.MEMORY_LEAK},
				],
			},
			{
				"kind": Interactable.Kind.ROLE_TERMINAL, "name": "Ticket Machine", "pos": Vector2(545, 165),
				"size": Vector2(28, 40), "color": Color(0.30, 0.30, 0.20), "verb": "Use the",
				"requires_flag": "found_phone",
				"locked": "The machine demands a role you can't honestly answer yet. Find the evidence first.",
				"prompt": "TICKET MACHINE  —  SELECT YOUR ROLE IN THE INCIDENT",
				"options": [
					{"id": "passenger", "label": "Passenger"},
					{"id": "witness", "label": "Witness"},
					{"id": "victim", "label": "Victim"},
					{"id": "staff", "label": "Staff"},
					{"id": "none", "label": "No involvement"},
				],
				"correct": "witness",
				"sets_flag": "station2_cleared",
				"then_objective": "You are a Witness now. Return to the train.",
				"on_correct": "ROLE ACCEPTED: WITNESS. Transfer authorised.",
				"on_wrong": "TRANSFER DENIED. The platform will not let you leave as that.",
			},
			{
				"kind": Interactable.Kind.DOOR, "name": "Train Doors", "pos": Vector2(60, 300),
				"size": Vector2(26, 32), "color": Color(0.20, 0.45, 0.40), "verb": "Board through the",
				"target_scene": "res://scenes/world/TrainCabin.tscn", "target_spawn": "from_platform",
				"requires_flag": "accepted_witness",
				"locked": "The doors stay shut until you admit what you were.",
			},
		],
	}
