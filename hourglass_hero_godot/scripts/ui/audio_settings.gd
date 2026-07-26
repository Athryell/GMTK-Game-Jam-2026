## Volume sliders — one per audio bus, generated from `Audio.BUSES`.
## Talks only to `Audio`, and follows `Audio.volume_changed` so several copies
## on screen stay in sync.
class_name AudioSettings
extends VBoxContainer

## Bus name → { slider, render }, so an external change can resync the widget.
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

	# An `HSlider` carries no `focus` stylebox, and a full one covers its own track,
	# so focus grows the bar and brightens it — see `FocusedSlider` in the theme.
	slider.focus_entered.connect(_mark_focus.bind(slider, label, true))
	slider.focus_exited.connect(_mark_focus.bind(slider, label, false))

	_sliders[bus] = {"slider": slider, "render": render}
	return row


static func _mark_focus(slider: HSlider, label: Label, on: bool) -> void:
	slider.theme_type_variation = &"FocusedSlider" if on else &""
	label.modulate = Palette.GLASS if on else Palette.TEXT_DIM


func _on_volume_changed(bus: String, linear: float) -> void:
	if not _sliders.has(bus):
		return
	# No signal: `Audio` already holds this value; re-emitting would ping-pong.
	_sliders[bus].slider.set_value_no_signal(linear)
	_sliders[bus].render.call(linear)
