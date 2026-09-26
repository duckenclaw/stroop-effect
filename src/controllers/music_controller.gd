class_name MusicController
extends Node
## Background music: the intro on the menu, then one track per stage, crossfaded as the player
## crosses each stage gate.
##
## Two decks, A and B, take turns: the incoming track starts silent on the idle deck and fades up
## while the outgoing one fades down. Lives in world.tscn rather than an autoload, so restarting
## (a scene reload back to the menu) brings the intro back without any extra code.

const SILENT_DB := -60.0  # effectively inaudible; tweening to -inf dB would jump rather than fade
const LOSE_FADE := 0.3

@export var intro_track: AudioStream
## Index 0 is stage 1. Stages past the end reuse the last track.
@export var stage_tracks: Array[AudioStream] = []
@export var lose_sound: AudioStreamWAV
@export var crossfade_time: float = 1.5
@export var music_volume_db: float = 0.0

var _decks: Array[AudioStreamPlayer] = []
var _active := 0
var _sting: AudioStreamPlayer
var _fade: Tween

func _ready() -> void:
	for _i in 2:
		_decks.append(_make_player())
	_sting = _make_player()
	play_track(intro_track, 0.0)

func _make_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = &"Music"
	add_child(player)
	return player

## Crossfades to `stream` over `fade` seconds. A no-op if it is already the one playing.
func play_track(stream: AudioStream, fade: float = crossfade_time) -> void:
	var outgoing := _decks[_active]
	if stream == null or (outgoing.stream == stream and outgoing.playing):
		return
	_active = 1 - _active
	var incoming := _decks[_active]
	incoming.stream = stream
	incoming.volume_db = SILENT_DB if fade > 0.0 else music_volume_db
	incoming.play()
	_fade_decks({incoming: music_volume_db, outgoing: SILENT_DB}, fade)

## Tweens each deck to its target volume in parallel and stops any that end silent. Kills the
## previous fade first, so switches in quick succession don't fight over the same deck.
func _fade_decks(targets: Dictionary, duration: float) -> void:
	if _fade:
		_fade.kill()
	if duration <= 0.0:
		for deck: AudioStreamPlayer in targets:
			deck.volume_db = targets[deck]
			if targets[deck] <= SILENT_DB:
				deck.stop()
		return
	_fade = create_tween().set_parallel()
	for deck: AudioStreamPlayer in targets:
		_fade.tween_property(deck, "volume_db", targets[deck], duration)
	_fade.chain().tween_callback(func():
		for deck: AudioStreamPlayer in targets:
			if targets[deck] <= SILENT_DB:
				deck.stop())

func _track_for_stage(stage: int) -> AudioStream:
	if stage_tracks.is_empty():
		return null
	return stage_tracks[clampi(stage - 1, 0, stage_tracks.size() - 1)]

func _on_game_started() -> void:
	play_track(_track_for_stage(1))

func _on_stage_changed(stage: int) -> void:
	play_track(_track_for_stage(stage))

func _on_player_lose() -> void:
	_fade_decks({_decks[0]: SILENT_DB, _decks[1]: SILENT_DB}, LOSE_FADE)
	if lose_sound:
		_sting.stream = lose_sound
		_sting.play()
