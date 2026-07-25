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
## Playable extent. Bounds the camera; falling below it kills.
@export var world_size := Vector2(960.0, 540.0): set = _set_world_size

@onready var spawn: Marker2D = $Spawn


func _set_world_size(value: Vector2) -> void:
	world_size = Vector2(maxf(value.x, 64.0), maxf(value.y, 64.0))
	queue_redraw()


func _draw() -> void:
	# Authoring guide only: shows the level bounds inside the editor.
	if not Engine.is_editor_hint():
		return
	draw_rect(Rect2(Vector2.ZERO, world_size), Color(1.0, 1.0, 1.0, 0.25), false, 2.0)
