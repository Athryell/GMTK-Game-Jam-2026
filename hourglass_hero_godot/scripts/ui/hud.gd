## HUD: the sand gauge, the level name, the current plane, and the death /
## level-clear / victory screens.
extends Control

## Centre of the sand gauge, in screen px. Editable on the HUD node in `hud.tscn`.
@export var gauge_centre := Vector2(52.0, 62.0)
## Drawn size of the gauge hourglass. It is the player's own glass, scaled up.
@export var gauge_size := Vector2(48.0, 72.0)

@onready var _level_label: Label = $LevelLabel
@onready var _plane_label: Label = $PlaneLabel
@onready var _overlay: Label = $Overlay
@onready var _hint: Label = $Hint


func _ready() -> void:
	Game.level_loaded.connect(_on_level_loaded)
	Game.status_changed.connect(_on_status_changed)
	Game.plane_changed.connect(_on_plane_changed)
	_on_status_changed(Game.status)
	_on_plane_changed(Game.plane)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	# Literally the player's own glass, drawn a second time at another size: same
	# tumble, same slosh, same trickle. Run right and the sand banks against the
	# left wall here exactly as it does down on the sprite.
	var motion := Glass.motion
	var colour := Palette.SAND_FULL.lerp(Palette.SAND_LOW, Game.danger())

	draw_set_transform(gauge_centre, motion.tilt, Vector2.ONE)
	HourglassShape.draw_glass(self, gauge_size, motion.chambers(), colour,
		motion.down(), motion.stream_phase, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# The gauge throbs when the sand runs low.
	if Game.danger() > 0.0:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 90.0)
		draw_arc(gauge_centre, gauge_size.y * 0.62, 0.0, TAU, 32,
			Color(Palette.SAND_LOW, 0.5 * pulse * Game.danger()), 2.0)


func _on_level_loaded(index: int, level_name: String) -> void:
	_level_label.text = "%d/%d — %s" % [index + 1, Game.level_scenes.size(), level_name]


func _on_plane_changed(plane: Planes.Kind) -> void:
	var front := plane == Planes.Kind.FRONT
	_plane_label.text = "FRONT" if front else "BACK"
	_plane_label.modulate = Palette.FRONT_SOLID if front else Palette.BACK_SOLID


func _on_status_changed(status: Game.Status) -> void:
	match status:
		Game.Status.PLAY:
			_overlay.text = ""
			_hint.text = "← → move    SPACE jump (flips the glass + swaps plane)    R restart    ESC menu    F1 tuning"
		Game.Status.DEAD:
			_overlay.text = "OUT OF SAND\n\nPress R to restart    ESC for the menu"
		Game.Status.LEVEL_CLEAR:
			_overlay.text = "LEVEL CLEAR"
		Game.Status.VICTORY:
			_overlay.text = "YOU MADE IT!\n\nPress R to play again    ESC for the menu"
