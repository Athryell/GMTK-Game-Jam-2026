## Volume sliders — one per audio bus, generated from `Audio.BUSES`.
##
## Self-contained on purpose: drop this scene into the menu, a pause screen and
## the tuning panel and all three work, without those three having to agree
## about anything. It talks to `Audio` and to nothing else.
##
## It also listens to `Audio.volume_changed`, so two copies on screen at once
## cannot drift apart — moving a slider in one moves it in the other.
class_name AudioSettings
extends VBoxContainer

## Bus name → its slider, so a change from elsewhere can resync the widget.
var _sliders: Dictionary = {}


func _ready() -> void:
	for bus in Audio.BUSES:
		add_child(_make_row(bus))
	Audio.volume_changed.connect(_on_volume_changed)


func _make_row(bus: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var label := Label.new()
	label.text = bus.to_upper()
	label.modulate = Palette.TEXT_DIM
	label.custom_minimum_size.x = 74.0
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = Audio.get_volume(bus)
	slider.custom_minimum_size = Vector2(180.0, 16.0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)

	var value := Label.new()
	value.modulate = Palette.SAND_FULL
	value.custom_minimum_size.x = 44.0
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)

	var render := func(v: float) -> void:
		value.text = "%d%%" % int(round(v * 100.0))
	render.call(slider.value)

	slider.value_changed.connect(func(v: float) -> void:
		Audio.set_volume(bus, v)
		render.call(v))

	_sliders[bus] = {"slider": slider, "render": render}
	return row


func _on_volume_changed(bus: String, linear: float) -> void:
	if not _sliders.has(bus):
		return
	# `set_value_no_signal`: `Audio` is already holding this value, and routing
	# back through `set_volume` would bounce between two copies of this panel.
	_sliders[bus].slider.set_value_no_signal(linear)
	_sliders[bus].render.call(linear)
