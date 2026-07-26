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
## A field rather than a live read of `Game`: a level is freed a frame after the
## next one is armed, and a player still winding down must keep judging by the
## world it was born in.
var pull := 1.0

var _coyote := 0.0
var _buffer := 0.0
## True while rising from a jump; gates the variable-height cut.
var _jumping := false

## Sideways push from a spring, in px/s, bleeding off. Steering rewrites
## `velocity.x` outright every frame, so a horizontal launch cannot live there:
## it rides on top of the steering instead.
var _launch := 0.0

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


## How far below its feet the glass reaches for the ground, in px. Without it a
## ramp crest costs a frame of contact, and with it the coyote window. Kept well
## under the shortest step in any level.
const FLOOR_SNAP := 8.0

## How far the landing thud is detuned each time, either way.
const LAND_PITCH_JITTER := 0.09

## What a feather's charge does to the lamp, to its energy and its reach alike.
## Kept under 1.5: past that the glass lights the whole room and the plane hues
## wash out.
const CHARGED_LIGHT_LIFT := 1.3


func _ready() -> void:
	collision_layer = Layers.PLAYER
	collision_mask = Layers.SOLID
	floor_snap_length = FLOOR_SNAP
	_face_gravity(Game.gravity_sign)
	Game.gravity_changed.connect(_face_gravity)
	add_to_group(Game.PLAYER_GROUP)
	_light = LightKit.point(Palette.SAND_FULL, Tuning.cfg.player_light_radius,
		Tuning.cfg.player_light_energy, true)
	add_child(_light)
	Game.flipped.connect(_on_flipped)
	Game.status_changed.connect(_on_status_changed)


func _process(delta: float) -> void:
	_pulse += delta
	var cfg := Tuning.cfg
	var danger := Game.danger()
	var fuel: float = clampf(Game.sand / maxf(cfg.sand_max, 1.0), 0.0, 1.0)
	var throb := 1.0 + 0.14 * sin(_pulse * 13.0) * danger
	var charge := CHARGED_LIGHT_LIFT if Game.feathered else 1.0
	_light.color = Palette.sand(danger, Game.feathered)
	# The 0.42 floor keeps an empty glass still lighting the way.
	_light.energy = cfg.player_light_energy * (0.42 + 0.58 * fuel) * throb * charge
	_light.texture_scale = LightKit.scale_for(cfg.player_light_radius * charge)
	# What still reaches into a shadow. At full strength, nothing.
	_light.shadow_color = Color(_light.color, 1.0 - cfg.shadow_strength)
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

	# Sampled here so it is the speed *after* last frame's `move_and_slide` — zero
	# against a wall.
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
	velocity.x = steer * cfg.move_speed + _launch
	_launch = move_toward(_launch, 0.0, cfg.spring_launch_decay * delta)
	Game.aim(steer)
	if not is_zero_approx(steer):
		Game.start_clock()

	# A locked jump reads as never pressed, buffer included.
	var pressed_jump := Game.jump_enabled and Input.is_action_just_pressed("jump")

	# Coyote time, then jump buffer.
	_coyote = cfg.coyote_time if is_on_floor() else maxf(0.0, _coyote - delta)
	_buffer = cfg.jump_buffer if pressed_jump else maxf(0.0, _buffer - delta)

	if _buffer > 0.0 and _coyote > 0.0:
		_jump(steer)
	elif Game.feathered and pressed_jump:
		# Keyed to the press, not `_buffer`: a buffered jump must not be spent in
		# the air. A second real flip, so it undoes the first: pure height.
		Game.feathered = false
		_jump(steer)

	velocity.y += cfg.gravity * pull * delta
	# Variable jump height.
	if _jumping and not Input.is_action_pressed("jump") and velocity.y * pull < 0.0:
		velocity.y = pull * maxf(velocity.y * pull, -cfg.jump_cut_velocity)
	velocity.y = pull * minf(velocity.y * pull, cfg.max_fall_speed)

	var was_airborne := not is_on_floor()
	var impact := velocity.y * pull
	move_and_slide()

	# Otherwise a launch into a wall keeps pinning the glass to it until it decays.
	if is_on_wall():
		_launch = 0.0

	if is_on_floor():
		if was_airborne and _settled:
			_land(impact)
		_jumping = false
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
## The turn follows the input HELD right now rather than `velocity.x`: pinned
## against a wall your velocity is zero, and reading it would take the choice of
## chamber away from you at the moment you most want it.
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
	# The glass breaks the way up it was standing: gravity inverted means the art
	# was a half turn round, and the pieces and the sand have to start there too.
	var turned := pull < 0.0
	Burst.shatter(get_parent(), global_position, _visual.body_size, Palette.GLASS, life,
		turned)
	# The bulb fills as the glass was DRAWING them, not the raw chamber numbers: the
	# sand that flies out has to be the sand that was on screen, pile for pile.
	Burst.spill(get_parent(), global_position, Palette.glass_sand(Game.feathered),
		Glass.motion.sprite_fills(), _visual.body_size, life, turned)
	_visual.hide()
	Audio.sfx("death")


## Launched by a spring: no flip, no plane change, and no variable-height cut.
## A spring does not refill the feather — nothing does.
##
## An axis `direction` does not push on is left alone, so an upright pad keeps
## your run speed and a pad on its side leaves you falling.
func bounce(power: float, direction: Vector2) -> void:
	var push := direction * power
	if not is_zero_approx(push.y):
		velocity.y = push.y
	if not is_zero_approx(push.x):
		_launch = push.x
	_jumping = false
	_coyote = 0.0
	Audio.sfx("spring")


# ----- The feather -----------------------------------------------------------

## Idempotent at one charge: two feathers in a level still only buy one jump.
func take_feather() -> void:
	Game.feathered = true
