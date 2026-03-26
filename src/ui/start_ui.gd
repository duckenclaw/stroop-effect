extends Control

signal game_start_requested

@onready var tutorial_panel: PanelContainer = $MarginContainer/TutorialPanel
@onready var menu_container: VBoxContainer = $MarginContainer/MenuContainer
@onready var options_panel: PanelContainer = $MarginContainer/OptionsPanel
@onready var master_slider: HSlider = $MarginContainer/OptionsPanel/MarginContainer/VBoxContainer/MasterSlider
@onready var music_slider: HSlider = $MarginContainer/OptionsPanel/MarginContainer/VBoxContainer/MusicSlider
@onready var sfx_slider: HSlider = $MarginContainer/OptionsPanel/MarginContainer/VBoxContainer/SFXSlider
@onready var title_label: RichTextLabel = $MarginContainer/TitleLabel
@onready var start_button: Button = $MarginContainer/MenuContainer/StartButton
@onready var how_to_play_button: Button = $MarginContainer/MenuContainer/HowToPlayButton
@onready var options_button: Button = $MarginContainer/MenuContainer/OptionsButton

# Rainbow color palette (HSV-based for smooth cycling)
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
const ANIMATION_SPEED = 0.15  # Seconds per color shift
const BUTTON_ANIMATION_SPEED = 0.08  # Faster animation for buttons
var rainbow_timer = 0.0
var color_offset = 0  # Current starting index in RAINBOW_COLORS
var button_rainbow_timer = 0.0
var button_color_offset = 0

# Track button states (for rainbow effect on hover/press)
var hovered_buttons: Array[Button] = []
var pressed_buttons: Array[Button] = []

func _ready() -> void:
	# Initialize sliders with current audio bus volumes (converted from db to 0-100 range)
	master_slider.value = _db_to_slider(AudioServer.get_bus_volume_db(0))
	music_slider.value = _db_to_slider(AudioServer.get_bus_volume_db(1))
	sfx_slider.value = _db_to_slider(AudioServer.get_bus_volume_db(2))

	# Start rainbow animation
	set_process(true)
	_update_rainbow_text()

	# Connect button signals for rainbow effects
	_connect_button_signals(start_button)
	_connect_button_signals(how_to_play_button)
	_connect_button_signals(options_button)

func _on_start_button_pressed() -> void:
	# Emit signal to request game start
	game_start_requested.emit()

func _on_how_to_play_button_pressed() -> void:
	# Show tutorial panel, hide menu
	menu_container.visible = false
	tutorial_panel.visible = true

func _on_close_button_pressed() -> void:
	# Hide tutorial panel, show menu
	tutorial_panel.visible = false
	menu_container.visible = true

func _on_options_button_pressed() -> void:
	# Show options panel, hide menu
	menu_container.visible = false
	options_panel.visible = true

func _on_options_back_pressed() -> void:
	# Hide options panel, show menu
	options_panel.visible = false
	menu_container.visible = true

func _on_master_volume_changed(value: float) -> void:
	var volume_linear = value / 100.0  # Convert 0-100 to 0-1
	AudioServer.set_bus_volume_db(0, linear_to_db(volume_linear))

func _on_music_volume_changed(value: float) -> void:
	var volume_linear = value / 100.0  # Convert 0-100 to 0-1
	AudioServer.set_bus_volume_db(1, linear_to_db(volume_linear))

func _on_sfx_volume_changed(value: float) -> void:
	var volume_linear = value / 100.0  # Convert 0-100 to 0-1
	AudioServer.set_bus_volume_db(2, linear_to_db(volume_linear))

func _db_to_slider(db: float) -> float:
	# Convert decibels to 0-100 slider range
	var linear = db_to_linear(db)
	return linear * 100.0

func _process(delta: float) -> void:
	# Update title rainbow animation
	rainbow_timer += delta

	if rainbow_timer >= ANIMATION_SPEED:
		rainbow_timer = 0.0
		color_offset = (color_offset + 1) % RAINBOW_COLORS.size()
		_update_rainbow_text()

	# Update button rainbow animation (if any buttons are hovered/pressed)
	if hovered_buttons.size() > 0 or pressed_buttons.size() > 0:
		button_rainbow_timer += delta

		if button_rainbow_timer >= BUTTON_ANIMATION_SPEED:
			button_rainbow_timer = 0.0
			button_color_offset = (button_color_offset + 1) % RAINBOW_COLORS.size()
			_update_button_colors()

func _update_rainbow_text() -> void:
	var bbcode_text = ""

	for i in range(TITLE_TEXT.length()):
		var char = TITLE_TEXT[i]

		# Skip coloring spaces
		if char == " ":
			bbcode_text += " "
			continue

		# Get color from rainbow array with offset
		var color_index = (i + color_offset) % RAINBOW_COLORS.size()
		var color = RAINBOW_COLORS[color_index]

		# Convert Color to hex string for BBCode
		var hex = "#" + color.to_html(false)
		bbcode_text += "[color=%s]%s[/color]" % [hex, char]

	title_label.text = bbcode_text

func _connect_button_signals(button: Button) -> void:
	button.mouse_entered.connect(_on_button_mouse_entered.bind(button))
	button.mouse_exited.connect(_on_button_mouse_exited.bind(button))
	button.button_down.connect(_on_button_pressed.bind(button))
	button.button_up.connect(_on_button_released.bind(button))

func _on_button_mouse_entered(button: Button) -> void:
	if button not in hovered_buttons:
		hovered_buttons.append(button)

func _on_button_mouse_exited(button: Button) -> void:
	if button in hovered_buttons:
		hovered_buttons.erase(button)
	# Reset button color when no longer hovered and not pressed
	if button not in pressed_buttons:
		button.modulate = Color.WHITE

func _on_button_pressed(button: Button) -> void:
	if button not in pressed_buttons:
		pressed_buttons.append(button)

func _on_button_released(button: Button) -> void:
	if button in pressed_buttons:
		pressed_buttons.erase(button)
	# Reset button color when released and not hovered
	if button not in hovered_buttons:
		button.modulate = Color.WHITE

func _update_button_colors() -> void:
	var current_color = RAINBOW_COLORS[button_color_offset]

	# Apply rainbow color to all hovered and pressed buttons using modulate
	# (modulate works regardless of theme styles)
	for button in hovered_buttons:
		button.modulate = current_color

	for button in pressed_buttons:
		button.modulate = current_color
