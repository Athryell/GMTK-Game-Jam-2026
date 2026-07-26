## The room behind the level: a painted sky and a stack of parallax cityscape
## layers, one set per background, swapped in as `configure` crosses into a new
## group of levels. Nothing here is collidable or authored — hand it a
## `world_size` and the current level index.
class_name Backdrop
extends Node2D

const BG_ROOT := "res://art/bg"
## How many levels share one background before the next takes over.
const LEVELS_PER_BACKGROUND := 4

## How many world px one of the painted layers' art px covers. The backdrop is
## the ONE place in the game that is not 1.0: at 1.0 the 576×324 art left bare
## sky above a strip of city and repeated twice within one screen.
##
## It must stay a WHOLE number — at anything fractional the doubled texels
## straddle world pixels and the 1-px trusses tear as the parallax slides.
## Nothing outside `BackdropLayer` may read it.
const ART_SCALE := 2.0

## How far below the ground line the art is planted, in px. Covers the bare sky
## the camera's `fall_death_margin` overscan would otherwise show under the
## floor.
const ART_DROP := 28.0

## Parallax speed of the nearest layer; the farthest sits at the opposite end,
## with any layers between graded evenly across the range. The whole range sits
## far under the world's own speed: the slower a layer answers the camera, the
## further off it reads.
const FAR_SCROLL := 0.05
const NEAR_SCROLL := 0.26

## Alpha of the fog-coloured veil each layer draws over its own art. The veils
## stack — the farthest layer is seen through all of them, the nearest only
## through its own — which is what separates silhouettes painted from the same
## eleven colours.
const FOG_FAR := 0.48
const FOG_NEAR := 0.30

## Fraction of a layer's fog left at the top of the art: haze piles up along the
## ground, so a distant roofline still cuts the sky.
const FOG_TOP := 0.45

const FOG_FALLBACK := Color(0.62, 0.66, 0.76)

## How fast the art tracks the camera VERTICALLY. One rate for every depth, not
## a graded range like the horizontal one: separate rates slide the layers apart
## and tear the skyline open at the rooflines where they overlap.
const VERTICAL_SCROLL := 0.10

var _sky: TextureRect
var _layers: Array[BackdropLayer] = []
var _background_index := -1


## Pushed below zero so there is a rung between the room and the level for things
## that have to sink INTO the world without falling out the back of it — the
## cannon's barrel is the first. Being earlier in `main.tscn` is not enough on its
## own: any negative `z_index` in the level would otherwise land behind the city.
const DEPTH := -2


func _ready() -> void:
	z_index = DEPTH
	_build_sky()


## Fits the room to a level, swapping in the art of `group` — the level's theme —
## whenever it differs from the one already up. `view_bottom` is the lowest world
## y the opening frame shows.
func configure(level: Level, group: int, view_bottom: float) -> void:
	var index := _background_index_for_group(group)
	if index != _background_index:
		_background_index = index
		_rebuild_layers(index)
	var floor_y := anchor(_terrain_bottom(level), view_bottom)
	for layer in _layers:
		layer.configure(level.world_size, floor_y)


## Where the art's bottom edge belongs, in world space. On the ground, unless the
## level opens far above its own floor — a well entered from the top — where the
## ground is hundreds of px below the view and anchoring to it plays the whole
## descent against bare sky. The skyline stands on the bottom of the opening
## frame instead, and the vertical parallax carries it down from there.
static func anchor(ground_bottom: float, view_bottom: float) -> float:
	return minf(ground_bottom, view_bottom) + ART_DROP


## Held still while the level is not being played: dying drops the camera to the
## bottom of the level, and letting the parallax answer drags the whole skyline
## down. The reload re-latches the datum.
func sync(camera_position: Vector2) -> void:
	if Game.status != Game.Status.PLAY:
		return
	for layer in _layers:
		layer.sync(camera_position)


## The lowest point of the level's ground, in world space. Falls back to
## `world_size.y` for a level with no `Terrain` (built entirely of floating
## `Platform`s), which has no single ground to align to.
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


## Full-viewport, in its own layer below everything: keeps the sky pinned to the
## screen and out of reach of the `CanvasModulate` that darkens the playfield.
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


## The theme a level falls in from its rank alone, UNCLAMPED — what a level that
## picked no theme of its own gets. Public because the theme is what the place
## is: the brick the level is built from and the music it plays are grouped by
## this too, so all three change on the same level or none of them do.
static func group_for_level(level_index: int) -> int:
	@warning_ignore("integer_division") # Grouping, not measurement — the floor is the point.
	return level_index / LEVELS_PER_BACKGROUND


func _background_index_for_group(group: int) -> int:
	var count := _count_backgrounds()
	if count <= 0:
		return -1
	return clampi(group, 0, count - 1)


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

	var textures := load_layer_textures("%s/background %d" % [BG_ROOT, index + 1])
	if textures.is_empty():
		_sky.texture = null
		return

	_sky.texture = textures[0]
	var fog := fog_colour(textures[0])
	var depth_count := textures.size() - 1
	for i in range(1, textures.size()):
		var t := float(i - 1) / float(maxi(depth_count - 1, 1))
		var layer := BackdropLayer.new()
		layer.texture = textures[i]
		layer.scroll = lerpf(FAR_SCROLL, NEAR_SCROLL, t)
		layer.fog = fog
		layer.fog_alpha = lerpf(FOG_FAR, FOG_NEAR, t)
		add_child(layer)
		_layers.append(layer)


## The colour the distance dissolves into, read off this background's own sky so
## each one hazes towards its own horizon rather than towards a grey the art
## never uses. Static and public: the menu stands in one of these rooms too.
static func fog_colour(sky: Texture2D) -> Color:
	var image := sky.get_image()
	if image == null:
		return FOG_FALLBACK
	if image.is_compressed():
		image.decompress()
	var width := image.get_width()
	var height := image.get_height()
	if width <= 0 or height <= 0:
		return FOG_FALLBACK
	# The bottom row only: the band the skyline actually stands against.
	var total := Color(0.0, 0.0, 0.0)
	for x in width:
		total += image.get_pixel(x, height - 1)
	return Color(total.r / width, total.g / width, total.b / width)


## The numbered layer files in a background folder (`1.png`, `2.png`, …),
## sorted so index 0 is the sky and the rest run far to near. `orig.png` /
## `origbig.png` are reference composites, not layers, and are skipped.
static func load_layer_textures(dir_path: String) -> Array[Texture2D]:
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
