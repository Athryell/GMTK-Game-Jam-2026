## The camera. Frames a level, follows the player, and shakes when hit.
##
## Lifted out of `main.gd`, which had grown a conductor's job plus a
## cinematographer's. The two never shared a variable, and only one of them
## needs to know what a trauma curve is.
##
## THE VERTICAL PROBLEM. Every jump in this game is also a flip, so the player
## is airborne constantly. A camera that tracks `player.y` bobs on every single
## input and makes the game unreadable. So it tracks the last GROUND the player
## stood on, and only lets the view drift from it by `vertical_slack` — a jump
## nudges the frame, a climb moves it. That is the whole trick, and it is why
## "Ten" (climbing) and "The Well" (descending) both read without either being
## special-cased.
class_name CameraRig
extends Camera2D

## Who to follow. Set by `main.gd` after it spawns the player.
var target: Player

var _trauma := 0.0
var _lead := 0.0
var _anchor_y := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	Game.status_changed.connect(_on_status_changed)
	Game.flipped.connect(_on_flipped)


## Fits the camera to a level. Call before the first frame: it sets the zoom the
## limits are derived from.
func frame(world_size: Vector2) -> void:
	var z: float = maxf(Tuning.cfg.camera_zoom, 0.1)
	zoom = Vector2(z, z)

	var visible := _visible_size()
	limit_left = 0
	limit_top = 0
	limit_right = int(maxf(world_size.x, visible.x))
	# Past the floor by the death margin, on purpose. Clamped exactly to the
	# world, the camera bottoms out with the player at ~85% of screen height —
	# standing on the floor you are pressed against the bottom bezel with a
	# third of a screen of empty sky above you. The extra room lets the frame
	# drop until the player sits around two thirds down, where a platformer
	# belongs, and the only thing it reveals is the pit that kills you.
	limit_bottom = int(maxf(world_size.y + Tuning.cfg.fall_death_margin, visible.y))
	_trauma = 0.0
	_lead = 0.0


## Jumps straight to where the camera belongs, with no easing and no shake.
func snap() -> void:
	if target != null and is_instance_valid(target):
		_anchor_y = target.global_position.y
	global_position = _clamped(_raw_target())
	offset = Vector2.ZERO
	reset_smoothing()


func _process(delta: float) -> void:
	var cfg := Tuning.cfg

	if target != null and is_instance_valid(target):
		if target.is_on_floor():
			_anchor_y = target.global_position.y
		# Lead the player by where they are going, not by where they are. Eased
		# on its own clock so that turning around sweeps the view across
		# instead of snapping it.
		var want: float = signf(target.velocity.x) * cfg.camera_lead
		_lead = lerpf(_lead, want, 1.0 - exp(-cfg.camera_lead_speed * delta))

	var goal := _clamped(_raw_target())
	if cfg.camera_smoothing <= 0.0:
		global_position = goal
	else:
		global_position = global_position.lerp(
			goal, 1.0 - exp(-cfg.camera_smoothing * delta))

	# Trauma decays linearly but is applied squared: a hard hit reads as a hard
	# hit, and the tail dies away instead of buzzing at low amplitude.
	_trauma = maxf(0.0, _trauma - delta / maxf(cfg.camera_shake_decay, 0.01))
	var amount := _trauma * _trauma * cfg.camera_shake_strength
	offset = Vector2(_rng.randf_range(-amount, amount), _rng.randf_range(-amount, amount))


## Adds to the shake, capped at 1. Additive rather than assigned so a death
## during a flip does not come out gentler than a death on its own.
func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func _raw_target() -> Vector2:
	if target == null or not is_instance_valid(target):
		return global_position
	var slack := Tuning.cfg.camera_vertical_slack
	return Vector2(
		target.global_position.x + _lead,
		clampf(target.global_position.y, _anchor_y - slack, _anchor_y + slack))


## What the camera can actually show, which is the viewport divided by the zoom.
## Getting this wrong is invisible at zoom 1 and wrong everywhere else: the
## limits would be computed for a view twice the size of the real one, and every
## level smaller than the screen would sit off-centre.
func _visible_size() -> Vector2:
	var z: float = maxf(zoom.x, 0.01)
	return get_viewport_rect().size / z


## Clamped against `limit_right` / `limit_bottom` rather than against a stored
## copy of the world size. Keeping both was one edge described in two places,
## and they disagreed: padding the limits past the floor did nothing because
## this function was still clamping to the floor itself.
func _clamped(point: Vector2) -> Vector2:
	var half := _visible_size() / 2.0
	# On a level smaller than the view, centre it rather than hug an edge.
	return Vector2(
		clampf(point.x, half.x, maxf(limit_right - half.x, half.x)),
		clampf(point.y, half.y, maxf(limit_bottom - half.y, half.y)))


func _on_status_changed(status: Game.Status) -> void:
	if status == Game.Status.DEAD:
		add_trauma(0.85)


func _on_flipped(from_pad: bool) -> void:
	add_trauma(0.16 if from_pad else 0.26)
