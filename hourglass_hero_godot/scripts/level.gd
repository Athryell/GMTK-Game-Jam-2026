@tool
## A level's root: data and scenery only. `main.gd` spawns the player and frames
## the camera from it. New levels are duplicated .tscn files in `scenes/levels/`,
## auto-discovered and played in filename order (`level_NN_*.tscn`).
class_name Level
extends Node2D

## Name shown in the HUD.
@export var level_name := "Untitled"
## Playable extent. Bounds the camera; falling below it kills. May exceed one
## screen on either axis — the camera clamps and scrolls.
@export var world_size := Vector2(960.0, 540.0): set = _set_world_size

@export_group("Rules")
## Sand the level starts you with, in ms. At 0 it falls back to `sand_start`.
@export_range(0.0, 20000.0, 100.0) var sand_start_override := 0.0
## Grants one extra mid-air jump, for this level only. Two flips restore both
## the starting plane and (since `flip_sand()` is `max - sand`) the exact sand.
@export var double_jump := false

@onready var spawn: Marker2D = $Spawn


func _set_world_size(value: Vector2) -> void:
	world_size = Vector2(maxf(value.x, 64.0), maxf(value.y, 64.0))
	queue_redraw()


func _draw() -> void:
	# Editor-only bounds guide.
	if not Engine.is_editor_hint():
		return
	draw_rect(Rect2(Vector2.ZERO, world_size), Color(1.0, 1.0, 1.0, 0.25), false, 2.0)
