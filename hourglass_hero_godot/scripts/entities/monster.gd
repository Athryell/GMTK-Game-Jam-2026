@tool
## Monster: patrols along an axis and kills on contact — but only within its own
## plane. A "front" monster does not bite while the player is in "back".
class_name Monster
extends Area2D

@export var size := Vector2(30.0, 34.0): set = _set_size
@export var plane: Planes.Kind = Planes.Kind.FRONT: set = _set_plane

@export_group("Patrol")
@export var move_axis: PingPong.Axis = PingPong.Axis.X
## Travel of the patrol, in px, from where you placed it in the editor.
@export_range(0.0, 800.0, 1.0) var move_distance := 90.0
## Patrol speed, in px/s.
@export_range(0.0, 400.0, 1.0) var move_speed := 115.0
## Where in the cycle it starts, as a fraction of a full there-and-back. Movers
## share one clock, so two of equal period sit in lockstep at 0 — set this to
## spread them into a wave.
@export_range(0.0, 1.0, 0.05) var move_phase := 0.0

@onready var _shape: CollisionShape2D = $CollisionShape2D

var _origin := Vector2.ZERO
var _elapsed := 0.0
var _active := true


func _ready() -> void:
	_origin = position
	_apply_size()
	collision_mask = Layers.PLAYER
	if Engine.is_editor_hint():
		return
	Game.plane_changed.connect(_on_plane_changed)
	body_entered.connect(_on_body_entered)
	EntityLight.attach(self, plane, size, Palette.MONSTER, 105.0, 0.8)
	_on_plane_changed(Game.plane)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if move_axis == PingPong.Axis.NONE or move_speed <= 0.0:
		return
	_elapsed += delta
	position = _origin + PingPong.offset_vector(
		move_axis, _elapsed, move_distance, move_speed, move_phase)


func _on_body_entered(body: Node2D) -> void:
	if _active and body is Player:
		Game.kill()


func _draw() -> void:
	var colour := Palette.MONSTER if _active or Engine.is_editor_hint() \
		else Color(Palette.MONSTER, Tuning.cfg.ghost_alpha)
	draw_rect(Rect2(Vector2.ZERO, size), colour)
	# Two eyes, so a monster reads as a monster and not as a red platform.
	var eye := Color(0.06, 0.05, 0.09, colour.a)
	var r := maxf(size.x * 0.09, 2.0)
	draw_circle(Vector2(size.x * 0.32, size.y * 0.34), r, eye)
	draw_circle(Vector2(size.x * 0.68, size.y * 0.34), r, eye)


func _on_plane_changed(current: Planes.Kind) -> void:
	_active = Planes.is_active(plane, current)
	monitoring = _active
	queue_redraw()


func _set_size(value: Vector2) -> void:
	size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
	_apply_size()


func _set_plane(value: Planes.Kind) -> void:
	plane = value
	queue_redraw()


func _apply_size() -> void:
	queue_redraw()
	if not is_node_ready():
		return
	var rect := _shape.shape as RectangleShape2D
	rect.size = size
	_shape.position = size / 2.0
