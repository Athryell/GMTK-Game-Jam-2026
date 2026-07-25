@tool
## A level's root. It holds nothing but data and scenery: `main.gd` is what
## instantiates the player and frames the camera from this.
##
## CREATING A LEVEL
##   1. Duplicate `scenes/levels/level_01_wake_up.tscn`, rename it keeping the
##      numbered prefix (`level_07_xxx.tscn`) — play order follows the name.
##   2. Set `level_name` and `world_size` in the Inspector.
##   3. Place the `Spawn` Marker2D where the hourglass appears.
##   4. Drag instances of `scenes/entities/*.tscn` into the `Entities` node.
##   5. Run. The level is discovered automatically, nothing to register.
class_name Level
extends Node2D

## Name shown in the HUD.
@export var level_name := "Untitled"
## Playable extent. Bounds the camera; falling below it kills. Nothing stops
## `y` from exceeding one screen — the camera has always clamped both axes, so a
## tall level scrolls vertically with no code to add.
@export var world_size := Vector2(960.0, 540.0): set = _set_world_size

@export_group("Rules")
## How many chambers this level's glass has — which is also how many planes the
## level has, and how far a jump turns you: a third of a turn at three, a quarter
## at four.
##
## Two is the hourglass the game is built on and what every level shipped with.
## Raising it does not make the level faster: a chamber still opens half full
## against the same drain, so the runway before your first jump is the same. It
## makes the level WIDER — more places to be, and more places for sand to be
## stranded in.
@export_range(2, 4) var chambers := 2
## Sand the level starts you with, in ms. At 0 it takes `sand_start` from the
## tuning panel. Set it low and the level is played from the edge of death —
## which is the whole subject of "The Last Grain".
@export_range(0.0, 20000.0, 100.0) var sand_start_override := 0.0
## Grants one extra jump in mid-air, for this level only.
##
## On a two-chamber glass, two turns return you to your starting plane AND —
## since a turn just swaps the bulbs — to your starting sand exactly. So a
## double jump is pure height
## — free while you are full, ruinous while you are empty, the exact mirror of
## the single jump. That asymmetry needs no tuning; it falls out of the formula.
##
## It lives on the level rather than on the player so there is no persistent
## unlock to write, and so earlier levels stay untouched by construction.
@export var double_jump := false

@onready var spawn: Marker2D = $Spawn


func _set_world_size(value: Vector2) -> void:
	world_size = Vector2(maxf(value.x, 64.0), maxf(value.y, 64.0))
	queue_redraw()


func _draw() -> void:
	# Authoring guide only: shows the level bounds inside the editor.
	if not Engine.is_editor_hint():
		return
	draw_rect(Rect2(Vector2.ZERO, world_size), Color(1.0, 1.0, 1.0, 0.25), false, 2.0)
