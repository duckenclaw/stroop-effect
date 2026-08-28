class_name PlayerSfx
extends Node3D
## Every sound the player makes, plus the rising pitch that rewards a scoring streak.
##
## Owns a small pool of voices instead of one player, so a slam, the bounce it earns and the score
## that follows can sound together rather than cutting each other off mid-sample.

const VOICES := 6
## A whole tone per step, so six scores climb exactly one octave and the Shepard pair wraps.
const STEPS_PER_OCTAVE := 6
const SILENT := 0.001  # quieter than this is inaudible; skip the voice rather than play it at -inf dB

# Semitones of random detune either side of a sound's own pitch, per play. A short sample fired over
# and over at one fixed pitch reads as a machine gun; a little wobble each time is what stops the ear
# hearing "the same clip again". Anything absent here plays dead-on, and only plain play() varies --
# play_rising() must not, or the random detune would swamp the Shepard step it is trying to convey.
const PITCH_SPREAD := {
	&"lane_change": 2.0,
}

@export var jump_sfx: AudioStreamWAV
@export var slam_sfx: AudioStreamWAV
@export var slam_jump_sfx: AudioStreamWAV
@export var lane_change_sfx: AudioStreamWAV
@export var score_sfx: AudioStreamWAV
@export var color_change_sfx: AudioStreamWAV
@export var base_volume_db: float = -5.0

var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer3D] = []
var _next_voice := 0  # round-robin fallback for when every voice is busy

func _ready() -> void:
	_streams = {
		&"jump": jump_sfx,
		&"slam": slam_sfx,
		&"slam_jump": slam_jump_sfx,
		&"lane_change": lane_change_sfx,
		&"score": score_sfx,
		&"color_change": color_change_sfx,
	}
	for _i in VOICES:
		var voice := AudioStreamPlayer3D.new()
		voice.bus = &"SFX"
		voice.volume_db = base_volume_db
		add_child(voice)
		_voices.append(voice)

## One voice, detuned by the sound's PITCH_SPREAD if it has one.
func play(sfx_name: StringName) -> void:
	_play_voice(_stream_for(sfx_name), _random_pitch(sfx_name), 1.0)

## A playback ratio somewhere inside the sound's spread. Randomised in semitones rather than in the
## ratio itself, so the detune is symmetric by ear -- down and up sound equally far from centre,
## which a uniform ratio range would not be.
func _random_pitch(sfx_name: StringName) -> float:
	var semitones: float = PITCH_SPREAD.get(sfx_name, 0.0)
	if semitones <= 0.0:
		return 1.0
	return pow(2.0, randf_range(-semitones, semitones) / 12.0)

## A Shepard tone: `step` may rise without limit, but the pitch never leaves a single octave.
##
## Two voices an octave apart are equal-power crossfaded across each octave of the climb. The upper
## one starts at the sample's own pitch and fades out as it reaches +1 octave; the lower one trails
## an octave below and fades in, arriving at the sample's own pitch exactly as the upper one falls
## silent. Step STEPS_PER_OCTAVE is therefore identical to step 0, having audibly risen all the way
## there -- which is what lets a long streak keep climbing without ending in a squeak.
func play_rising(sfx_name: StringName, step: int) -> void:
	var stream := _stream_for(sfx_name)
	var t := float(step % STEPS_PER_OCTAVE) / STEPS_PER_OCTAVE  # position within the octave
	_play_voice(stream, pow(2.0, t), cos(t * PI * 0.5))
	_play_voice(stream, pow(2.0, t - 1.0), sin(t * PI * 0.5))

func _play_voice(stream: AudioStream, pitch: float, gain: float) -> void:
	if stream == null or gain < SILENT:
		return
	var voice := _free_voice()
	voice.stream = stream
	voice.pitch_scale = pitch
	voice.volume_db = base_volume_db + linear_to_db(gain)
	voice.play()

## The first idle voice, or the oldest one when the pool is saturated -- stealing a voice that is
## already part-way through its sample beats dropping the new sound entirely.
func _free_voice() -> AudioStreamPlayer3D:
	for voice in _voices:
		if not voice.playing:
			return voice
	var stolen := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	return stolen

func _stream_for(sfx_name: StringName) -> AudioStream:
	var stream: AudioStream = _streams.get(sfx_name)
	if stream == null:
		push_warning("Unknown or unassigned player SFX: " + sfx_name)
	return stream
