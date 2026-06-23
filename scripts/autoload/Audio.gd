extends Node
## Tiny audio facade. Every call is safe even when the referenced file doesn't exist yet, so
## sound designers can drop .ogg/.wav files into res://audio/ later without touching any code.

var _ambience: AudioStreamPlayer
var _sfx: AudioStreamPlayer


func _ready() -> void:
	_ambience = AudioStreamPlayer.new()
	_ambience.volume_db = -8.0
	add_child(_ambience)
	_sfx = AudioStreamPlayer.new()
	add_child(_sfx)


func play_ambience(path: String, volume_db: float = -8.0) -> void:
	if path == "" or not ResourceLoader.exists(path):
		_ambience.stream = null
		return
	var stream: AudioStream = load(path)
	if _ambience.stream == stream and _ambience.playing:
		return
	_ambience.stream = stream
	_ambience.volume_db = volume_db
	_ambience.play()


func stop_ambience() -> void:
	_ambience.stop()


func play_sfx(path: String, volume_db: float = 0.0) -> void:
	if path == "" or not ResourceLoader.exists(path):
		return
	_sfx.stream = load(path)
	_sfx.volume_db = volume_db
	_sfx.play()
