@tool
## Monster: patrols along an axis and kills on contact, within its own plane only.
class_name Monster
extends PlaneArea

@export_group("Patrol")
@export var move_axis: PingPong.Axis = PingPong.Axis.X
## Patrol travel, in px, from the editor-placed position.
@export_range(0.0, 800.0, 1.0) var move_distance := 90.0
## Patrol speed, in px/s.
@export_range(0.0, 400.0, 1.0) var move_speed := 115.0
## Start offset in the cycle. All movers share one clock, so equal-period
## entities are locked in step at 0.
@export_range(0.0, 1.0, 0.05) var move_phase := 0.0

var _origin := Vector2.ZERO
var _elapsed := 0.0


func _init() -> void:
	size = Vector2(30.0, 34.0)
	plane = Planes.Kind.P0
	light_tint = Palette.MONSTER
	light_radius = 105.0
	light_energy = 0.8


func _ready() -> void:
	_origin = position
	super()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if move_axis == PingPong.Axis.NONE or move_speed <= 0.0:
		return
	_elapsed += delta
	position = _origin + PingPong.offset_vector(
		move_axis, _elapsed, move_distance, move_speed, move_phase)


func _touched(_player: Player) -> void:
	Game.kill()


func _draw() -> void:
	var colour := _shade(Palette.MONSTER)
	draw_rect(Rect2(Vector2.ZERO, size), colour)
	var eye := Color(0.06, 0.05, 0.09, colour.a)
	var r := maxf(size.x * 0.09, 2.0)
	draw_circle(Vector2(size.x * 0.32, size.y * 0.34), r, eye)
	draw_circle(Vector2(size.x * 0.68, size.y * 0.34), r, eye)
