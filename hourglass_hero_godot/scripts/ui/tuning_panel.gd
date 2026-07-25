## In-game tuning panel (F1).
##
## The sliders are written nowhere: they are GENERATED from the `@export_range`
## entries in `game_config.gd`. Add a variable there and its slider shows up
## here on its own, under its `@export_group` heading.
extends CanvasLayer

const PANEL_WIDTH := 340.0

@onready var _panel: PanelContainer = $Panel
@onready var _rows: VBoxContainer = $Panel/Margin/Layout/Scroll/Rows
@onready var _save_button: Button = $Panel/Margin/Layout/Buttons/Save
@onready var _reset_button: Button = $Panel/Margin/Layout/Buttons/Reset
@onready var _status: Label = $Panel/Margin/Layout/Status

## Variable name → { slider, render }, so Reset can resync the widgets.
var _sliders: Dictionary = {}


func _ready() -> void:
	_panel.custom_minimum_size.x = PANEL_WIDTH
	_build_rows()
	_save_button.pressed.connect(_on_save)
	_reset_button.pressed.connect(_on_reset)
	# Saving rewrites a file under res://, which an exported build cannot do —
	# better to say so than to fail silently.
	_save_button.disabled = not OS.has_feature("editor")
	if _save_button.disabled:
		_save_button.tooltip_text = "Only available from the Godot editor."
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_tuner"):
		visible = not visible
		_status.text = ""
		get_viewport().set_input_as_handled()


func _build_rows() -> void:
	var current_group := ""
	for prop in Tuning.tunable_properties():
		if prop.group != current_group:
			current_group = prop.group
			_rows.add_child(_make_group_header(current_group))
		_rows.add_child(_make_slider_row(prop))


func _make_group_header(title: String) -> Control:
	var label := Label.new()
	label.text = title.to_upper()
	label.modulate = Palette.TEXT_DIM
	label.custom_minimum_size.y = 26.0
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return label


func _make_slider_row(prop: Dictionary) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 0)

	var header := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = prop.name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_label := Label.new()
	value_label.modulate = Palette.SAND_FULL
	header.add_child(name_label)
	header.add_child(value_label)

	var slider := HSlider.new()
	slider.min_value = prop.min
	slider.max_value = prop.max
	slider.step = prop.step
	slider.value = Tuning.cfg.get(prop.name)
	slider.custom_minimum_size.y = 18.0

	var render_value := func(v: float) -> void:
		value_label.text = ("%.2f" % v) if prop.step < 1.0 else str(int(round(v)))
	render_value.call(slider.value)

	slider.value_changed.connect(func(v: float) -> void:
		Tuning.set_value(prop.name, v)
		render_value.call(v)
		_status.text = "")

	row.add_child(header)
	row.add_child(slider)
	_sliders[prop.name] = {"slider": slider, "render": render_value}
	return row


func _on_save() -> void:
	_status.text = "Saved to game_config.tres" if Tuning.save() \
		else "Save failed (see the console)"


func _on_reset() -> void:
	Tuning.reset()
	for prop_name in _sliders:
		var value: float = Tuning.cfg.get(prop_name)
		# `set_value_no_signal`: Tuning.reset() already wrote everything, no
		# need to route each slider back through set_value.
		_sliders[prop_name].slider.set_value_no_signal(value)
		_sliders[prop_name].render.call(value)
	_status.text = "Values restored"
