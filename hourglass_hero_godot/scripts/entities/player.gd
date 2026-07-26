## The player — an hourglass.
##
## A jump does three things at once: flip (refuel), swap plane, and launch. So
## refuelling requires a NET plane change. Exceptions: spring (jump, no flip)
## and flip-pad (flip, no jump).
class_name Player
extends CharacterBody2D

## The band you are allowed to be in, in screen-y. Two edges rather than one:
## the world turns over mid-level, so either way is a way out. Set by `main.gd`.
var death_top := -10000.0
var death_bottom := 10000.0

## Screen-y of "down" for this glass: +1 normally, -1 while the world is over.
## A field rather than a live read of `Game`, for the same reason the death band
## is: a level is freed a frame after the next one is armed, and a player still
## winding down must keep judging by the world it was born in.
var pull := 1.0

var _coyote := 0.0
var _buffer := 0.0
## True while rising from a jump; gates the variable-height cut.
var _jumping := false
## Jumps left in mid-air; above zero only when the level has `double_jump`.
var _air_jumps := 0

## The light the glass gives off; its brightness is the remaining sand.
var _light: PointLight2D
var _pulse := 0.0

## The drawn hourglass.
@onready var _visual: Node2D = $Visual

## Danger below which the glass does not sweat.
const SWEAT_FROM := 0.4
## Seconds between beads at `SWEAT_FROM` and at bone dry.
const SWEAT_SLOWEST := 0.34
const SWEAT_FASTEST := 0.09

var _sweat_timer := 0.0
var _rng := RandomNumberGenerator.new()
## Suppress the landing sound until the player has first settled on the floor
## after spawn — the spawn drop is not a landing.
var _settled := false


## How far below its feet the glass reaches for the ground, in px. Only slopes
## need it: run down a ramp without a snap and you leave the floor at every
## crest, which costs a frame of contact — and with it the coyote window, the
## landing dust, and the right to jump. Kept well under the shortest step in any
## level, so it never glues you to a ledge you meant to walk off.
const FLOOR_SNAP := 8.0

## How far the landing thud is detuned each time, either way. Small on purpose:
## enough that a run of hops stops sounding like one sample on repeat, not so
## much that the glass sounds like a different object each time it touches down.
const LAND_PITCH_JITTER := 0.09


func _ready() -> void:
	collision_layer = Layers.PLAYER
	collision_mask = Layers.SOLID
	# Godot's own 45° stays: past that a face is a wall, which is what the
	# vertical sides of every ledge in the game rely on being.
	floor_snap_length = FLOOR_SNAP
	_face_gravity(Game.gravity_sign)
	Game.gravity_changed.connect(_face_gravity)
	add_to_group(Game.PLAYER_GROUP)
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
	var throb := 1.0 + 0.14 * sin(_pulse * 13.0) * danger
	_light.color = Palette.sand(danger)
	# The 0.42 floor keeps an empty glass still lighting the way.
	_light.energy = cfg.player_light_energy * (0.42 + 0.58 * fuel) * throb
	_light.texture_scale = LightKit.scale_for(cfg.player_light_radius)
	_sweat(delta, danger)


## Beads shed as the sand runs out.
func _sweat(delta: float, danger: float) -> void:
	if Game.status != Game.Status.PLAY or danger < SWEAT_FROM:
		# Reset, not pause: a bead must not fire the instant danger returns.
		_sweat_timer = 0.0
		return

	_sweat_timer -= delta
	if _sweat_timer > 0.0:
		return
	var urgency := inverse_lerp(SWEAT_FROM, 1.0, danger)
	_sweat_timer = lerpf(SWEAT_SLOWEST, SWEAT_FASTEST, urgency)
	var from := global_position + Vector2(
		_rng.randf_range(-11.0, 11.0),
		_rng.randf_range(-15.0, -4.0) * pull)
	Burst.sweat(get_parent(), from, Palette.GLASS)


func _physics_process(delta: float) -> void:
	var cfg := Tuning.cfg

	# Sand slosh (sprite + HUD). Sampled here so it is the speed *after* last
	# frame's `move_and_slide` — zero against a wall.
	Glass.travel = velocity.x

	# Every vertical line below reads the DOWNWARD component, `velocity.y * pull`,
	# and writes it back the same way: one set of arithmetic, either way up.
	if Game.status != Game.Status.PLAY:
		# Dead or cleared: freeze, but keep gravity.
		velocity.x = 0.0
		velocity.y = pull * minf(velocity.y * pull + cfg.gravity * delta, cfg.max_fall_speed)
		move_and_slide()
		return

	var steer := Input.get_axis("move_left", "move_right")
	velocity.x = steer * cfg.move_speed
	Game.aim(steer)
	# The clock is the player's to start; a level that holds it runs frozen
	# until this line.
	if not is_zero_approx(steer):
		Game.start_clock()

	# A locked jump reads as never pressed, buffer included.
	var pressed_jump := Game.jump_enabled and Input.is_action_just_pressed("jump")

	# Coyote time, then jump buffer.
	_coyote = cfg.coyote_time if is_on_floor() else maxf(0.0, _coyote - delta)
	_buffer = cfg.jump_buffer if pressed_jump else maxf(0.0, _buffer - delta)

	if _buffer > 0.0 and _coyote > 0.0:
		_jump(steer)
	elif _air_jumps > 0 and pressed_jump:
		# Keyed to the press, not `_buffer`: a buffered jump must not be spent in
		# the air. A second real flip, so it undoes the first: pure height.
		_air_jumps -= 1
		_jump(steer)

	velocity.y += cfg.gravity * pull * delta
	# Variable jump height.
	if _jumping and not Input.is_action_pressed("jump") and velocity.y * pull < 0.0:
		velocity.y = pull * maxf(velocity.y * pull, -cfg.jump_cut_velocity)
	velocity.y = pull * minf(velocity.y * pull, cfg.max_fall_speed)

	var was_airborne := not is_on_floor()
	var impact := velocity.y * pull
	move_and_slide()

	if is_on_floor():
		if was_airborne and _settled:
			_land(impact)
		_jumping = false
		_air_jumps = 1 if Game.double_jump else 0
		_settled = true

	if global_position.y < death_top or global_position.y > death_bottom:
		Game.kill()


## Turns with the world. The velocity is deliberately left alone, so the flip
## reads as the world moving rather than as the glass being teleported.
func _face_gravity(sign: float) -> void:
	pull = sign
	up_direction = Vector2(0.0, -pull)


## The signature move: height, a turn of the glass, and a plane change, all off
## one press.
##
## The turn follows the input HELD right now rather than `velocity.x`. They agree
## in open ground, and they disagree in exactly the place it matters: pinned
## against a wall your velocity is zero, and reading it would take the choice of
## chamber away from you at the moment you most want it. `steer` is the value the
## ghost world was drawn from, so it lands where it said it would.
func _jump(steer: float) -> void:
	_buffer = 0.0
	_coyote = 0.0
	_jumping = true
	velocity.y = -Tuning.cfg.jump_velocity * pull
	Game.jump_flip(steer)
	Audio.sfx("jump")


# ----- Presentation ----------------------------------------------------------
# Effects are parented to the LEVEL (`get_parent()`), not the player, so they
# neither follow it nor die with it.

func _land(impact_speed: float) -> void:
	var force := clampf(impact_speed / maxf(Tuning.cfg.max_fall_speed, 1.0) * 2.4, 0.0, 1.0)
	if force < 0.08:
		return
	Burst.dust(get_parent(), global_position + Vector2(0.0, 19.0 * pull),
		Palette.solid(Planes.Kind.BOTH, Game.plane), force)
	Audio.sfx("land", LAND_PITCH_JITTER)


func _on_flipped(_from_pad: bool) -> void:
	Burst.ring(get_parent(), global_position,
		Palette.solid(Planes.Kind.BOTH, Game.plane))


## Death: shatter and spill. Hide the visual on the frame the fragments appear,
## and cap their lifetime at `death_delay` — the level is freed then.
func _on_status_changed(status: Game.Status) -> void:
	if status != Game.Status.DEAD:
		return
	var life: float = Tuning.cfg.death_delay
	# How full the whole glass was, 0 to 1. Each chamber reads 0 to 1 against its
	# own capacity and the glass holds `count / 2` of those, so that is what
	# normalises the total — and at two chambers it is the shipped `x + y`.
	var chambers := Glass.motion.chambers()
	var full := 0.0
	for fill in chambers:
		full += fill
	# The glass breaks the way up it was standing: gravity inverted means the art
	# was a half turn round, and the pieces have to start there too.
	Burst.shatter(get_parent(), global_position, _visual.body_size, Palette.GLASS, life,
		pull < 0.0)
	# Where the spilled sand comes to rest: the ground the glass was standing on,
	# which is its own feet. Only when it was standing, and only the right way up —
	# sand falls down whatever gravity the player was under, so a glass that died
	# in the air or on a ceiling has nothing under it to land on.
	var ground := INF
	if is_on_floor() and pull > 0.0:
		ground = global_position.y + _visual.body_size.y * 0.5
	Burst.spill(get_parent(), global_position, Palette.sand(Game.danger()),
		full / (chambers.size() / 2.0), life, ground)
	_visual.hide()
	Audio.sfx("death")


## Launched by a spring: no flip, no plane change, and no variable-height cut.
func bounce(power: float) -> void:
	velocity.y = -power * pull
	_jumping = false
	_coyote = 0.0
	Audio.sfx("spring")
	# A launch, not a jump spent: the air jump is handed back.
	_air_jumps = 1 if Game.double_jump else 0
