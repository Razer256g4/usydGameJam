extends Node
## Fade-through scene changes. Remembers which named spawn point the next scene should drop
## the player at, so doors just say "go to that scene, at that entry".

var pending_spawn: String = "entry"
var _changing := false


func change_scene(path: String, spawn: String = "entry") -> void:
	if _changing or path == "":
		return
	_changing = true
	pending_spawn = spawn
	await Hud.fade_out()
	get_tree().change_scene_to_file(path)
	# give the new scene a couple of frames to build itself before fading back in
	await get_tree().process_frame
	await get_tree().process_frame
	await Hud.fade_in()
	_changing = false


func reload() -> void:
	await change_scene(get_tree().current_scene.scene_file_path, pending_spawn)
