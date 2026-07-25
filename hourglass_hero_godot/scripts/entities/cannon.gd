@tool
## A laser cannon. It tracks the player while it charges, then fires along the
## line it was holding at the instant the shot went off.
##
## That lock is the whole mechanic: the faint red line tells you where the beam
## WILL be, and the only way out of it is to not be there any more — so the
## answer is a jump, which in this game is also a refuel.
##
## The beam stops at the first thing it meets, player or wall alike, which is
## why a block you can crouch behind is real cover.
class_name Cannon
extends Node2D

## How far the beam reaches before it gives up, in px. Longer than any level is
## wide, so the beam only ever ends on something.
const RANGE := 2000.0

const BODY_RADIUS := 13.0
const BARREL_LENGTH := 20.0
const BARREL_WIDTH := 9.0
## The charging line is thin and see-through; the shot is thick and has a white
## core. Nothing else changes, so the difference reads as one thing: it fired.
const AIM_WIDTH := 2.0
const AIM_ALPHA := 0.3
const FIRE_WIDTH := 8.0
const CORE_RATIO := 0.35

@export var plane: Planes.Kind = Planes.Kind.BOTH: set = _set_plane

@export_group("Timing")
## Seconds spent tracking the player before each shot.
@export_range(0.2, 5.0, 0.05) var aim_time := 1.3
## Seconds the beam stays lethal.
@export_range(0.05, 2.0, 0.05) var fire_time := 0.3
## Where in the cycle this cannon starts, 0 to 1. Two cannons of equal period
## fire in lockstep unless this differs — the same job `move_phase` does for a
## mover.
@export_range(0.0, 1.0, 0.05) var phase := 0.0

@onready var _ray: RayCast2D = $Ray

var _player: Player
## Unit vector the barrel points along, in this node's own space.
var _aim := Vector2.LEFT
var _clock := 0.0
var _firing := false
var _active := true


func _ready() -> void:
	_ray.collision_mask = Layers.SOLID | Layers.PLAYER
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	_clock = phase * _period()
	Game.plane_changed.connect(_on_plane_changed)
	Tuning.changed.connect(queue_redraw)
	EntityLight.attach(self, plane, Vector2.ZERO, Palette.MONSTER, 130.0, 0.5)
	_on_plane_changed(Game.plane)


func _physics_process(delta: float) -> void:
	if not _active or Game.status != Game.Status.PLAY:
		return
	_clock = fmod(_clock + delta, _period())
	_firing = _clock >= aim_time
	if not _firing:
		_track_player()
	_ray.target_position = _aim * RANGE
	_ray.force_raycast_update()
	if _firing and _ray.get_collider() is Player:
		Game.kill()
	queue_redraw()


func _draw() -> void:
	var tint := Palette.ghost(Palette.MONSTER, _active or Engine.is_editor_hint())
	var muzzle := _aim * BARREL_LENGTH
	# No beam in the editor: without physics the ray has never been cast, so its
	# collision point is whatever it last happened to hold.
	if not Engine.is_editor_hint():
		_draw_beam(muzzle, tint)
	draw_line(Vector2.ZERO, muzzle, tint.darkened(0.25), BARREL_WIDTH)
	draw_circle(Vector2.ZERO, BODY_RADIUS, tint.darkened(0.5))
	draw_circle(Vector2.ZERO, BODY_RADIUS * 0.45,
		tint if _firing else tint.darkened(0.2))


func _draw_beam(muzzle: Vector2, tint: Color) -> void:
	var end := to_local(_ray.get_collision_point()) if _ray.is_colliding() \
		else _aim * RANGE
	if not _firing:
		draw_line(muzzle, end,
			Color(tint.r, tint.g, tint.b, tint.a * AIM_ALPHA), AIM_WIDTH)
		return
	draw_line(muzzle, end, tint, FIRE_WIDTH)
	draw_line(muzzle, end, Color(1.0, 1.0, 1.0, tint.a), FIRE_WIDTH * CORE_RATIO)


## One charge plus one shot. Guarded because a period of zero would divide by
## nothing in `fmod`.
func _period() -> float:
	return maxf(aim_time + fire_time, 0.1)


## The player is spawned by `main.gd` after the level exists, so there is no
## looking it up in `_ready` — it is found on the first frame it is there for.
func _track_player() -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(Game.PLAYER_GROUP) as Player
		if _player == null:
			return
	var towards := to_local(_player.global_position)
	if towards.length_squared() > 1.0:
		_aim = towards.normalized()


func _on_plane_changed(current: Planes.Kind) -> void:
	_active = Planes.is_active(plane, current)
	queue_redraw()


func _set_plane(value: Planes.Kind) -> void:
	plane = value
	queue_redraw()
