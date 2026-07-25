## Autoload `Screen` — the window, and nothing else.
##
## The game launches fullscreen (`window/size/mode` in `project.godot`). This is
## the way back out: a fullscreen game with no escape hatch is a trap for anyone
## wanting to alt-tab, record a window, or run it beside the editor.
##
## Alt+Enter is the primary binding because macOS keeps F11 for Show Desktop and
## may swallow it; F11 is there for everyone else. Deliberately kept out of
## `Game`, which owns run state and has no business touching the display.
extends Node


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("toggle_fullscreen"):
		return
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
	get_viewport().set_input_as_handled()
