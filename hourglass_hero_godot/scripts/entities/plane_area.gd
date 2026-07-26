@tool
## Base class for plane-aware triggers (door, spring, spikes, monster): owns size,
## plane, ghosting and the light. The origin is the TOP-LEFT corner of `size`.
class_name PlaneArea
extends Area2D

@export var size := Vector2(32.0, 32.0): set = _set_size
@export var plane: Planes.Kind = Planes.Kind.BOTH: set = _set_plane

## Light settings, set by a subclass in `_init`. Radius 0 means no light.
var light_tint := Color.WHITE
var light_radius := 0.0
var light_energy := 1.0
## Optional breathing. See [EntityLight].
var light_pulse_rate := 0.0
var light_pulse_depth := 0.0

@onready var _shape: CollisionShape2D = $CollisionShape2D

## True while the player shares this plane. Inactive: faint, inert, unlit.
var _active := true
## True while a jump would land the player in this plane: brighter, still inert.
var _next := false


func _ready() -> void:
	_apply_size()
	collision_mask = Layers.PLAYER
	if Engine.is_editor_hint():
		return
	Game.plane_changed.connect(_on_plane_changed)
	Game.next_plane_changed.connect(_on_next_plane_changed)
	# Ghost alpha is read inside `_draw`, so a tuning change needs a new frame.
	Tuning.changed.connect(queue_redraw)
	body_entered.connect(_on_body_entered)
	if light_radius > 0.0:
		EntityLight.attach(self, plane, size, light_tint, light_radius, light_energy,
			light_pulse_rate, light_pulse_depth)
	_on_plane_changed(Game.plane)
	_on_next_plane_changed(Game.next_plane)


## Override: what this entity does to the player. Only called while active.
func _touched(_player: Player) -> void:
	pass


## Override this, not `_draw`: the base owns the frame so the editor plane tag
## lands on every entity without each one remembering to ask for it.
func _paint() -> void:
	pass


func _draw() -> void:
	_paint()
	if Engine.is_editor_hint():
		PlaneMarker.tag(self, Polygons.rect(Rect2(Vector2.ZERO, size)), plane)


## `base` solid in this plane, ghosted in the other. Always solid in the editor.
func _shade(base: Color) -> Color:
	return Palette.ghost(base, _active or Engine.is_editor_hint(), _next)


func _on_body_entered(body: Node2D) -> void:
	if _active and body is Player:
		_touched(body as Player)


func _on_plane_changed(current: Planes.Kind) -> void:
	_active = Planes.is_active(plane, current)
	monitoring = _active
	queue_redraw()


func _on_next_plane_changed(next: Planes.Kind) -> void:
	_next = plane == next
	queue_redraw()


func _set_size(value: Vector2) -> void:
	size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
	_apply_size()


func _set_plane(value: Planes.Kind) -> void:
	plane = value
	queue_redraw()


## The hitbox, refitted to `size`. Override when the hitbox is not the whole rect.
func _apply_size() -> void:
	queue_redraw()
	if not is_node_ready():
		return
	var rect := _shape.shape as RectangleShape2D
	rect.size = size
	_shape.position = size / 2.0
