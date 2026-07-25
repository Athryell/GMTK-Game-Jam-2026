## The player — an hourglass.
##
## Signature mechanic: a jump does THREE things at once.
##   1. It flips the hourglass (the drained sand comes back: a refuel).
##   2. It swaps the plane (front ⇄ back), at an identical (x, y).
##   3. It launches you upwards.
##
## The consequence: you can only refuel by NET-changing plane. The two
## exceptions are the spring (jump without flip) and the flip-pad (flip without
## jump).
class_name Player
extends CharacterBody2D

## Depth past which you have fallen out of the level. Filled in by `main.gd`
## from the loaded level's size.
var death_y := 10000.0

var _coyote := 0.0
var _buffer := 0.0
## True while rising from a jump; gates the variable-height cut.
var _jumping := false
## Jumps left in mid-air. Refilled on landing, and only ever above zero on a
## level whose `double_jump` is on.
var _air_jumps := 0


func _ready() -> void:
	collision_layer = Layers.PLAYER
	collision_mask = Layers.SOLID


func _physics_process(delta: float) -> void:
	var cfg := Tuning.cfg

	# Hand the glass our travel speed so the sand can slosh with us — both the
	# sprite and the HUD gauge read it. Sampled here, at the top, because this
	# still holds the speed *after* last frame's `move_and_slide`: run into a
	# wall and it reads zero, so the sand pitches forward the way it should.
	Glass.travel = velocity.x

	if Game.status != Game.Status.PLAY:
		# Dead or level cleared: freeze, but keep gravity pinning us down so
		# the final pose stays believable.
		velocity.x = 0.0
		velocity.y = minf(velocity.y + cfg.gravity * delta, cfg.max_fall_speed)
		move_and_slide()
		return

	velocity.x = Input.get_axis("move_left", "move_right") * cfg.move_speed

	# Coyote time: you can still jump for a moment after leaving a ledge.
	# Jump buffer: a jump pressed too early fires on landing.
	_coyote = cfg.coyote_time if is_on_floor() else maxf(0.0, _coyote - delta)
	_buffer = cfg.jump_buffer if Input.is_action_just_pressed("jump") \
		else maxf(0.0, _buffer - delta)

	if _buffer > 0.0 and _coyote > 0.0:
		_jump()
	elif _air_jumps > 0 and Input.is_action_just_pressed("jump"):
		# Deliberately keyed to the press itself, not to `_buffer`: a buffered
		# jump that missed the ground would otherwise be spent in the air the
		# instant it was pressed, which is not what the player asked for.
		#
		# This is a second real flip, so it undoes the first — same plane, same
		# sand, pure height. Double-jump while nearly empty and you throw away
		# the refuel you just earned, which is exactly the trap level 10 is
		# built around. No special case here makes that happen; `max - sand`
		# applied twice does.
		_air_jumps -= 1
		_jump()

	velocity.y += cfg.gravity * delta
	# Variable jump height: releasing early clips the rise.
	if _jumping and not Input.is_action_pressed("jump") and velocity.y < 0.0:
		velocity.y = maxf(velocity.y, -cfg.jump_cut_velocity)
	velocity.y = minf(velocity.y, cfg.max_fall_speed)

	move_and_slide()

	if is_on_floor():
		_jumping = false
		_air_jumps = 1 if Game.double_jump else 0

	if global_position.y > death_y:
		Game.kill()


func _jump() -> void:
	_buffer = 0.0
	_coyote = 0.0
	_jumping = true
	velocity.y = -Tuning.cfg.jump_velocity
	Game.jump_flip(velocity.x)


## Launched by a spring: height, but no flip and no plane change. The height is
## fixed, so no variable-height cut applies.
func bounce(power: float) -> void:
	velocity.y = -power
	_jumping = false
	_coyote = 0.0
	# A spring hands back your air jump: it is a launch, not a jump you spent.
	_air_jumps = 1 if Game.double_jump else 0
