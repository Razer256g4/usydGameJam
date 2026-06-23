extends Node
## Single source of truth for one playthrough.
##
## Every system reads from and writes to GameState and reacts to its signals, so there is
## exactly one place that owns "what is true right now". The whole game is built around a
## single inverted axis -- REALITY -- which pills push toward comfort and truth pushes back.

signal reality_changed(state: int)
signal pills_changed(count: int)
signal denial_changed(score: int)
signal flag_changed(flag: String, value: Variant)
signal fragments_changed(set_id: String, collected: int, total: int)
signal objective_changed(text: String)
signal victim_changed(stage: int)
signal truth_pulse                          # fired when the truth actually leaks one step further

## Pills make the world STABLE (safe lies, clues hidden). Avoiding them and chasing the
## truth pushes toward MEMORY_LEAK (truth visible, world hostile). This is the spine of the
## "flip the script" theme: the thing that helps you is the thing that hides the truth.
enum Reality { STABLE, UNCERTAIN, MEMORY_LEAK }
enum Victim { NONE, FACELESS, PARTIAL, REVEALED }

const START_PILLS := 2

var reality: int = Reality.UNCERTAIN
var pills: int = START_PILLS
var denial: int = 0
var victim_stage: int = Victim.NONE
var objective: String = ""
var pending_ending: String = ""

var flags := {}                # String -> Variant
var _fragments := {}           # set_id -> { "have": Array[String], "total": int }

var drift_enabled := false     # "sanity drift": reality slowly slips back toward the truth
var _drift_timer: Timer

## How the controls currently betray you: "normal" | "mirror" (L/R swap) | "invert" (both)
## | "swap" (axes swapped). Set per-room via station data "input_mode" or by an event effect.
var input_mode := "normal"


func _ready() -> void:
	_setup_input()
	_drift_timer = Timer.new()
	_drift_timer.one_shot = false
	_drift_timer.timeout.connect(_on_drift_tick)
	add_child(_drift_timer)


func _on_drift_tick() -> void:
	if drift_enabled:
		nudge_truth()


## Wipe the run for a fresh start / restart.
func reset() -> void:
	stop_drift()
	input_mode = "normal"
	reality = Reality.UNCERTAIN
	pills = START_PILLS
	denial = 0
	victim_stage = Victim.NONE
	objective = ""
	pending_ending = ""
	flags.clear()
	_fragments.clear()
	pills_changed.emit(pills)
	denial_changed.emit(denial)
	victim_changed.emit(victim_stage)


# ---------------------------------------------------------------- flags
func set_flag(flag: String, value: Variant = true) -> void:
	flags[flag] = value
	flag_changed.emit(flag, value)


func has_flag(flag: String) -> bool:
	return bool(flags.get(flag, false))


# ---------------------------------------------------------------- reality / pills
func set_reality(state: int) -> void:
	state = clampi(state, Reality.STABLE, Reality.MEMORY_LEAK)
	if state == reality:
		return
	reality = state
	reality_changed.emit(reality)


## Truth leaks back even through denial -- nudge one step toward MEMORY_LEAK.
func nudge_truth() -> void:
	var before := reality
	set_reality(mini(reality + 1, Reality.MEMORY_LEAK))
	if reality != before:
		truth_pulse.emit()


## Returns false if there were no pills left to take.
func use_pill() -> bool:
	if pills <= 0:
		return false
	pills -= 1
	denial += 1
	pills_changed.emit(pills)
	denial_changed.emit(denial)
	set_reality(Reality.STABLE)
	return true


func add_pills(n: int) -> void:
	pills += n
	pills_changed.emit(pills)


# ---------------------------------------------------------------- sanity drift
## Start (or stop, with seconds <= 0) the slow slip toward MEMORY_LEAK. Pills reset reality to
## STABLE; drift drags it back -- so pills feel like they "wear off". Set per-room via the
## station data field "sanity_drift" (seconds between nudges).
func set_drift(seconds: float) -> void:
	if seconds <= 0.0:
		stop_drift()
		return
	drift_enabled = true
	_drift_timer.wait_time = seconds
	_drift_timer.start()


func stop_drift() -> void:
	drift_enabled = false
	if _drift_timer:
		_drift_timer.stop()


# ---------------------------------------------------------------- fragments
## Collect one piece of a multi-part collectible (e.g. the station name). Returns true once
## the set is complete.
func collect_fragment(set_id: String, piece: String, total: int) -> bool:
	var entry: Dictionary = _fragments.get(set_id, {"have": [], "total": total})
	entry["total"] = total
	if not entry["have"].has(piece):
		entry["have"].append(piece)
	_fragments[set_id] = entry
	fragments_changed.emit(set_id, entry["have"].size(), total)
	return fragments_complete(set_id)


func fragments_complete(set_id: String) -> bool:
	var entry: Variant = _fragments.get(set_id, null)
	if entry == null:
		return false
	return entry["have"].size() >= entry["total"]


func fragment_count(set_id: String) -> int:
	var entry: Variant = _fragments.get(set_id, null)
	return 0 if entry == null else entry["have"].size()


# ---------------------------------------------------------------- objective / victim
func set_objective(text: String) -> void:
	objective = text
	objective_changed.emit(text)


## Victim only ever moves toward REVEALED -- never backward.
func set_victim_stage(stage: int) -> void:
	stage = clampi(stage, Victim.NONE, Victim.REVEALED)
	if stage <= victim_stage:
		return
	victim_stage = stage
	victim_changed.emit(stage)


# ---------------------------------------------------------------- ticket (quest log = guilt meter)
func get_ticket() -> Dictionary:
	var role := "Witness" if has_flag("accepted_witness") else "Passenger"
	var dest := "Home"
	if has_flag("station2_cleared"):
		dest = "Actual Destination"
	elif has_flag("station1_cleared"):
		dest = "[REDACTED]"
	var action := "ANSWER" if has_flag("final_scene") else ""
	return {"from": "Central", "to": dest, "role": role, "action": action}


# ---------------------------------------------------------------- endings
func get_ending(choice: String) -> String:
	match choice:
		"accept":
			return "bittersweet" if denial >= 2 else "good"
		"deny":
			return "loop"
		"pill":
			return "denial"
		"stay":
			return "conductor"
	return "loop"


# ---------------------------------------------------------------- input bootstrap
## Defined in code (not project.godot) so the input map can't cause merge conflicts during a
## jam and is documented in one readable place.
func _setup_input() -> void:
	_bind("move_up", [KEY_W, KEY_UP])
	_bind("move_down", [KEY_S, KEY_DOWN])
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("interact", [KEY_E, KEY_ENTER])
	_bind("pill", [KEY_Q])
	_bind("ticket", [KEY_T])


func _bind(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
