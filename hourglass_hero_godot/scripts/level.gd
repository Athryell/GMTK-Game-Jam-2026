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
## How many chambers this level's glass has — also how many planes it has, and
## how far a jump turns you. Raising it does not make the level faster: a chamber
## still opens against the same drain. It makes the level wider, with more places
## for sand to be stranded in.
@export_range(2, 4) var chambers := 2
## Sand the level starts you with, in ms. At 0 it falls back to `sand_start`.
@export_range(0.0, 20000.0, 100.0) var sand_start_override := 0.0
## Grants one extra mid-air jump, for this level only. On a two-chamber glass two
## turns restore both the starting plane and the exact sand, so the double jump
## is pure height — free while you are full, ruinous while you are empty.
@export var double_jump := false
## Holds the sand until the player first steers, so a level with something to say
## can say it before anything is at stake.
@export var clock_starts_on_move := false
## Takes the jump away for the first life only; the death hands it back. Walking
## straight ahead until you run dry is a lesson no sentence teaches.
@export var jump_locked_first_life := false

@onready var spawn: Marker2D = $Spawn


func _set_world_size(value: Vector2) -> void:
	world_size = Vector2(maxf(value.x, 64.0), maxf(value.y, 64.0))
	queue_redraw()


func _draw() -> void:
	# Editor-only bounds guide.
	if not Engine.is_editor_hint():
		return
	draw_rect(Rect2(Vector2.ZERO, world_size), Color(1.0, 1.0, 1.0, 0.25), false, 2.0)
