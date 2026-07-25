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
##
## The slack is a WINDOW, not a wall. Read literally it was a wall: the goal
## stopped dead at the edge of the slack, so a spring — which launches 445 px,
## more than three times a jump — carried the player clean out of the frame and
## left them there. Measured, that was 350 px off centre in a 348 px view.
##
## Two rules keep that from happening again, and they are deliberately different
## in kind. The window is the FEEL: it is what the player is pushing against,
## and it moves only when they push it. The leash is the GUARANTEE: applied
## last, after easing and clamping, it is the promise that whatever the physics
## does, the player stays on screen. Feel is tunable, the guarantee is not
## negotiable, so they must not be the same mechanism.
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


## On the PHYSICS clock, not the render clock, and this is not a preference.
##
## The player is moved by `move_and_slide()` at 60 Hz. A camera that followed in
## `_process` advanced on a different clock, so on some frames the view had
## moved and the player had not — at `move_speed` that is ±4 px of alternating
## displacement, and since everything else in the world is stationary relative
## to the camera, the player alone smeared into a double image whenever the
## camera was moving.
##
## The camera is below the level in `main.tscn`, so within a tick the player has
## already been moved by the time this runs.
func _physics_process(delta: float) -> void:
	var cfg := Tuning.cfg

	if target != null and is_instance_valid(target):
		if target.is_on_floor():
			_anchor_y = target.global_position.y
		else:
			# Airborne, the window is dragged rather than set: it stays put while
			# the player moves inside it, and travels only once they reach an
			# edge. A jump lives inside the window and moves nothing; a spring or
			# a long drop pushes it, and the view goes along.
			var slack := Tuning.cfg.camera_vertical_slack
			_anchor_y = clampf(_anchor_y,
				target.global_position.y - slack, target.global_position.y + slack)
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
	global_position = _leashed(global_position)

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
	# `_anchor_y` outright, with no second clamp against the player: the window
	# is already the whole vertical rule, and clamping the player into it here as
	# well was what made the slack behave as a wall.
	return Vector2(target.global_position.x + _lead, _anchor_y)


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


## The guarantee: the player is never further from the centre than the frame can
## show, less `camera_edge_margin` so they are never welded to the bezel either.
##
## Applied AFTER the easing, which is the entire point. Smoothing exists to make
## the view feel unhurried, and an unhurried view loses a 1400 px/s launch — at
## `camera_smoothing` 7 that is 200 px of lag on its own, before any slack. So
## the easing is allowed to fall behind, and this catches it. During the fast
## part of a launch the camera is dragged rigidly; the moment the player slows,
## the leash goes loose and the easing has the frame back.
##
## Not clamped against the level limits afterwards: `_clamped` already put the
## goal inside them, and the leash only ever pulls TOWARDS the player, who is
## inside the level. Re-clamping here would silently reinstate the bug at the
## top of a level, where being on screen matters most.
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


func _on_flipped(from_pad: bool) -> void:
	add_trauma(0.16 if from_pad else 0.26)
