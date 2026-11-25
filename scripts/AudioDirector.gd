extends Node

signal finished

var player: AudioStreamPlayer
var cache: Dictionary = {}
var active_words: Array = []
var playing := false


func _ready() -> void:
	player = AudioStreamPlayer.new()
	add_child(player)
	player.connect("finished", self, "_on_finished")


func play(file_name: String, words: Array = []) -> void:
	stop()
	if file_name == "":
		return
	if not cache.has(file_name):
		var stream = load("res://assets/audio/" + file_name)
		if stream == null:
			push_error("Missing audio: " + file_name)
			return
		cache[file_name] = stream
	player.stream = cache[file_name]
	active_words = words
	playing = true
	player.play()


func stop() -> void:
	if player != null:
		player.stop()
	playing = false
	active_words = []


func current_word_index() -> int:
	if not playing or active_words.empty():
		return -1
	var position := player.get_playback_position() + AudioServer.get_output_latency()
	for index in range(active_words.size()):
		var timing = active_words[index]
		if position >= float(timing.start) and position < float(timing.end):
			return index
	return -1


func set_sound_enabled(enabled: bool) -> void:
	AudioServer.set_bus_mute(0, not enabled)


func _on_finished() -> void:
	playing = false
	emit_signal("finished")
