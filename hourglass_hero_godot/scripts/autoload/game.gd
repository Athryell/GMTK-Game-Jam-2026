## Autoload `Game` — run state: sand, current plane, progression.
##
## Deliberately kept away from rendering: the HUD, the player and the entities
## read this state and listen to its signals; nobody talks to anybody directly.
extends Node

const LEVELS_DIR := "res://scenes/levels"

enum Status { PLAY, DEAD, LEVEL_CLEAR, VICTORY }

## The player's plane changed — entities (de)activate off this.
signal plane_changed(plane: Planes.Kind)
## The hourglass was just flipped. `from_pad` tells a flip-pad from a jump.
signal flipped(from_pad: bool)
signal status_changed(status: Status)
signal level_loaded(index: int, level_name: String)

## Level scenes, sorted by filename (level_01_… before level_02_…).
var level_scenes: Array[PackedScene] = []
## Display names, parallel to `level_scenes`. Read straight off the scene files
## so the menu can list them without instantiating a single level.
var level_names: Array[String] = []
var level_index := 0

## Progression gate. Everything is open for now — the menu asks `is_unlocked()`,
## so gating later is a one-line change here, with no UI to touch.
var unlock_all := true
## Highest level index reached so far. Kept up to date even while `unlock_all`
## is on, so switching the gate off works immediately.
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
var sand: float:
	get:
		var total := 0.0
		for i in ChamberLayout.uppers(chamber_count):
			total += chambers[i]
		return total

var plane: Planes.Kind = Planes.Kind.P0
var status: Status = Status.PLAY

## Does the current level grant an extra jump in mid-air? Set by `main.gd` from
## the level's own `double_jump`, because the level scene does not exist yet
## when `start_level` arms the state.
var double_jump := false

## Seconds left on the flip animation, and which way it tumbles.
var flip_anim: float = 0.0
var flip_dir: float = 1.0
## Seconds left on the "flip-pad triggered" flash.
var pad_flash: float = 0.0


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
	# Sand drains continuously. Death is the DRAINING chambers running dry, not
	# the glass: at four chambers you can die with half the sand still in it,
	# sealed away in a side chamber you did not turn towards.
	drain(delta * Tuning.cfg.sand_drain_rate)
	if sand <= 0.0:
		set_status(Status.DEAD)


## Scans the levels folder. Adding a level = dropping a .tscn in there; it is
## picked up on the next run, with nothing to register anywhere.
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


## Pulls `level_name` out of a level scene without building it. Falls back to a
## readable form of the filename when the level was left at its default name.
func _read_level_name(scene: PackedScene) -> String:
	var state := scene.get_state()
	if state.get_node_count() > 0:
		for i in state.get_node_property_count(0):
			if state.get_node_property_name(0, i) == "level_name":
				return str(state.get_node_property_value(0, i))
	# "level_03_the_spring.tscn" -> "The Spring"
	var stem := scene.resource_path.get_file().get_basename()
	var words := stem.split("_", false)
	var out := ""
	for w in words:
		if w.is_valid_int() or w == "level":
			continue
		out += (" " if out != "" else "") + w.capitalize()
	return out if out != "" else stem


## Is this level playable from the menu? Always true for now.
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
	flip_anim = 0.0
	pad_flash = 0.0
	# Off until the level says otherwise, so a level that grants it cannot leak
	# into the next one.
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


## The level scene is built and the player placed. `main.gd` calls this rather
## than firing `level_loaded` itself: every signal here is emitted by `Game`, so
## there is one place to look when you wonder who announces what.
func announce_level(level_name: String) -> void:
	level_loaded.emit(level_index, level_name)


func set_plane(new_plane: Planes.Kind) -> void:
	plane = new_plane
	plane_changed.emit(plane)


# ----- The hourglass ---------------------------------------------------------

## The glass a level is played on: `count` chambers, `top` sand in the one on
## top, and the rest of the glass split evenly among the others.
##
## The split needs no tuning. `sand_start` is half of `sand_max`, and the glass
## holds `sand_max * count / 2`, so the remainder divides into exactly
## `sand_start` per chamber whatever the count. A chamber at rest reads half
## full, and the runway before the first turn is compulsory is the same on every
## glass in the game.
func arm_glass(count: int, top: float) -> void:
	chamber_count = clampi(count, 2, Planes.COUNT)
	chambers = PackedFloat32Array()
	chambers.resize(chamber_count)
	chambers[0] = clampf(top, 0.0, capacity())
	var rest := (capacity() * chamber_count / 2.0 - chambers[0]) / float(chamber_count - 1)
	for i in range(1, chamber_count):
		chambers[i] = maxf(rest, 0.0)


## One chamber's capacity. `sand_max` has always meant this — at two chambers all
## of it fits into a single bulb, which is why the shipped flip could clamp to it.
func capacity() -> float:
	return Tuning.cfg.sand_max


## Moves `amount` of sand out of the draining chambers and into whatever sits
## below them. Never destroys a grain: what a chamber loses, its targets gain.
##
## The rate is the glass's, not a chamber's — two chambers draining at once each
## run at half speed, so the clock does not care how the sand is arranged.
func drain(amount: float) -> void:
	var live: Array[int] = []
	for i in ChamberLayout.uppers(chamber_count):
		if chambers[i] > 0.0:
			live.append(i)
	if live.is_empty():
		return
	var each := amount / float(live.size())
	for i in live:
		var moved := minf(each, chambers[i])
		chambers[i] -= moved
		var targets := ChamberLayout.targets(chamber_count, i)
		if targets.is_empty():
			continue
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
	# The turn rolls the way you travel — moving right spins clockwise, like a
	# wheel. Keep the last direction on a straight-up jump.
	if not is_zero_approx(travel_dir):
		flip_dir = signf(travel_dir)
	rotate_glass(int(flip_dir))
	set_plane(Planes.step(plane, int(flip_dir), chamber_count))
	flip_anim = Tuning.cfg.flip_duration
	flipped.emit(false)


## A flip-pad: turns the glass with NO jump and NO plane change. It is the only
## way to refuel while staying where you are.
##
## The plane staying put while the glass turns only reads right on a two-chamber
## glass, where the pad simply swaps the two bulbs. No three- or four-chamber
## level places one, and doing so is out of scope.
func pad_flip() -> void:
	rotate_glass(1)
	pad_flash = Tuning.cfg.pad_flash_duration
	flipped.emit(true)


## The flash's progress, 1 (just fired) down to 0. Owning it here means the
## visual never has to know the duration — one number, one place.
func pad_flash_ratio() -> float:
	var duration := Tuning.cfg.pad_flash_duration
	if duration <= 0.0:
		return 0.0
	return clampf(pad_flash / duration, 0.0, 1.0)


## How close death is, from 0 (safe) to 1 (about to run out).
func danger() -> float:
	var warn := Tuning.cfg.sand_warn
	if warn <= 0.0 or sand > warn:
		return 0.0
	return clampf(1.0 - sand / warn, 0.0, 1.0)


func kill() -> void:
	set_status(Status.DEAD)


func win() -> void:
	set_status(Status.LEVEL_CLEAR)
