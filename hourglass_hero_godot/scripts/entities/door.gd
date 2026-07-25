@tool
## The level exit. Like everything else it belongs to a plane: a "back" door
## forces you to ARRIVE in the back plane, so you have to count your jumps.
class_name Door
extends Area2D

@export var size := Vector2(34.0, 64.0): set = _set_size
@export var plane: Planes.Kind = Planes.Kind.BOTH: set = _set_plane

@onready var _shape: CollisionShape2D = $CollisionShape2D

var _active := true
var _pulse := 0.0


func _ready() -> void:
	_apply_size()
	collision_mask = Layers.PLAYER
	if Engine.is_editor_hint():
		return
	Game.plane_changed.connect(_on_plane_changed)
	body_entered.connect(_on_body_entered)
	_on_plane_changed(Game.plane)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_pulse += delta
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if _active and body is Player and Game.status == Game.Status.PLAY:
		Game.win()


func _draw() -> void:
	var alpha := 1.0 if _active or Engine.is_editor_hint() else Tuning.cfg.ghost_alpha
	var colour := Color(Palette.DOOR, alpha)
	# A breathing halo: the exit catches the eye even from far away.
	var glow := 6.0 + 3.0 * sin(_pulse * 3.0)
	draw_rect(Rect2(Vector2(-glow, -glow), size + Vector2(glow, glow) * 2.0),
		Color(Palette.DOOR, 0.18 * alpha))
	draw_rect(Rect2(Vector2.ZERO, size), colour)
	draw_rect(Rect2(Vector2(4.0, 4.0), size - Vector2(8.0, 8.0)), colour.darkened(0.55))
	draw_circle(Vector2(size.x * 0.75, size.y * 0.55), 3.0, colour)


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
