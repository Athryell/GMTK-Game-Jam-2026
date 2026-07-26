@tool
## Spring: launches the way it is turned, WITHOUT flipping or changing plane, so
## it gives distance but no refuel. An Area2D, not a solid.
class_name Spring
extends PlaneArea

## FOOT and PLATE are fractions of the pad's height. TRAVEL is not: it is a
## fraction of the gap left over, `(size.y - foot - plate) * TRAVEL`.
const FOOT := 0.14
const PLATE := 0.30
const TRAVEL := 0.62

## Post width and inset from each end, as fractions of the pad's width.
const POST := 0.045
const POST_INSET := 0.08

## Impulse, in px/s. At 0 it takes `spring_power` from the tuning panel.
@export_range(0.0, 3000.0, 10.0) var power := 0.0

var _compress := 0.0 ## 1 on impact, decays back to 0.


func _init() -> void:
	# Origin is the TOP-LEFT corner: a pad on a floor sits at the floor's top
	# minus its own height, and turning it swings it about that corner.
	size = Vector2(56.0, 14.0)
	light_tint = Palette.SPRING
	light_radius = 120.0
	light_energy = 0.9


func _process(delta: float) -> void:
	if _compress <= 0.0:
		return
	_compress = maxf(0.0, _compress - delta * Tuning.cfg.spring_recovery_speed)
	queue_redraw()


## The way the plate faces, in world space. Turning the node in the editor turns
## the art, the hitbox and the launch together, and the launch is NOT relative to
## gravity: a pad drawn pointing up throws you up the screen, world over or not.
func push_direction() -> Vector2:
	return Vector2.UP.rotated(global_rotation)


func _touched(player: Player) -> void:
	# Only on the way in: leaving the pad the way it pushes must not fire it again.
	var push := push_direction()
	if player.velocity.dot(push) > 0.0:
		return
	player.bounce(power if power > 0.0 else Tuning.cfg.spring_power, push)
	_compress = 1.0
	Audio.sfx("bounce")
	queue_redraw()


## Only the plate moves on impact, so the closing gap reads as compression.
func _paint() -> void:
	var colour := _shade(Palette.SPRING)
	var foot := maxf(2.0, size.y * FOOT)
	var plate := maxf(4.0, size.y * PLATE)
	var top := (size.y - foot - plate) * TRAVEL * _compress

	# The two slabs only: a line round each post would read as more springs.
	var foot_box := Rect2(Vector2(0.0, size.y - foot), Vector2(size.x, foot))
	Outline.rect(self, foot_box, colour.a)
	Outline.rect(self, Rect2(Vector2(0.0, top), Vector2(size.x, plate)), colour.a)

	draw_rect(foot_box, colour.darkened(0.55))
	var post := maxf(3.0, size.x * POST)
	var inset := size.x * POST_INSET
	for x in [inset, size.x - inset - post]:
		draw_rect(Rect2(Vector2(x, top + plate),
			Vector2(post, size.y - foot - top - plate)), colour.darkened(0.38))
	draw_rect(Rect2(Vector2(0.0, top), Vector2(size.x, plate)), colour)
	draw_rect(Rect2(Vector2(0.0, top), Vector2(size.x, 2.0)), colour.lightened(0.45))
