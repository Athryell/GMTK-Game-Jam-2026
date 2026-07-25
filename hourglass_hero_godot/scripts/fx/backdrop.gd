## The room behind the level: a graded sky and two walls at different depths.
## Nothing here is collidable or authored — hand it a `world_size`.
class_name Backdrop
extends Node2D

## Recolour time on a flip, in seconds. Deliberately slower than the plane swap.
const RECOLOUR_TIME := 0.26

var _gradient: Gradient
var _far: ParallaxWall
var _near: ParallaxWall

var _from: Array[Color] = []
var _to: Array[Color] = []
var _tween: Tween


func _ready() -> void:
	_build_sky()

	_far = ParallaxWall.new()
	_far.scroll = 0.22
	_far.style = ParallaxWall.Style.FAR
	add_child(_far)

	_near = ParallaxWall.new()
	_near.scroll = 0.48
	_near.style = ParallaxWall.Style.NEAR
	add_child(_near)

	Game.plane_changed.connect(_on_plane_changed)
	_from = Palette.room(Game.plane)
	_to = _from
	_apply(1.0)


## Fits the room to a level. Must be called before the first frame of a load,
## or the walls flash at the previous level's size.
func configure(world_size: Vector2) -> void:
	var colours := Palette.room(Game.plane)
	_from = colours
	_to = colours
	_far.configure(world_size, colours[2])
	_near.configure(world_size, colours[3])
	_apply(1.0)


func sync(camera_position: Vector2) -> void:
	_far.sync(camera_position)
	_near.sync(camera_position)


func _build_sky() -> void:
	_gradient = Gradient.new()
	_gradient.offsets = PackedFloat32Array([0.0, 1.0])
	_gradient.colors = PackedColorArray([Palette.FRONT_SKY, Palette.FRONT_FLOOR])

	var texture := GradientTexture2D.new()
	texture.gradient = _gradient
	texture.width = 8 # A vertical ramp needs no horizontal resolution.
	texture.height = 256
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)

	var sky := TextureRect.new()
	sky.texture = texture
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Its own layer, below everything: keeps the sky from scrolling with the
	# world and out of reach of the `CanvasModulate` that darkens the playfield.
	var layer := CanvasLayer.new()
	layer.layer = -100
	layer.add_child(sky)
	add_child(layer)


func _on_plane_changed(plane: Planes.Kind) -> void:
	_from = _current()
	_to = Palette.room(plane)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_apply, 0.0, 1.0, RECOLOUR_TIME)


## The four colours currently on screen, read back off the live nodes so a flip
## interrupting a flip starts from where the last one had got to.
func _current() -> Array[Color]:
	if _far == null:
		return _from
	return [_gradient.colors[0], _gradient.colors[1], _far.tone, _near.tone]


func _apply(t: float) -> void:
	if _from.size() < 4 or _to.size() < 4:
		return
	_gradient.set_color(0, _from[0].lerp(_to[0], t))
	_gradient.set_color(1, _from[1].lerp(_to[1], t))
	_far.tone = _from[2].lerp(_to[2], t)
	_near.tone = _from[3].lerp(_to[3], t)
