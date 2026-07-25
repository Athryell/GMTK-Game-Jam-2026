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

## The light the glass gives off. Its brightness IS the sand: the room closes in
## around you as the clock runs down, so "how long have I got" is answerable
## without ever looking at the gauge.
var _light: PointLight2D
var _pulse := 0.0

## Below this much danger the glass is nervous but dry. Set so the sweat starts
## noticeably AFTER the light has already begun to redden — two cues arriving
## together read as one, and the point of the second is that things got worse.
const SWEAT_FROM := 0.4
## Seconds between beads at `SWEAT_FROM` and at bone dry.
const SWEAT_SLOWEST := 0.34
const SWEAT_FASTEST := 0.09

var _sweat_timer := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	collision_layer = Layers.PLAYER
	collision_mask = Layers.SOLID
	_light = LightKit.point(Palette.SAND_FULL, Tuning.cfg.player_light_radius,
		Tuning.cfg.player_light_energy)
	add_child(_light)
	Game.flipped.connect(_on_flipped)
	Game.status_changed.connect(_on_status_changed)


func _process(delta: float) -> void:
	_pulse += delta
	var cfg := Tuning.cfg
	var danger := Game.danger()
	var fuel: float = clampf(Game.sand / maxf(cfg.sand_max, 1.0), 0.0, 1.0)
	# Never all the way out. A light that reaches zero is not tension, it is a
	# player who cannot see the platform they are about to miss.
	var throb := 1.0 + 0.14 * sin(_pulse * 13.0) * danger
	_light.color = Palette.SAND_FULL.lerp(Palette.SAND_LOW, danger)
	_light.energy = cfg.player_light_energy * (0.42 + 0.58 * fuel) * throb
	_light.texture_scale = cfg.player_light_radius * 2.0 / LightKit.TEXTURE_SIZE
	_sweat(delta, danger)


## Beads shaken off the glass as the sand runs out, faster the closer it gets.
##
## Driven off the same `danger()` as the tremble and the light, so all three
## arrive as one rising state rather than as three effects with their own ideas
## about when things are bad.
func _sweat(delta: float, danger: float) -> void:
	if Game.status != Game.Status.PLAY or danger < SWEAT_FROM:
		# Reset rather than pause: refuel and the next bead should wait its turn,
		# not fire the instant you drop back into the warning.
		_sweat_timer = 0.0
		return

	_sweat_timer -= delta
	if _sweat_timer > 0.0:
		return
	var urgency := inverse_lerp(SWEAT_FROM, 1.0, danger)
	_sweat_timer = lerpf(SWEAT_SLOWEST, SWEAT_FASTEST, urgency)
	# Off the shoulders of the glass, never dead centre: a bead leaving from the
	# middle of the sprite looks like it came out of the sand rather than off it.
	var from := global_position + Vector2(
		_rng.randf_range(-11.0, 11.0), _rng.randf_range(-15.0, -4.0))
	Burst.sweat(get_parent(), from, Palette.GLASS)


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

	var was_airborne := not is_on_floor()
	var impact := velocity.y
	move_and_slide()

	if is_on_floor():
		if was_airborne:
			_land(impact)
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


# ----- Presentation ----------------------------------------------------------
# Effects are spawned into the LEVEL, not onto the player. A burst parented here
# would be dragged along by the thing that made it — dust would follow you off
# the ledge — and would be freed with the player on a restart, mid-animation.

func _land(impact_speed: float) -> void:
	var force := clampf(impact_speed / maxf(Tuning.cfg.max_fall_speed, 1.0) * 2.4, 0.0, 1.0)
	if force < 0.08:
		return
	Burst.dust(get_parent(), global_position + Vector2(0.0, 19.0),
		Palette.solid(Planes.Kind.BOTH, Game.plane), force)


## The plane swap, in the colour of the plane you have just arrived in — the
## ring is the clearest read of "which side am I on now" in the whole game.
func _on_flipped(_from_pad: bool) -> void:
	Burst.ring(get_parent(), global_position,
		Palette.solid(Planes.Kind.BOTH, Game.plane))


func _on_status_changed(status: Game.Status) -> void:
	if status == Game.Status.DEAD:
		Burst.shards(get_parent(), global_position, Palette.GLASS)


## Launched by a spring: height, but no flip and no plane change. The height is
## fixed, so no variable-height cut applies.
func bounce(power: float) -> void:
	velocity.y = -power
	_jumping = false
	_coyote = 0.0
	# A spring hands back your air jump: it is a launch, not a jump you spent.
	_air_jumps = 1 if Game.double_jump else 0
