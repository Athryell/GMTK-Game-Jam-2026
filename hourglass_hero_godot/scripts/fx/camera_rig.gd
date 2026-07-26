## The camera. Frames a level, follows the player, and shakes when hit.
##
## Vertically it tracks the last ground the player stood on, not `player.y`,
## which would bob on every jump. Two separate rules: the `camera_vertical_slack`
## window (feel, tunable) and `_leashed` (the guarantee that the player stays on
## screen, applied last). Keep them distinct.
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
	# Deliberately past the floor by the death margin: clamped exactly to the
	# world the player ends up pinned to the bottom bezel.
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


## The lowest world y currently on screen. What the backdrop plants its art
## against when the level's own ground is out of sight below.
func view_bottom() -> float:
	return global_position.y + _visible_size().y / 2.0


## Must stay on the physics clock: the player moves in `move_and_slide()`, and
## following on the render clock makes them judder against a still world. The
## camera is below the level in `main.tscn`, so the player has already moved by
## the time this runs.
func _physics_process(delta: float) -> void:
	var cfg := Tuning.cfg

	if target != null and is_instance_valid(target):
		if target.is_on_floor():
			_anchor_y = target.global_position.y
		else:
			# Airborne, the anchor is dragged rather than set: it only moves once
			# the player reaches an edge of the slack window.
			var slack := Tuning.cfg.camera_vertical_slack
			_anchor_y = clampf(_anchor_y,
				target.global_position.y - slack, target.global_position.y + slack)
		# Lead by facing direction, eased on its own clock so turning around
		# sweeps the view instead of snapping it.
		var want: float = signf(target.velocity.x) * cfg.camera_lead
		_lead = lerpf(_lead, want, 1.0 - exp(-cfg.camera_lead_speed * delta))

	var goal := _clamped(_raw_target())
	if cfg.camera_smoothing <= 0.0:
		global_position = goal
	else:
		global_position = global_position.lerp(
			goal, 1.0 - exp(-cfg.camera_smoothing * delta))
	global_position = _leashed(global_position)

	# Trauma decays linearly but is applied squared, so the tail dies away
	# instead of buzzing at low amplitude.
	_trauma = maxf(0.0, _trauma - delta / maxf(cfg.camera_shake_decay, 0.01))
	var amount := _trauma * _trauma * cfg.camera_shake_strength
	# A glass about to run out shakes the view for as long as it lasts, which is
	# why it is added here and not to `_trauma`, whose whole job is to decay.
	if Game.status == Game.Status.PLAY:
		var fear := Game.danger()
		amount += fear * fear * cfg.camera_danger_shake
	offset = Vector2(_rng.randf_range(-amount, amount), _rng.randf_range(-amount, amount))


## Adds to the shake, capped at 1. Additive so overlapping events stack.
func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func _raw_target() -> Vector2:
	if target == null or not is_instance_valid(target):
		return global_position
	# `_anchor_y` outright: the slack window is the whole vertical rule, and a
	# second clamp against the player here turns that window into a wall.
	return Vector2(target.global_position.x + _lead, _anchor_y)


## What the camera can show: the viewport divided by the zoom. Skipping the
## division is invisible at zoom 1 and wrong at every other zoom.
func _visible_size() -> Vector2:
	var z: float = maxf(zoom.x, 0.01)
	return get_viewport_rect().size / z


## Clamped against `limit_right` / `limit_bottom`, never against a separate copy
## of the world size — the padding applied to the limits in [method frame] has
## to survive here.
func _clamped(point: Vector2) -> Vector2:
	var half := _visible_size() / 2.0
	# On a level smaller than the view, centre it rather than hug an edge.
	return Vector2(
		clampf(point.x, half.x, maxf(limit_right - half.x, half.x)),
		clampf(point.y, half.y, maxf(limit_bottom - half.y, half.y)))


## The guarantee: the player is never further from the centre than the frame can
## show, less `camera_edge_margin`. Must be applied AFTER the smoothing, which
## otherwise lags far enough behind a spring launch to lose the player.
## Deliberately not re-clamped to the level limits afterwards — the leash only
## pulls towards the player, who is already inside them. Which is why the target
## is dropped on death: a dead player is not.
func _leashed(point: Vector2) -> Vector2:
	if target == null or not is_instance_valid(target):
		return point
	var reach := _visible_size() / 2.0 - Vector2.ONE * Tuning.cfg.camera_edge_margin
	var player := target.global_position
	return Vector2(
		clampf(point.x, player.x - maxf(reach.x, 0.0), player.x + maxf(reach.x, 0.0)),
		clampf(point.y, player.y - maxf(reach.y, 0.0), player.y + maxf(reach.y, 0.0)))


func _on_status_changed(status: Game.Status) -> void:
	if status == Game.Status.DEAD:
		add_trauma(0.85)
		# A dead glass keeps falling and nothing kills it a second time, so the
		# leash would drag the view thousands of px below the world. Nothing is
		# lost: it hides itself on the death frame, and the fragments stay put.
		target = null


func _on_flipped(from_pad: bool) -> void:
	add_trauma(0.16 if from_pad else 0.26)
