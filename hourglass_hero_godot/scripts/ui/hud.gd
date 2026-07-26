## HUD: the sand gauge, the level name, and the victory screen.
extends Control

## Centre of the sand gauge, in screen px. Editable on `Root` in `hud.tscn`.
@export var gauge_centre := Vector2(52.0, 62.0)
## Drawn size of the gauge hourglass. [constant HourglassSprite.TRIM]'s size, so
## the HUD glass is drawn one art px to one px of the 960×540 design canvas —
## which at `camera_zoom` 1.0 is the same size a pixel comes out in the world.
@export var gauge_size := Vector2(32.0, 60.0)

## The bar along the bottom. A level that has taken the jump away must not go on
## advertising it.
const HINT_FULL := "← → move    SPACE jump (turns the glass + moves you on)    R restart    ESC menu    F1 tuning"
const HINT_NO_JUMP := "← → move    R restart    ESC menu    F1 tuning"

## The bloom around the gauge while a feather's jump is in hand.
const CHARGED_GLOW_RADIUS := 46.0
const CHARGED_GLOW_ALPHA := 0.45

@onready var _level_label: Label = $LevelLabel
@onready var _overlay: Label = $Overlay
@onready var _hint: Label = $Hint

var _glow: Glow


func _ready() -> void:
	# Per-node rather than a project default; see `terrain.gd`.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_glow = Glow.halo(Palette.SAND_CHARGED, CHARGED_GLOW_RADIUS, CHARGED_GLOW_ALPHA)
	_glow.position = gauge_centre
	add_child(_glow)
	Game.level_loaded.connect(_on_level_loaded)
	Game.status_changed.connect(_on_status_changed)
	_on_status_changed(Game.status)


func _process(_delta: float) -> void:
	_glow.visible = Game.feathered
	queue_redraw()


func _draw() -> void:
	var motion := Glass.motion
	var colour := Palette.sand(Game.danger(), Game.feathered)

	var tilt := motion.sprite_tilt()
	# Turned left-for-right through the same quarter of a turn as the player's
	# glass, to keep the light down its left side; see `hourglass_visual.gd`.
	var facing := -1.0 if cos(tilt) < 0.0 else 1.0
	var down := motion.sprite_down()
	if facing < 0.0:
		down.x = -down.x
	draw_set_transform(gauge_centre, tilt, Vector2(facing, 1.0))
	HourglassSprite.draw(self, gauge_size, motion.sprite_fills(), colour,
		down, motion.invert(), Game.flip_anim > 0.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if Game.danger() > 0.0:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 90.0)
		draw_arc(gauge_centre, gauge_size.y * 0.62, 0.0, TAU, 32,
			Color(Palette.SAND_LOW, 0.5 * pulse * Game.danger()), 2.0)


func _on_level_loaded(index: int, level_name: String) -> void:
	_level_label.text = "%d/%d — %s" % [index + 1, Game.level_scenes.size(), level_name]
	# Emitted after the level's rules are applied, so the jump lock is settled.
	_hint.text = HINT_FULL if Game.jump_enabled else HINT_NO_JUMP


func _on_status_changed(status: Game.Status) -> void:
	match status:
		Game.Status.PLAY:
			_overlay.text = ""
		# No banner: both states resolve on their own within a second.
		Game.Status.DEAD, Game.Status.LEVEL_CLEAR:
			_overlay.text = ""
		Game.Status.VICTORY:
			_overlay.text = "YOU MADE IT!\n\nPress R to play again    ESC for the menu"
