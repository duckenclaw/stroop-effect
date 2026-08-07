extends Control

signal game_start_requested

@onready var tutorial_panel: PanelContainer = $MarginContainer/TutorialPanel
@onready var menu_container: VBoxContainer = $MarginContainer/MenuContainer
@onready var options_panel: PanelContainer = $MarginContainer/OptionsPanel
@onready var title_label: RichTextLabel = $MarginContainer/TitleLabel

# Rainbow color palette
const RAINBOW_COLORS = [
	Color(1.0, 0.0, 0.0),      # Red
	Color(1.0, 0.5, 0.0),      # Orange
	Color(1.0, 1.0, 0.0),      # Yellow
	Color(0.0, 1.0, 0.0),      # Green
	Color(0.0, 0.5, 1.0),      # Light Blue
	Color(0.0, 0.0, 1.0),      # Blue
	Color(0.5, 0.0, 1.0),      # Purple
]

const TITLE_TEXT = "STROOP EFFECT"
const TITLE_SHIFT := 0.15  # Seconds per color shift on the title
const BUTTON_SHIFT := 0.08  # Buttons cycle faster than the title

## Slider node name -> the audio bus it drives. Used to seed the sliders from the current bus
## volumes; the value_changed connections in start_ui.tscn carry the same index as a bind.
const SLIDER_BUSES := {"MasterSlider": 0, "MusicSlider": 1, "SFXSlider": 2}

## One clock drives both rainbows; they just read it at different rates.
var _elapsed := 0.0
var _title_step := -1

func _ready() -> void:
	var sliders := $MarginContainer/OptionsPanel/MarginContainer/VBoxContainer
	for slider_name in SLIDER_BUSES:
		var bus: int = SLIDER_BUSES[slider_name]
		# Convert the bus volume from decibels to the sliders' 0-100 range.
		sliders.get_node(slider_name).value = db_to_linear(AudioServer.get_bus_volume_db(bus)) * 100.0

func _process(delta: float) -> void:
	_elapsed += delta

	# The title is BBCode, so only rebuild it when the color offset actually advances.
	var step := int(_elapsed / TITLE_SHIFT)
	if step != _title_step:
		_title_step = step
		_update_rainbow_text()

	_update_button_colors()

func _update_rainbow_text() -> void:
	var bbcode_text = ""
	for i in TITLE_TEXT.length():
		var letter = TITLE_TEXT[i]
		if letter == " ":
			bbcode_text += " "  # Skip coloring spaces
			continue
		var color: Color = RAINBOW_COLORS[(i + _title_step) % RAINBOW_COLORS.size()]
		bbcode_text += "[color=#%s]%s[/color]" % [color.to_html(false), letter]
	title_label.text = bbcode_text

## Buttons answer is_hovered()/button_pressed themselves, so there is nothing to track between
## frames -- modulate is derived from the button's own state each frame.
func _update_button_colors() -> void:
	var active: Color = RAINBOW_COLORS[int(_elapsed / BUTTON_SHIFT) % RAINBOW_COLORS.size()]
	for button in menu_container.get_children():
		if button is Button:
			var lit: bool = button.is_hovered() or button.button_pressed
			button.modulate = active if lit else Color.WHITE

func _on_start_button_pressed() -> void:
	game_start_requested.emit()

func _on_how_to_play_button_pressed() -> void:
	menu_container.visible = false
	tutorial_panel.visible = true

func _on_close_button_pressed() -> void:
	tutorial_panel.visible = false
	menu_container.visible = true

func _on_options_button_pressed() -> void:
	menu_container.visible = false
	options_panel.visible = true

func _on_options_back_pressed() -> void:
	options_panel.visible = false
	menu_container.visible = true

func _on_volume_changed(value: float, bus: int) -> void:
	AudioServer.set_bus_volume_db(bus, linear_to_db(value / 100.0))
