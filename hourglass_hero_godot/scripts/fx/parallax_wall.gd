## One depth of the room, drawn procedurally and slid against the camera.
##
## Godot ships `Parallax2D`, and this does not use it. That node earns its keep
## by tiling an unbounded background against a camera it does not control; here
## the camera is ours, every level is a few hundred pixels of bounded world, and
## the whole scene is `_draw()` calls with no texture to tile. Against that,
## `position = camera * (1 - scroll)` is the entire feature — and it stays
## predictable under a zoomed camera, which is the case that would otherwise
## need testing against someone else's node.
class_name ParallaxWall
extends Node2D

enum Style {
	FAR, ## Distant wall: dense columns, beams, and the clock face.
	NEAR, ## Closer pillars with a lit cap.
	FORE, ## Passes between the player and the camera.
}

## 1.0 moves with the world, 0.0 is pinned to the camera, above 1.0 rushes past.
@export var scroll := 0.35
@export var style: Style = Style.FAR

## Drawn a screen wider than the level in both directions: a layer that scrolls
## at a different rate runs out of itself at the edges otherwise.
const MARGIN := 700.0

var tone := Color.WHITE: set = _set_tone

var _world := Vector2(960.0, 540.0)


## Sizes the wall to a level and reseeds its pattern. The seed is the level's
## own dimensions, so every level gets a different room and gets the same one
## every time it loads — a fresh random each frame would make the wall crawl.
func configure(world_size: Vector2, colour: Color) -> void:
	_world = world_size
	tone = colour


func sync(camera_position: Vector2) -> void:
	position = camera_position * (1.0 - scroll)


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(_world) + Vector2i(style, 0))
	var left := -MARGIN
	var right := _world.x + MARGIN
	var bottom := _world.y + MARGIN

	match style:
		Style.FAR:
			_draw_far(rng, left, right, bottom)
		Style.NEAR:
			_draw_near(rng, left, right, bottom)
		Style.FORE:
			_draw_fore(rng, left, right, bottom)


## The far wall: a stone face of columns crossed by beams, with a clock let into
## it. The clock is the one piece of scenery that says what this game is about,
## so it is placed by hand at the level's centre rather than left to the seed.
func _draw_far(rng: RandomNumberGenerator, left: float, right: float, bottom: float) -> void:
	var x := left
	while x < right:
		var top := -MARGIN + rng.randf_range(0.0, 140.0)
		draw_rect(Rect2(x, top, 128.0, bottom - top), tone)
		x += 210.0

	var beam := tone.darkened(0.28)
	var y := -MARGIN
	while y < bottom:
		draw_rect(Rect2(left, y, right - left, 22.0), beam)
		y += 190.0

	var centre := Vector2(_world.x * 0.5, _world.y * 0.34)
	var radius := minf(_world.x, _world.y) * 0.30
	var face := tone.lightened(0.16)
	draw_arc(centre, radius, 0.0, TAU, 96, face, 5.0, true)
	for i in 12:
		var a := TAU * i / 12.0
		var dir := Vector2(cos(a), sin(a))
		draw_line(centre + dir * radius * 0.86, centre + dir * radius * 0.97, face, 4.0, true)
	# Frozen at midnight, which is the hour the last level is named for.
	draw_line(centre, centre + Vector2(0.0, -radius * 0.62), face, 5.0, true)
	draw_line(centre, centre + Vector2(0.0, -radius * 0.42), face, 7.0, true)


## Nearer pillars, lit along the top edge — the same trick the platforms use, so
## the scenery reads as being made of the same stuff as the level.
func _draw_near(rng: RandomNumberGenerator, left: float, right: float, bottom: float) -> void:
	var cap := tone.lightened(0.22)
	var inner := tone.darkened(0.3)
	var x := left
	while x < right:
		var width := rng.randf_range(58.0, 86.0)
		var top := rng.randf_range(-MARGIN, _world.y * 0.25)
		draw_rect(Rect2(x, top, width, bottom - top), tone)
		draw_rect(Rect2(x, top, width, 5.0), cap)
		draw_rect(Rect2(x + width * 0.34, top + 24.0, width * 0.32, bottom - top), inner)
		x += rng.randf_range(300.0, 400.0)


## The pillars that sweep between the player and the camera.
##
## Kept sparse, narrow and translucent on purpose. A foreground that is any
## heavier stops being depth and starts being a thing that hides spikes.
func _draw_fore(rng: RandomNumberGenerator, left: float, right: float, bottom: float) -> void:
	# Nearly opaque. At 0.55 these pillars were near-black on a near-black room
	# and only their edge highlight survived, which read as a scratch on the
	# screen rather than as something standing between you and the level.
	var body := Color(tone, 0.92)
	var edge := Color(tone.lightened(0.45), 0.7)
	var x := left
	while x < right:
		var width := rng.randf_range(54.0, 92.0)
		draw_rect(Rect2(x, -MARGIN, width, bottom + MARGIN), body)
		draw_rect(Rect2(x + width - 4.0, -MARGIN, 4.0, bottom + MARGIN), edge)
		x += rng.randf_range(520.0, 760.0)


func _set_tone(value: Color) -> void:
	tone = value
	queue_redraw()
