## Screenshot harness: boots the real game and saves frames to disk.
##
##   godot --path hourglass_hero_godot tests/screenshot.tscn -- <out_dir> [flip] [dry] [levels…]
##
## Levels are 1-based; none given shoots every level. `flip` jumps once first,
## the only way to see the BACK plane. Needs a real window — under `--headless`
## the viewport comes back blank.
extends Node

const MAIN := preload("res://scenes/main.tscn")
## Frames to let the camera, parallax and flip tween settle before shooting.
const SETTLE_FRAMES := 45

var _out_dir := "res://../shots"
var _levels: Array[int] = []
var _flip := false
var _dry := false


func _ready() -> void:
	_parse_args()
	DirAccess.make_dir_recursive_absolute(_out_dir)

	var main := MAIN.instantiate()
	add_child(main)
	await get_tree().process_frame

	if _levels.is_empty():
		for i in Game.level_scenes.size():
			_levels.append(i)

	for index in _levels:
		Game.start_level(index)
		main._load_current_level()
		# Nudge right so the shot catches the game in motion, not at rest on spawn.
		Input.action_press("move_right")
		if _flip:
			# Early, so the backdrop's recolour tween has landed by the shot.
			await get_tree().process_frame
			Input.action_press("jump")
			await get_tree().process_frame
			Input.action_release("jump")
		for i in SETTLE_FRAMES:
			await get_tree().process_frame
			# Hold the clock steady so a slow level does not die mid-shoot; `dry`
			# holds it just above empty to photograph the last-seconds look.
			Game.sand = Tuning.cfg.sand_warn * 0.08 if _dry else Tuning.cfg.sand_max
		Input.action_release("move_right")
		await RenderingServer.frame_post_draw

		var image := get_viewport().get_texture().get_image()
		var path := "%s/level_%02d.png" % [_out_dir, index + 1]
		var err := image.save_png(path)
		print("  %s  %s" % ["ok  " if err == OK else "FAIL", path])

	get_tree().quit(0)


func _parse_args() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	for i in range(1, args.size()):
		if args[i] == "flip":
			_flip = true
		elif args[i] == "dry":
			_dry = true
		elif args[i].is_valid_int():
			_levels.append(args[i].to_int() - 1)
