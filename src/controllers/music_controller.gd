extends AudioStreamPlayer3D

@export var lose_sound: AudioStreamWAV


func _on_player_lose():
	stream = lose_sound
	playing = true
