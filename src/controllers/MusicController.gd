extends AudioStreamPlayer3D

@export var lose_sound: AudioStreamMP3
@export var bgm: AudioStreamMP3


func _on_player_lose():
	stream = lose_sound
	playing = true
