extends Station
## Station 1 -- "The Station That Forgets". A multi-room, explorable level built entirely from
## data (see Station.gd for the systems). Fears: absence, claustrophobia (Iron Lung), and a
## world that refuses to behave the way it looks (Trap Adventure).
##
## World map (left -> right), tight dark corridors between rooms:
##   [Platform] -corr- [Flooded Maintenance] -corr- [Waiting Room]
##   with a hidden Alcove sealed above the Platform by a wall only the truth can open.
##
## Puzzle: 3 name fragments -> restore the sign (WITNESS) -> the train doors open.
##   WIT  : on the platform
##   NES  : far side of the flooded room -- the "walkway" is the trap, wade the "water"
##   S    : in the alcove, behind a wall that only opens once reality has slipped (MEMORY_LEAK)

const STABLE := GameState.Reality.STABLE
const UNCERTAIN := GameState.Reality.UNCERTAIN
const LEAK := GameState.Reality.MEMORY_LEAK


func _station_data() -> Dictionary:
	return {
		"title": "The Station That Forgets",
		"entries": {"from_train": Vector2(90, 500), "entry": Vector2(90, 500), "respawn": Vector2(90, 500)},
		"on_enter_reality": UNCERTAIN,
		"dark": true,
		"dark_color": Color(0.28, 0.29, 0.34),   # lower this toward 0.18 for full Iron-Lung dark
		"light_radius": 110,
		"light_energy": 1.5,
		"sanity_drift": 22.0,
		"objective": "This station forgot its own name. Find the three missing letters.",
		"announcements": ["This station is not in service.", "Please return to the train.", "Maintenance teams to the flooded platform."],
		"ambience": "res://audio/ambience/station1.ogg",

		"layout": {
			"world_size": Vector2(1400, 600),
			"floors": [
				{"rect": Rect2(0, 0, 1400, 600), "color": Color(0.06, 0.07, 0.09)},
				{"rect": Rect2(20, 170, 360, 410), "color": Color(0.10, 0.10, 0.13)},   # platform
				{"rect": Rect2(20, 20, 360, 138), "color": Color(0.13, 0.06, 0.07)},    # hidden alcove
				{"rect": Rect2(413, 236, 140, 128), "color": Color(0.04, 0.05, 0.06)},  # corridor 1
				{"rect": Rect2(571, 20, 384, 560), "color": Color(0.05, 0.13, 0.16)},   # flooded room ("water")
				{"rect": Rect2(957, 236, 118, 128), "color": Color(0.04, 0.05, 0.06)},  # corridor 2
				{"rect": Rect2(1077, 20, 303, 560), "color": Color(0.09, 0.10, 0.12)},  # waiting room
			],
			"walls": [
				# vertical dividers, each leaving a doorway gap at y 236..364
				{"rect": Rect2(395, 0, 18, 236)}, {"rect": Rect2(395, 364, 18, 236)},
				{"rect": Rect2(553, 0, 18, 236)}, {"rect": Rect2(553, 364, 18, 236)},
				{"rect": Rect2(955, 0, 18, 236)}, {"rect": Rect2(955, 364, 18, 236)},
				{"rect": Rect2(1075, 0, 18, 236)}, {"rect": Rect2(1075, 364, 18, 236)},
				# the wall that hides the alcove -- solid normally, opens once the truth leaks in
				{"rect": Rect2(20, 158, 375, 16), "id": "secret_wall", "color": Color(0.10, 0.05, 0.06),
				 "solid_in": [STABLE, UNCERTAIN]},
				# looks exactly like a wall; has no collision -- walk straight through it
				{"rect": Rect2(835, 70, 18, 150), "fake": true, "color": Color(0.05, 0.05, 0.08)},
				# nothing is there at all; you still can't pass (an unseen wall in the waiting room)
				{"rect": Rect2(1300, 120, 16, 260), "invisible_solid": true},
			],
		},

		"holes": [
			# THE TRAP: a tidy grey "walkway" down the middle of the flooded room. It looks like
			# the safe path; it is the drop. The "water" around it is harmless. Step on this and
			# you're set back to the room's entrance.
			{"rect": Rect2(690, 250, 180, 100), "color": Color(0.40, 0.41, 0.44),
			 "respawn": Vector2(600, 300), "flash": 0.5,
			 "announce": "The walkway gives way under you -- and the water just... holds you up. As if it was always solid."},
			# a pit in the waiting room that only exists once reality has slipped
			{"rect": Rect2(1175, 250, 95, 105), "color": Color(0.0, 0.0, 0.0, 1.0),
			 "reality_min": LEAK, "respawn": Vector2(1110, 300),
			 "announce": "That floor was whole a moment ago."},
		],

		"events": [
			# entering the first corridor: the lights stutter and the cart is suddenly nearer
			{"rect": Rect2(413, 236, 140, 128), "once": true,
			 "effects": [{"do": "shake", "amount": 6.0}, {"do": "flash", "amount": 0.4},
				{"do": "announce", "text": "Something rolled across the dark behind you."}]},
			# entering the flooded room: the lie that sets up the trap
			{"rect": Rect2(640, 236, 44, 128), "once": true,
			 "effects": [{"do": "announce", "text": "FLOODING IN PROGRESS. Use the walkway. Do not step in the water."}]},
			# the mirror corridor: left becomes right. Reset zones flank it on both sides so you're
			# only turned-around inside the passage.
			{"rect": Rect2(345, 236, 50, 128), "once": false, "effects": [{"do": "controls", "mode": "normal"}]},
			{"rect": Rect2(413, 236, 140, 128), "once": false, "effects": [{"do": "controls", "mode": "mirror"}]},
			{"rect": Rect2(571, 236, 52, 128), "once": false, "effects": [{"do": "controls", "mode": "normal"}]},
			{"rect": Rect2(455, 236, 45, 128), "once": true,
			 "effects": [{"do": "announce", "text": "Left is right in this passage. Keep moving."}, {"do": "tilt", "deg": 6.0}]},
		],

		"props": [
			# --- fragments (one per area) ---
			{"kind": Interactable.Kind.FRAGMENT, "name": "Torn Notice", "pos": Vector2(140, 440),
			 "size": Vector2(18, 20), "color": Color(0.62, 0.60, 0.50), "verb": "Take a fragment from",
			 "set_id": "name", "piece": "WIT", "total": 3, "nudge_truth": true,
			 "uncertain": "A scrap torn from the station sign: 'WIT'."},
			{"kind": Interactable.Kind.FRAGMENT, "name": "Soaked Scrap", "pos": Vector2(900, 300),
			 "size": Vector2(18, 20), "color": Color(0.62, 0.60, 0.50), "verb": "Take a fragment from",
			 "set_id": "name", "piece": "NES", "total": 3, "nudge_truth": true,
			 "uncertain": "Across the water, a soaked scrap clings to the far wall: 'NES'."},
			{"kind": Interactable.Kind.FRAGMENT, "name": "Pressed Letter", "pos": Vector2(120, 80),
			 "size": Vector2(18, 20), "color": Color(0.62, 0.60, 0.50), "verb": "Take a fragment from",
			 "set_id": "name", "piece": "S", "total": 3, "nudge_truth": true,
			 "uncertain": "Hidden in the alcove the whole time, the last letter: 'S'."},

			# --- flavour / inversion props ---
			{"kind": Interactable.Kind.EXAMINE, "name": "Poster", "pos": Vector2(80, 300),
			 "size": Vector2(34, 46), "color": Color(0.50, 0.30, 0.30), "verb": "Read the",
			 "stable": "SEE SOMETHING, SAY SOMETHING.", "uncertain": "SEE SOMETHING, SAY SOMETHING.",
			 "leak": "SAW SOMETHING. SAID NOTHING.",
			 "sprite": "res://assets/sprites/props/poster.png", "sprite_leak": "res://assets/sprites/props/poster_leak.png"},
			{"kind": Interactable.Kind.EXAMINE, "name": "Notice", "pos": Vector2(620, 110),
			 "size": Vector2(34, 30), "color": Color(0.55, 0.50, 0.25), "verb": "Read the",
			 "stable": "USE THE WALKWAY. DO NOT STEP IN THE WATER.",
			 "uncertain": "USE THE WALKWAY. DO NOT STEP IN THE WATER.",
			 "leak": "THE WALKWAY IS THE DROP. THE WATER WILL HOLD YOU. WADE."},
			{"kind": Interactable.Kind.EXAMINE, "name": "Intercom", "pos": Vector2(483, 300),
			 "size": Vector2(20, 20), "color": Color(0.30, 0.30, 0.35), "verb": "Listen to the",
			 "stable": "\"This station is not in service.\"", "uncertain": "\"This station is not in service.\"",
			 "leak": "Under the announcement, another voice: \"Then why did you get off here?\""},
			{"kind": Interactable.Kind.EXAMINE, "name": "Clock", "pos": Vector2(1130, 110),
			 "size": Vector2(22, 22), "color": Color(0.40, 0.40, 0.45), "verb": "Check the",
			 "stable": "The clock has no hands.", "uncertain": "No hands. But something is ticking.",
			 "leak": "The ticking is in your own pocket. From the ticket."},
			{"kind": Interactable.Kind.EXAMINE, "name": "Vending Machine", "pos": Vector2(1340, 300),
			 "size": Vector2(30, 46), "color": Color(0.25, 0.35, 0.40), "verb": "Inspect the",
			 "stable": "Out of order. Empty.", "uncertain": "Every slot holds the same object.",
			 "leak": "Every slot holds the same ticket. Yours."},

			# --- signs that won't hold still ---
			{"kind": Interactable.Kind.EXAMINE, "name": "Departures Board", "pos": Vector2(1150, 470),
			 "size": Vector2(64, 22), "color": Color(0.15, 0.25, 0.20), "verb": "Read the",
			 "cycle": [
				"DEPARTURES  12:04  Home",
				"DEPARTURES  12:04  Home  (Delayed)",
				"DEPARTURES  12:04  Home  (Cancelled)",
				"DEPARTURES  this service does not stop where you think it does",
				"DEPARTURES  WITNESS   WITNESS   WITNESS",
			 ]},
			{"kind": Interactable.Kind.EXAMINE, "name": "Exit Sign", "pos": Vector2(1110, 250),
			 "size": Vector2(42, 14), "color": Color(0.20, 0.45, 0.25), "verb": "Follow the",
			 "stable": "EXIT  ->   (the arrow points back the way you came)",
			 "uncertain": "EXIT  ->   You are fairly sure the exit is not that way.",
			 "leak": "The arrow points at the train. The exit is the loop. Don't take it."},

			# --- the cart that only moves when you look away ---
			{"kind": Interactable.Kind.EXAMINE, "name": "Luggage Cart", "pos": Vector2(645, 175),
			 "size": Vector2(26, 20), "color": Color(0.32, 0.28, 0.20), "verb": "Examine the",
			 "moves_when_unseen": true, "move_step": 30.0, "move_interval": 0.55, "move_min": 30.0,
			 "stable": "An abandoned luggage cart.",
			 "uncertain": "An abandoned luggage cart. It is closer than it was.",
			 "leak": "It only rolls when you stop watching it. So don't."},

			# --- the friendly thing that arrives wrong (appears once reality slips) ---
			{"kind": Interactable.Kind.EXAMINE, "name": "Attendant", "pos": Vector2(250, 80),
			 "size": Vector2(20, 30), "color": Color(0.50, 0.50, 0.55), "verb": "Speak to the",
			 "hidden_until_reality": LEAK, "reveal_flash": 0.5,
			 "reveal_announce": "Someone is standing in the dark of the alcove with you now.",
			 "stable": "A station attendant smiles warmly. \"Lost your platform? I can show you the way.\"",
			 "uncertain": "The attendant smiles, and holds it a moment too long.",
			 "leak": "Its smile doesn't move at all. It knows exactly which stop was yours -- and that you missed it."},

			# --- the objective + the way out ---
			{"kind": Interactable.Kind.FLAG_SET, "name": "Blank Sign", "pos": Vector2(1230, 200),
			 "size": Vector2(84, 22), "color": Color(0.15, 0.16, 0.20), "verb": "Restore the",
			 "one_shot": true, "requires_fragments": "name",
			 "locked": "The station sign is blank. Its name is in pieces.",
			 "uncertain": "You press the fragments home. The sign remembers its name: WITNESS.",
			 "sets_flag": "station1_cleared", "nudge_truth": true, "becomes_name": "WITNESS",
			 "then_objective": "The doors are open. Find your way back to the train.",
			 "announce": "Now serving: WITNESS."},
			{"kind": Interactable.Kind.DOOR, "name": "Train Doors", "pos": Vector2(60, 540),
			 "size": Vector2(26, 32), "color": Color(0.20, 0.45, 0.40), "verb": "Board through the",
			 "target_scene": "res://scenes/world/TrainCabin.tscn", "target_spawn": "from_platform",
			 "requires_flag": "station1_cleared",
			 "locked": "The doors won't open. You haven't found what this station forgot."},
		],
	}
