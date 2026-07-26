@tool
## A level's root: data and scenery only. `main.gd` spawns the player and frames
## the camera from it. New levels are duplicated .tscn files in `scenes/levels/`,
## auto-discovered and played in filename order (`level_NN_*.tscn`).
class_name Level
extends Node2D

## Name shown in the HUD. Renaming the .tscn renames the level.
var level_name: String: get = _get_level_name
## Playable extent. Bounds the camera; falling below it kills. May exceed one
## screen on either axis — the camera clamps and scrolls.
@export var world_size := Vector2(960.0, 540.0): set = _set_world_size

@export_group("Look")
## The place this level is in: skyline, brick tint and music, which always
## change together. Left to the order, it is five levels to a theme.
@export_enum("From the level order:-1", "Theme 1:0", "Theme 2:1", "Theme 3:2",
	"Theme 4:3") var theme := -1: set = _set_theme

@export_group("Rules")
## How many chambers this level's glass has — also how many planes, and how far a
## jump turns you. Raising it does not make the level faster: a chamber still
## opens against the same drain, so it only strands sand in more places.
@export_range(2, 4) var chambers := 2
## Sand the level starts you with, in ms. At 0 it falls back to `sand_start`.
@export_range(0.0, 20000.0, 100.0) var sand_start_override := 0.0
## Holds the sand until the player first steers, so a level with something to say
## can say it before anything is at stake.
@export var clock_starts_on_move := false
## Takes the jump away for the first life only; the death hands it back.
@export var jump_locked_first_life := false
## Keeps the level off the run clock and the run's death toll. A level that
## teaches by killing you must not charge the run for the lesson.
@export var counts_towards_run := true

@onready var spawn: Marker2D = $Spawn


func _get_level_name() -> String:
	return title_from_path(scene_file_path)


## "res://scenes/levels/level_04_the_spring.tscn" -> 4. An unnumbered scene
## comes out high so it sorts after every numbered one rather than before.
static func number_from_path(path: String) -> int:
	for word in path.get_file().get_basename().split("_", false):
		if word.is_valid_int():
			return word.to_int()
	return 1 << 30


## "res://scenes/levels/level_04_the_spring.tscn" -> "The Spring".
static func title_from_path(path: String) -> String:
	var stem := path.get_file().get_basename()
	var words := PackedStringArray()
	for word in stem.split("_", false):
		if word == "level" or word.is_valid_int():
			continue
		words.append(word.capitalize())
	return " ".join(words) if not words.is_empty() else stem


func theme_group(level_index: int) -> int:
	return theme if theme >= 0 else Backdrop.group_for_level(level_index)


## The theme of the level a piece of scenery sits in. Scenery is `owner`ed by the
## level root in the editor and once instantiated alike; a node with no level
## over it — a test scene — falls back to the level order.
static func group_of(node: Node) -> int:
	var index := 0 if Engine.is_editor_hint() else Game.level_index
	var level := node.owner as Level
	return level.theme_group(index) if level != null else Backdrop.group_for_level(index)


## The scenery paints itself from the theme, so it all has to be told.
func _set_theme(value: int) -> void:
	theme = value
	if not Engine.is_editor_hint():
		return
	for node in find_children("*", "CanvasItem", true, false):
		(node as CanvasItem).queue_redraw()


func _set_world_size(value: Vector2) -> void:
	world_size = Vector2(maxf(value.x, 64.0), maxf(value.y, 64.0))
	queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_rect(Rect2(Vector2.ZERO, world_size), Color(1.0, 1.0, 1.0, 0.25), false, 2.0)
