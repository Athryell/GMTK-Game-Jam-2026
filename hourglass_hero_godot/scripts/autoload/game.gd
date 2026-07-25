## Autoload `Game` — run state: sand, current plane, progression.
## Holds no rendering; other nodes read this state and listen to its signals.
extends Node

const LEVELS_DIR := "res://scenes/levels"
## Nodes here are asked `contains_player()` once a frame. A group rather than a
## registry: unloading a level deregisters every zone for free.
const INVERSION_GROUP := "inversion_zones"
## The player puts itself here. Entities that need to know where it IS — rather
## than merely whether it has touched them — look it up through this. A group
## rather than a reference on `Game`: the level owns the player, so nothing here
## has to be cleared when the level goes.
const PLAYER_GROUP := "player"

enum Status { PLAY, DEAD, LEVEL_CLEAR, VICTORY }

## The player's plane changed; entities (de)activate off this.
signal plane_changed(plane: Planes.Kind)
## The hourglass was flipped; `from_pad` distinguishes a flip-pad from a jump.
signal flipped(from_pad: bool)
signal status_changed(status: Status)
## Which way the world pulls has changed. `sign` is the new [member gravity_sign].
signal gravity_changed(sign: float)
signal level_loaded(index: int, level_name: String)

## Level scenes, sorted by filename (level_01_… before level_02_…).
var level_scenes: Array[PackedScene] = []
## Display names, parallel to `level_scenes`.
var level_names: Array[String] = []
var level_index := 0

## Progression gate; everything is unlocked for now.
var unlock_all := true
## Highest level index reached; tracked even while `unlock_all` is on.
var levels_reached := 0

## How much sand sits in each chamber, indexed by SLOT — by fixed position on
## screen, not by which chamber it happens to be. Slot 0 is always the top one.
var chambers := PackedFloat32Array([0.0, 0.0])
## How many chambers this level's glass has, which is also how many planes it
## has. Two is the hourglass the game opens with.
var chamber_count := 2

## The sand you can still spend: everything sitting in a chamber that drains.
##
## Derived rather than stored, which is what let the whole multi-chamber glass
## arrive without the HUD, the light, the tremble or `danger()` changing a line.
## At three and four chambers there is exactly one draining chamber, so this is
## simply the top one.
##
## Writable, and it MUST stay writable. A property with only a getter is not an
## error in GDScript: `Game.sand = x` compiles, does nothing, and the next line
## reads the old value — which is how a smoke check sat there filling a glass
## that was never filled. Setting it puts the sand where it is spent from and
## leaves every other chamber alone, so the glass's total moves with it.
var sand: float:
	get:
		var total := 0.0
		for i in ChamberLayout.uppers(chamber_count):
			total += chambers[i]
		return total
	set(value):
		var draining := ChamberLayout.uppers(chamber_count)
		var each := clampf(value, 0.0, capacity() * draining.size()) / float(draining.size())
		for i in draining:
			chambers[i] = each

var plane: Planes.Kind = Planes.Kind.P0
var status: Status = Status.PLAY
## Which way the sand runs: +1 normally, -1 inside an inversion zone. Cached
## once a frame because `danger()` is read several times by the HUD, the sprite
## and the player's light.
var sand_flow := 1.0
## How far the drawn sand has turned over, 0 (running down the glass) to 1
## (running up it). Lags `sand_flow` by `flow_turn_duration`: sand that changes
## direction between two frames reads as a glitch rather than as a cause.
var flow_blend := 0.0

## Mid-air extra jump. Set by `main.gd` after the level scene exists, since
## `start_level` runs before it is instantiated.
var double_jump := false

## Screen-y of "down" right now: +1 normally, -1 while the world is upside down.
## Changed mid-level by a [GravityPad]. Every vertical quantity is written as a
## downward component times this, so an inverted world is the same code.
##
## Set through `set_gravity`, never assigned directly: the player has to be told.
var gravity_sign := 1.0

## Seconds left on the flip animation, and which way it tumbles.
var flip_anim: float = 0.0
var flip_dir: float = 1.0
## Seconds left on the "flip-pad triggered" flash.
var pad_flash: float = 0.0



## Idempotent: a pad fires every time it is touched, and standing on one must
## not flutter the world.
func set_gravity(sign: float) -> void:
	var wanted := signf(sign) if not is_zero_approx(sign) else 1.0
	if is_equal_approx(wanted, gravity_sign):
		return
	gravity_sign = wanted
	gravity_changed.emit(gravity_sign)


func _ready() -> void:
	level_scenes = _discover_levels()
	for scene in level_scenes:
		level_names.append(_read_level_name(scene))
	if level_scenes.is_empty():
		push_error("No levels found in %s" % LEVELS_DIR)


func _process(delta: float) -> void:
	if flip_anim > 0.0:
		flip_anim = maxf(0.0, flip_anim - delta)
	if pad_flash > 0.0:
		pad_flash = maxf(0.0, pad_flash - delta)
	if status != Status.PLAY:
		return
	# Both ends of the glass kill, and it is the DRAINING chambers that run out,
	# not the glass: at four chambers you can die with sand still sealed in a side
	# you never turned towards. Normally an empty one is death; inside an
	# inversion zone the sand climbs back into them and a brim-full one — nothing
	# left below to lift — is death instead. Standing still is never safe.
	var cfg := Tuning.cfg
	var flow := poll_sand_flow()
	advance_flow_blend(delta)
	drain(delta * flow * (cfg.sand_reverse_rate if flow < 0.0 else cfg.sand_drain_rate))
	if flow < 0.0:
		if sand >= capacity():
			set_status(Status.DEAD)
	elif sand <= 0.0:
		set_status(Status.DEAD)


## Asks every zone whether it holds the player, caches the answer in
## `sand_flow` and returns it. Zones never push to `Game`, so the clock keeps a
## single writer. One containing zone is enough: the flow is a direction, not
## a total, so overlapping zones do not stack.
func poll_sand_flow() -> float:
	sand_flow = 1.0
	for zone in get_tree().get_nodes_in_group(INVERSION_GROUP):
		if zone.contains_player():
			sand_flow = -1.0
			break
	return sand_flow


## Moves the drawn sand a step towards whichever way the clock is running, and
## returns how far it has got. Kept apart from `sand_flow` so the death rule
## switches on the frame you cross the line; only the picture is allowed to lag.
func advance_flow_blend(delta: float) -> float:
	var target := 1.0 if sand_flow < 0.0 else 0.0
	flow_blend = move_toward(flow_blend, target,
		delta / maxf(Tuning.cfg.flow_turn_duration, 0.001))
	return flow_blend


## Scans the levels folder; a .tscn dropped in there is picked up on next run.
func _discover_levels() -> Array[PackedScene]:
	var names: Array[String] = []
	var dir := DirAccess.open(LEVELS_DIR)
	if dir == null:
		return []
	for file in dir.get_files():
		# In an exported build scenes are remapped to .tscn.remap.
		var clean := file.trim_suffix(".remap")
		if clean.get_extension() == "tscn":
			names.append(clean)
	names.sort()

	var out: Array[PackedScene] = []
	for n in names:
		var scene := load(LEVELS_DIR.path_join(n)) as PackedScene
		if scene != null:
			out.append(scene)
	return out


## Reads `level_name` from a scene without instantiating it; falls back to the
## filename.
func _read_level_name(scene: PackedScene) -> String:
	var state := scene.get_state()
	if state.get_node_count() > 0:
		for i in state.get_node_property_count(0):
			if state.get_node_property_name(0, i) == "level_name":
				return str(state.get_node_property_value(0, i))
	# "level_04_the_spring.tscn" -> "The Spring"
	var stem := scene.resource_path.get_file().get_basename()
	var words := stem.split("_", false)
	var out := ""
	for w in words:
		if w.is_valid_int() or w == "level":
			continue
		out += (" " if out != "" else "") + w.capitalize()
	return out if out != "" else stem


## Is this level playable from the menu?
func is_unlocked(index: int) -> bool:
	return unlock_all or index <= levels_reached


# ----- Level lifecycle -------------------------------------------------------

func start_level(index: int) -> void:
	level_index = clampi(index, 0, level_scenes.size() - 1)
	levels_reached = maxi(levels_reached, level_index)
	# Two chambers until the level says otherwise. `main.gd` re-arms the glass
	# once the scene exists and can be asked; this is what a level that never
	# does gets.
	arm_glass(2, Tuning.cfg.sand_start)
	sand_flow = 1.0
	flow_blend = 0.0
	flip_anim = 0.0
	pad_flash = 0.0
	# Cleared so a level granting it cannot leak into the next one.
	double_jump = false
	set_plane(Planes.Kind.P0)
	set_status(Status.PLAY)


func next_level() -> void:
	if level_index + 1 < level_scenes.size():
		start_level(level_index + 1)
	else:
		set_status(Status.VICTORY)


func restart() -> void:
	if status == Status.VICTORY:
		start_level(0)
	else:
		start_level(level_index)


func set_status(new_status: Status) -> void:
	if status == new_status:
		return
	status = new_status
	status_changed.emit(status)


## Called by `main.gd` once the level scene is built and the player placed, so
## that `level_loaded` is only ever emitted from here.
func announce_level(level_name: String) -> void:
	level_loaded.emit(level_index, level_name)


func set_plane(new_plane: Planes.Kind) -> void:
	plane = new_plane
	plane_changed.emit(plane)


# ----- The hourglass ---------------------------------------------------------

## The glass a level is played on: `count` chambers, `top` sand in the one on
## top, the rest of the glass split evenly among the others.
##
## The glass carries one bulb of sand per turn it takes to get a drained bulb
## back on top, and no more. At four chambers the sand lands opposite, two turns
## away, so it has to carry the turn in between; at two and three it lands next
## door and one bulb is the whole supply.
##
## `top` is always `sand_start`, so the runway before the first turn is the same
## whatever the count. What the count changes is what comes back: three chambers
## split every drain in two and hand you back only the half you turn into, which
## is why they get one bulb and not one and a half.
func arm_glass(count: int, top: float) -> void:
	chamber_count = clampi(count, 2, Planes.COUNT)
	chambers = PackedFloat32Array()
	chambers.resize(chamber_count)
	chambers[0] = clampf(top, 0.0, capacity())
	var rest := (capacity() * reach() - chambers[0]) / float(chamber_count - 1)
	for i in range(1, chamber_count):
		chambers[i] = maxf(rest, 0.0)


## Turns before a bulb drained from the top can be on top again: the nearest
## chamber the top pours into, counted in steps either way round.
func reach() -> int:
	var targets := ChamberLayout.targets(chamber_count, 0)
	for step in range(1, chamber_count):
		if targets.has(posmod(step, chamber_count)) \
			or targets.has(posmod(-step, chamber_count)):
			return step
	return 1


## One chamber's capacity. `sand_max` has always meant this — at two chambers all
## of it fits into a single bulb, which is why the shipped flip could clamp to it.
func capacity() -> float:
	return Tuning.cfg.sand_max


## Moves `amount` of sand out of the draining chambers and into whatever sits
## below them. Never destroys a grain: what a chamber loses, its targets gain.
##
## A NEGATIVE amount runs the same falls backwards — an inversion zone, where the
## sand climbs out of the chambers below and back into the one draining. It is
## the same graph read the other way round, so nothing here needed a second
## table, and the trickle is drawn from the same `targets` either way.
##
## The rate is the glass's, not a chamber's — two chambers draining at once each
## run at half speed, so the clock does not care how the sand is arranged.
func drain(amount: float) -> void:
	var down := amount >= 0.0
	var live: Array[int] = []
	for i in ChamberLayout.uppers(chamber_count):
		# Running down, a chamber is live while it still holds sand; running up,
		# while it still has room. Either way a dead chamber is one the sand cannot
		# move through, and the glass's rate is shared among the rest.
		var free := chambers[i] > 0.0 if down else chambers[i] < capacity()
		if free:
			live.append(i)
	if live.is_empty():
		return
	var each := amount / float(live.size())
	for i in live:
		var targets := ChamberLayout.targets(chamber_count, i)
		if targets.is_empty():
			continue
		# Capped at both ends, in whichever direction the sand is going: there has
		# to be sand to move, and room to put it in.
		var below := 0.0
		for t in targets:
			below += chambers[t]
		var moved := clampf(each, -minf(below, capacity() - chambers[i]), chambers[i])
		chambers[i] -= moved
		var share := moved / float(targets.size())
		for t in targets:
			chambers[t] += share


## One step of the glass. `dir` is +1 clockwise on screen and -1 the other way;
## every chamber keeps its sand and moves to the next slot.
##
## At two chambers this IS the flip that shipped: the lower chamber always holds
## `sand_max - top`, so the new top is `sand_max - old_top + sand_flip_base`,
## character for character.
func rotate_glass(dir: int) -> void:
	var moved := PackedFloat32Array()
	moved.resize(chamber_count)
	for i in chamber_count:
		moved[posmod(i + dir, chamber_count)] = chambers[i]
	chambers = moved
	_pay_flip_bonus()


## The tuning panel's flip bonus, kept meaning what it means at any chamber
## count: it tops the draining chambers up, and the glass takes the cost back out
## of the fullest chamber that does not drain, so the total never moves.
##
## It is 0 in the shipped config and this whole function is inert. It is here so
## that dragging the slider still does something sane rather than quietly
## inventing sand.
func _pay_flip_bonus() -> void:
	var bonus := Tuning.cfg.sand_flip_base
	if is_zero_approx(bonus):
		return
	for i in ChamberLayout.uppers(chamber_count):
		var room := capacity() - chambers[i]
		var added := clampf(bonus, 0.0, room)
		chambers[i] += added
		var payer := -1
		for j in chamber_count:
			if j != i and (payer < 0 or chambers[j] > chambers[payer]):
				payer = j
		if payer >= 0:
			var paid := minf(added, chambers[payer])
			chambers[payer] -= paid
			chambers[i] -= added - paid


## A jump: turns the glass AND moves you to the next plane.
func jump_flip(travel_dir: float) -> void:
	# The turn rolls the way you travel, like a wheel; a straight-up jump keeps
	# the last direction.
	if not is_zero_approx(travel_dir):
		flip_dir = signf(travel_dir)
	rotate_glass(int(flip_dir))
	set_plane(Planes.step(plane, int(flip_dir), chamber_count))
	flip_anim = Tuning.cfg.flip_duration
	flipped.emit(false)


## A flip-pad: refuels with no jump and no plane change. Standing still while the
## glass turns only reads right at two chambers, where the pad just swaps the two
## bulbs — no three- or four-chamber level places one.
func pad_flip() -> void:
	rotate_glass(1)
	pad_flash = Tuning.cfg.pad_flash_duration
	flipped.emit(true)


## Flash progress, 1 (just fired) down to 0.
func pad_flash_ratio() -> float:
	var duration := Tuning.cfg.pad_flash_duration
	if duration <= 0.0:
		return 0.0
	return clampf(pad_flash / duration, 0.0, 1.0)


## How close death is, from 0 (safe) to 1 (about to run out), measured against
## whichever end is currently lethal: an empty glass normally, a full one when
## inverted.
func danger() -> float:
	var cfg := Tuning.cfg
	var warn := cfg.sand_warn
	var left := cfg.sand_max - sand if sand_flow < 0.0 else sand
	if warn <= 0.0 or left > warn:
		return 0.0
	return clampf(1.0 - left / warn, 0.0, 1.0)


func kill() -> void:
	set_status(Status.DEAD)


func win() -> void:
	set_status(Status.LEVEL_CLEAR)
