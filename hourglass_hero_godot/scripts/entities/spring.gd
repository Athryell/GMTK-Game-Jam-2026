@tool
## Spring: launches the player upwards WITHOUT flipping the hourglass and
## without changing plane. Free height and reach, but no refuel — the exception
## that decouples "jumping" from "refuelling".
##
## It is an Area2D rather than a solid: you don't bump into it sideways, you
## walk into its column and get launched, exactly like the JS prototype.
class_name Spring
extends PlaneArea

## Impulse, in px/s. At 0 it takes `spring_power` from the tuning panel.
@export_range(0.0, 3000.0, 10.0) var power := 0.0

var _compress := 0.0 ## Visual cue: the spring squashes, then springs back.


func _init() -> void:
	size = Vector2(84.0, 22.0)
	light_tint = Palette.SPRING
	light_radius = 120.0
	light_energy = 0.9


func _process(delta: float) -> void:
	if _compress <= 0.0:
		return
	_compress = maxf(0.0, _compress - delta * Tuning.cfg.spring_recovery_speed)
	queue_redraw()


func _touched(player: Player) -> void:
	# Only bounce when coming down onto it: passing up through it from below
	# must not re-launch.
	if player.velocity.y < 0.0:
		return
	player.bounce(power if power > 0.0 else Tuning.cfg.spring_power)
	_compress = 1.0
	queue_redraw()


func _draw() -> void:
	# On impact the spring flattens, then recovers as it extends.
	var squash := 1.0 - 0.45 * _compress
	var h := size.y * squash
	var top := size.y - h
	var colour := _shade(Palette.SPRING)
	draw_rect(Rect2(Vector2(0.0, top), Vector2(size.x, h)), colour)
	# Three upward chevrons: the launch direction reads at a glance.
	var mid := size.x / 2.0
	for i in 3:
		var y := top + h * (0.25 + 0.25 * i)
		draw_line(Vector2(mid - 14.0, y + 6.0), Vector2(mid, y), colour.darkened(0.5), 2.0)
		draw_line(Vector2(mid, y), Vector2(mid + 14.0, y + 6.0), colour.darkened(0.5), 2.0)
