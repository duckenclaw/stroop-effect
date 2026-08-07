class_name ScoreKeeper
extends Timer
## The run's score and its decaying streak multiplier.
##
## Doubles as the streak timer -- the same shape timed_effect.gd uses -- so the multiplier and the
## countdown that resets it cannot drift apart.

const STREAK_DECAY := 3.5  # seconds without scoring before the multiplier drops back to 1
const MAX_MODIFIER := 5.0

## How much a color-change pickup adds to the multiplier.
@export var modifier_step: float = 1.0

var points := 0.0
var modifier := 1.0

signal changed(total: float, modifier: float)

func _ready() -> void:
	# one_shot, or the timer would restart itself and re-announce the same reset every STREAK_DECAY
	# seconds for the rest of the run.
	one_shot = true
	timeout.connect(_on_timeout)

func add(amount: float) -> void:
	points += amount * modifier
	start(STREAK_DECAY)
	changed.emit(points, modifier)

func boost() -> void:
	modifier = minf(modifier + modifier_step, MAX_MODIFIER)

func _on_timeout() -> void:
	modifier = 1.0
	changed.emit(points, modifier)
