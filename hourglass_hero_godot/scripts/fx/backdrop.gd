## The room behind the level: a painted sky and a stack of parallax cityscape
## layers, one set per background, swapped in as `configure` crosses into a new
## group of levels. Nothing here is collidable or authored — hand it a
## `world_size` and the current level index.
class_name Backdrop
extends Node2D

const BG_ROOT := "res://art/bg"
## How many levels share one background before the next takes over.
const LEVELS_PER_BACKGROUND := 4

## The painted layers are exported at 576×324 and drawn one art px to one world
## px, like every other texture in the game — that single rule is what keeps a
## pixel the same size whether it lands on a brick, the glass or the skyline.
##
## Nothing else may read this: it is here so the rule has a name, not so the
## backdrop can be sized independently. At 1.0 the art is narrower than the
## 960 px view, so `BackdropLayer` tiles it sideways to cover the level.
const ART_SCALE := 1.0

## How far below the ground line the art is planted, in px. A little overlap
## reads better than a butt joint, and it covers the bare sky the camera's
## `fall_death_margin` overscan would otherwise show under the floor.
const ART_DROP := 28.0

## Parallax speed of the nearest layer; the farthest sits at the opposite end,
## with any layers between graded evenly across the range.
const FAR_SCROLL := 0.12
const NEAR_SCROLL := 0.55

## How fast the art tracks the camera VERTICALLY, as a fraction of the world's
## own speed — kept under even the slowest horizontal rate on purpose, so
## climbing a level only stirs the skyline where walking along one sweeps it.
##
## One rate for every depth, not a graded range like the horizontal one. Depth
## already reads from the sideways motion, and giving each layer its own
## vertical rate would slide them apart and tear the skyline open at the
## rooflines where they overlap.
const VERTICAL_SCROLL := 0.10

var _sky: TextureRect
var _layers: Array[BackdropLayer] = []
var _background_index := -1


func _ready() -> void:
	_build_sky()


## Fits the room to a level, swapping in a new background's art the moment
## `level_index` crosses into the next group of `LEVELS_PER_BACKGROUND`.
func configure(level: Level, level_index: int) -> void:
	var index := _background_index_for_level(level_index)
	if index != _background_index:
		_background_index = index
		_rebuild_layers(index)
	var floor_y := _terrain_bottom(level) + ART_DROP
	for layer in _layers:
		layer.configure(level.world_size, floor_y)


## Held still while the level is not being played. Dying drops the camera with
## the falling player, all the way to the bottom of the level, and letting the
## parallax answer that drags the whole skyline down through a moment the player
## has no control over. The reload re-latches the datum, so nothing has to be
## restored when play resumes.
func sync(camera_position: Vector2) -> void:
	if Game.status != Game.Status.PLAY:
		return
	for layer in _layers:
		layer.sync(camera_position)


## The lowest point of the level's ground, in world space — where the art's
## bottom edge belongs. Falls back to `world_size.y` for a level with no
## `Terrain` (built entirely of floating `Platform`s), which has no single
## ground to align to.
func _terrain_bottom(level: Level) -> float:
	var grounds := level.find_children("*", "Terrain", true, false)
	if grounds.is_empty():
		return level.world_size.y
	var bottom := -INF
	for node in grounds:
		var ground := node as Terrain
		for point in ground.shadow_outline():
			bottom = maxf(bottom, (ground.global_transform * point).y)
	return bottom


## Full-viewport, in its own layer below everything: keeps the sky pinned to
## the screen (never scrolling with the world) and out of reach of the
## `CanvasModulate` that darkens the playfield.
func _build_sky() -> void:
	_sky = TextureRect.new()
	_sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sky.stretch_mode = TextureRect.STRETCH_SCALE
	_sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var layer := CanvasLayer.new()
	layer.layer = -100
	layer.add_child(_sky)
	add_child(layer)


func _background_index_for_level(level_index: int) -> int:
	var count := _count_backgrounds()
	if count <= 0:
		return -1
	@warning_ignore("integer_division") # Grouping, not measurement — the floor is the point.
	return clampi(level_index / LEVELS_PER_BACKGROUND, 0, count - 1)


## How many "background N" folders exist under `BG_ROOT`.
func _count_backgrounds() -> int:
	var dir := DirAccess.open(BG_ROOT)
	if dir == null:
		return 0
	var count := 0
	for dir_name in dir.get_directories():
		if dir_name.begins_with("background "):
			count += 1
	return count


func _rebuild_layers(index: int) -> void:
	for layer in _layers:
		layer.queue_free()
	_layers.clear()

	if index < 0:
		_sky.texture = null
		return

	var textures := _load_layer_textures("%s/background %d" % [BG_ROOT, index + 1])
	if textures.is_empty():
		_sky.texture = null
		return

	_sky.texture = textures[0]
	var depth_count := textures.size() - 1
	for i in range(1, textures.size()):
		var t := float(i - 1) / float(maxi(depth_count - 1, 1))
		var layer := BackdropLayer.new()
		layer.texture = textures[i]
		layer.scroll = lerpf(FAR_SCROLL, NEAR_SCROLL, t)
		add_child(layer)
		_layers.append(layer)


## The numbered layer files in a background folder (`1.png`, `2.png`, …),
## sorted so index 0 is the sky and the rest run far to near. `orig.png` /
## `origbig.png` are reference composites, not layers, and are skipped.
func _load_layer_textures(dir_path: String) -> Array[Texture2D]:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("No background art found at %s" % dir_path)
		return []

	var names: Array[String] = []
	for file in dir.get_files():
		# In an exported build, files are remapped to `<name>.remap`.
		var clean := file.trim_suffix(".remap")
		if clean.get_extension() == "png" and clean.get_basename().is_valid_int():
			names.append(clean)
	names.sort_custom(func(a, b): return a.get_basename().to_int() < b.get_basename().to_int())

	var textures: Array[Texture2D] = []
	for n in names:
		var tex := load(dir_path.path_join(n)) as Texture2D
		if tex != null:
			textures.append(tex)
	return textures
