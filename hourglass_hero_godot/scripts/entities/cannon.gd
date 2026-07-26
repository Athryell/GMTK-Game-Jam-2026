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

const BASE: Texture2D = preload("res://art/sprites/cannon_base.png")
const BARREL: Texture2D = preload("res://art/sprites/cannon_barrell.png")

## Both sprites are 16×16, drawn at two world px per art px so the cannon's
## pixels are the size of the backdrop's rather than half of it. Whole number on
## purpose: at anything fractional the doubled texels straddle world pixels and
## the 1-px outlines tear as the barrel turns. See `Backdrop.ART_SCALE`.
const ART_SIZE := 16.0
const ART_SCALE := 2.0
## The arch in the base is a 2×2 hole about this pixel, and the barrel's butt is
## the middle of its bottom edge. Putting the two on the node's origin is what
## makes the barrel turn IN the hole rather than beside it, so these are measured
## off the art, not guessed — retracing either sprite is the only thing that can
## pull them apart.
const BASE_PIVOT := Vector2(8.0, 15.0)
const BARREL_PIVOT := Vector2(8.0, 16.0)

## How far the muzzle sits from the pivot: the barrel's whole drawn length, since
## the butt is on the pivot and the art points straight up its own sprite.
const BARREL_LENGTH := ART_SIZE * ART_SCALE
## The line is thin and see-through while it tracks, and grows to the full shot
## across the lock.
const AIM_WIDTH := 2.0
const AIM_ALPHA := 0.28
const FIRE_WIDTH := 8.0
const CORE_RATIO := 0.35
## Radius of the glow at the muzzle at full charge, in px.
const MUZZLE_GLOW := 7.0

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
## Its own node, not a shape in `_draw`, purely so it can sit on its own `z_index`:
## swung low the barrel passes through the ground it is bolted to, and drawn over
## the bricks it gives the emplacement away as a flat cut-out.
@onready var _barrel: Sprite2D = $Barrel

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
	# See `terrain.gd` for why this is per-node rather than a project default.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Set here rather than in the scene so the pivot stays measured in ONE place:
	# a `Sprite2D` offset typed into the .tscn would drift from `BARREL_PIVOT` the
	# first time the art moves.
	_barrel.texture = BARREL
	_barrel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_barrel.centered = false
	# Offset is in the sprite's own space, so the scale carries it: the butt still
	# lands on the origin and the whole barrel grows away from it.
	_barrel.offset = -BARREL_PIVOT
	_barrel.scale = Vector2.ONE * ART_SCALE
	if Engine.is_editor_hint():
		set_physics_process(false)
		_refresh()
		return
	_clock = phase * _period()
	Game.plane_changed.connect(_on_plane_changed)
	Game.next_plane_changed.connect(_on_next_plane_changed)
	Tuning.changed.connect(_refresh)
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
	_refresh()


## The node's origin IS the pivot: the hole in the base and the butt of the
## barrel are both laid on it, so the emplacement stays put while the barrel
## swings in its socket.
func _draw() -> void:
	var tint := _tint()
	var art := Color(1.0, 1.0, 1.0, tint.a)
	var muzzle := _aim * BARREL_LENGTH

	# The barrel is `$Barrel`, a rung below on `z_index`, so the emplacement and the
	# ground both cover it. Only the base is struck here.
	draw_texture_rect(BASE, _base_rect(), false, art)

	# No beam in the editor: without physics the ray has never been cast, so its
	# collision point is whatever it last happened to hold.
	if not Engine.is_editor_hint():
		_draw_beam(muzzle, tint)
	# The muzzle lights up as it charges, so the cannon still warns you when the
	# line itself is behind a wall. On the muzzle rather than the body, now the
	# body is a sprite with nothing to swell.
	if _charge > 0.0:
		draw_circle(muzzle, MUZZLE_GLOW * _charge, Color(1.0, 1.0, 1.0, tint.a * _charge))
	if Engine.is_editor_hint():
		# The base only: tagging the barrel too would move the chip with the aim.
		PlaneMarker.tag(self, Polygons.rect(_base_rect()), plane)


## Where the base sits, so its arch lands on the origin.
func _base_rect() -> Rect2:
	return Rect2(-BASE_PIVOT * ART_SCALE, Vector2.ONE * ART_SIZE * ART_SCALE)


func _tint() -> Color:
	return Palette.ghost(Palette.MONSTER, _active or Engine.is_editor_hint(), _next)


## Everything the cannon shows in one call, because the barrel is a separate node
## and only the beam and the base go through `_draw`: aiming one without the
## other leaves the shot coming out of a barrel pointing somewhere else.
func _refresh() -> void:
	if _barrel != null:
		# The art points up its own sprite, so the turn is measured from UP rather
		# than from RIGHT — `_aim` is a direction in this node's space either way.
		_barrel.rotation = Vector2.UP.angle_to(_aim)
		_barrel.modulate = Color(1.0, 1.0, 1.0, _tint().a)
	queue_redraw()


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
	_refresh()


func _on_next_plane_changed(next: Planes.Kind) -> void:
	_next = plane == next
	_refresh()


func _set_plane(value: Planes.Kind) -> void:
	plane = value
	_refresh()
