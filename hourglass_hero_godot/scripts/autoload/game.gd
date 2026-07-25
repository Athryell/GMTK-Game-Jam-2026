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

var sand: float = 0.0
var plane: Planes.Kind = Planes.Kind.FRONT
var status: Status = Status.PLAY

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
	# Sand drains continuously; empty means dead.
	sand -= delta * Tuning.cfg.sand_drain_rate
	if sand <= 0.0:
		sand = 0.0
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
	sand = Tuning.cfg.sand_start
	flip_anim = 0.0
	pad_flash = 0.0
	set_plane(Planes.Kind.FRONT)
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

## Flipping the hourglass: the sand that already drained (`max - sand`) becomes
## the sand you have left. Waiting long (sand near 0) gives back nearly
## everything; flipping early gives back nearly nothing. That is the whole
## timing game.
func flip_sand() -> float:
	var cfg := Tuning.cfg
	return clampf(cfg.sand_max - sand + cfg.sand_flip_base, 0.0, cfg.sand_max)


## A jump: swaps the plane AND flips the hourglass.
func jump_flip(travel_dir: float) -> void:
	sand = flip_sand()
	set_plane(Planes.opposite(plane))
	flip_anim = Tuning.cfg.flip_duration
	# Tumble rolls the way you travel — moving right spins clockwise, like a
	# wheel. Keep the last direction on a straight-up jump.
	if not is_zero_approx(travel_dir):
		flip_dir = signf(travel_dir)
	flipped.emit(false)


## A flip-pad: flips the hourglass with NO jump and NO plane change. It is the
## only way to refuel while staying in one plane.
func pad_flip() -> void:
	sand = flip_sand()
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
