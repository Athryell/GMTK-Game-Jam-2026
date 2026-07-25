## Flow-turn harness: one contact sheet of the sand reversing, step by step.
##
##   godot --path hourglass_hero_godot tests/flow_sheet.tscn -- <out.png> [fill]
##
## The glass alone, drawn once per value of `invert`, reading left to right then
## top to bottom: a glitch shows up as one cell out of step with its neighbours.
## Needs a real window, like `screenshot.tscn`.
extends Node2D

const COLUMNS := 6
const ROWS := 2
const CELL := Vector2(160.0, 270.0)
const GLASS := Vector2(96.0, 180.0)

var _fill := 0.65


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var path := args[0] if args.size() > 0 else "res://../shots/flow_sheet.png"
	if args.size() > 1 and args[1].is_valid_float():
		_fill = args[1].to_float()
	queue_redraw()
	await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(path)
	print("  %s  %s" % ["ok  " if err == OK else "FAIL", path])
	get_tree().quit(0 if err == OK else 1)


func _draw() -> void:
	# P0's floor: the backdrop this sheet has always been read against.
	draw_rect(Rect2(Vector2.ZERO, Vector2(960.0, 540.0)), Palette.room(Planes.Kind.P0)[1])
	var cells := COLUMNS * ROWS
	for i in cells:
		var invert := float(i) / (cells - 1)
		var centre := Vector2(
			(i % COLUMNS + 0.5) * CELL.x, (i / COLUMNS + 0.5) * CELL.y)
		# One tint for every cell: this sheet is about where the sand is.
		draw_set_transform(centre, 0.0, Vector2.ONE)
		# Two chambers: this sheet is about `invert`, and the reversal is easiest to
		# read against the glass everyone already knows.
		HourglassShape.draw_glass(self, GLASS, PackedFloat32Array([_fill, 1.0 - _fill]),
			Palette.SAND_FULL, Vector2.DOWN, 1.5, invert)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
