## Autoload `Screen` — fullscreen toggle only. The game launches fullscreen via
## `window/size/mode` in `project.godot`; the `toggle_fullscreen` action (Alt+Enter,
## F11 — macOS may swallow F11) is the way back out.
extends Node


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("toggle_fullscreen"):
		return
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
	get_viewport().set_input_as_handled()
