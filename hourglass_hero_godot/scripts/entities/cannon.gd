@tool
## A laser cannon, in three beats: it tracks the player, it LOCKS, it fires.
##
## For `lock_time` the line stops following you and charges in place, and where
## it points at the end of that is where the shot goes — so the warning is "the
## beam will be exactly THERE" rather than "a cannon is here".
##
## The shot travels at `BEAM_SPEED` rather than existing all at once, and kills
## only where it has reached. It stops at the first thing it meets, player or
## wall alike, so a block you can stand behind is real cover.
class_name Cannon
extends Node2D

## How far the beam reaches before it gives up, in px. Longer than any level is
## wide, so the beam only ever ends on something.
const RANGE := 2000.0
## How fast the shot travels down the line it was given, in px/s.
const BEAM_SPEED := 1500.0

const BODY_RADIUS := 13.0
const BARREL_LENGTH := 20.0
const BARREL_WIDTH := 9.0
## The line is thin and see-through while it tracks, and grows to the full shot
## across the lock.
const AIM_WIDTH := 2.0
const AIM_ALPHA := 0.28
const FIRE_WIDTH := 8.0
const CORE_RATIO := 0.35
## How much the muzzle swells while charging, as a fraction of `BODY_RADIUS`.
const MUZZLE_SWELL := 0.9

@export var plane: Planes.Kind = Planes.Kind.BOTH: set = _set_plane

@export_group("Timing")
## Seconds spent tracking the player, before the aim is locked.
@export_range(0.2, 5.0, 0.05) var aim_time := 1.1
## Seconds the locked line charges before the shot. This is the dodge window —
## shorten it and the cannon stops being fair.
@export_range(0.1, 3.0, 0.05) var lock_time := 0.7
## Seconds the beam stays lethal once it has arrived.
@export_range(0.05, 2.0, 0.05) var fire_time := 0.35
## Where in the cycle this cannon starts, 0 to 1. Two cannons of equal period
## fire in lockstep unless this differs.
@export_range(0.0, 1.0, 0.05) var phase := 0.0

@onready var _ray: RayCast2D = $Ray

var _player: Player
## Unit vector the barrel points along, in this node's own space.
var _aim := Vector2.LEFT
var _clock := 0.0
## 0 while tracking, climbing to 1 at the instant of the shot.
var _charge := 0.0
var _firing := false
## How far down the line the shot has got, in px. Nothing past this is lethal,
## and nothing past this is drawn.
var _reach := 0.0
var _active := true
## True while a jump would land the player in this plane: brighter, still inert.
var _next := false


func _ready() -> void:
	_ray.collision_mask = Layers.SOLID | Layers.PLAYER
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	_clock = phase * _period()
	Game.plane_changed.connect(_on_plane_changed)
	Game.next_plane_changed.connect(_on_next_plane_changed)
	Tuning.changed.connect(queue_redraw)
	EntityLight.attach(self, plane, Vector2.ZERO, Palette.MONSTER, 130.0, 0.5)
	_on_plane_changed(Game.plane)
	_on_next_plane_changed(Game.next_plane)


func _physics_process(delta: float) -> void:
	if not _active or Game.status != Game.Status.PLAY:
		return
	_clock = fmod(_clock + delta, _period())
	_firing = _clock >= aim_time + lock_time
	# The aim is only ever changed in the first beat. Everything after it —
	# the charge, the shot, what the shot hits — reads the line already given.
	if _clock < aim_time:
		_track_player()
		_charge = 0.0
		_reach = 0.0
	elif not _firing:
		_charge = (_clock - aim_time) / lock_time
		_reach = 0.0
	else:
		_charge = 1.0
		_reach += delta * BEAM_SPEED

	_ray.target_position = _aim * RANGE
	_ray.force_raycast_update()
	if _firing and _ray.get_collider() is Player and _reach >= _hit_distance():
		Game.kill()
	queue_redraw()


func _draw() -> void:
	var tint := Palette.ghost(Palette.MONSTER, _active or Engine.is_editor_hint(), _next)
	var muzzle := _aim * BARREL_LENGTH
	# No beam in the editor: without physics the ray has never been cast, so its
	# collision point is whatever it last happened to hold.
	if not Engine.is_editor_hint():
		_draw_beam(muzzle, tint)
	# Both outlines before either fill, so each shape covers the other's line
	# where they overlap: ink at the joint would seam a cannon that is one piece.
	Outline.polygon(self,
		HourglassShape.thread_quad(Vector2.ZERO, muzzle, BARREL_WIDTH), tint.a)
	Outline.circle(self, Vector2.ZERO, BODY_RADIUS, tint.a)
	draw_line(Vector2.ZERO, muzzle, tint.darkened(0.25), BARREL_WIDTH)
	draw_circle(Vector2.ZERO, BODY_RADIUS, tint.darkened(0.5))
	# The eye swells and lights up with the charge, so the cannon warns you even
	# when the line itself is behind a wall.
	draw_circle(Vector2.ZERO, BODY_RADIUS * (0.45 + MUZZLE_SWELL * _charge * 0.45),
		tint.darkened(0.2).lerp(Color.WHITE, _charge))
	if Engine.is_editor_hint():
		# The body only: tagging the barrel too would move the chip with the aim.
		PlaneMarker.tag(self, Polygons.rect(
			Rect2(-Vector2.ONE * BODY_RADIUS, Vector2.ONE * BODY_RADIUS * 2.0)), plane)


func _draw_beam(muzzle: Vector2, tint: Color) -> void:
	var span := _hit_distance()
	if _firing:
		span = minf(span, _reach)
	var end := _aim * maxf(span, BARREL_LENGTH)
	# Width and alpha ramp together across the lock, so the shot is the end of a
	# movement you have been watching rather than a new thing appearing.
	var width := lerpf(AIM_WIDTH, FIRE_WIDTH, _charge)
	var alpha := tint.a * lerpf(AIM_ALPHA, 1.0, _charge)
	draw_line(muzzle, end, Color(tint.r, tint.g, tint.b, alpha), width)
	if _firing:
		draw_line(muzzle, end, Color(1.0, 1.0, 1.0, tint.a), width * CORE_RATIO)


## How far along the line the first solid — or the player — is, in px.
func _hit_distance() -> float:
	if not _ray.is_colliding():
		return RANGE
	return to_local(_ray.get_collision_point()).length()


## Track, charge, shoot. Guarded because a period of zero would divide by
## nothing in `fmod`.
func _period() -> float:
	return maxf(aim_time + lock_time + fire_time, 0.1)


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


func _on_next_plane_changed(next: Planes.Kind) -> void:
	_next = plane == next
	queue_redraw()


func _set_plane(value: Planes.Kind) -> void:
	plane = value
	queue_redraw()
