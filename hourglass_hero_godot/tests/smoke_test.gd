## Smoke test: boots the real game and checks the core mechanic holds up.
## Plays itself, no window needed:
##
##   godot --headless tests/smoke_test.tscn
##
## Exits 1 on the first failure, so it can be wired into CI.
extends Node

const MAIN := preload("res://scenes/main.tscn")

var _failures := 0
var _main: Node2D


func _ready() -> void:
	await get_tree().process_frame
	_main = MAIN.instantiate()
	add_child(_main)
	await _frames(10)

	# Counted from the folder rather than written down here: adding a level is
	# meant to be "drop a .tscn in", and a hard-coded number turns that into
	# "drop a .tscn in and then go fix the test".
	var on_disk := _levels_on_disk()
	_check("every level scene in the folder is discovered",
		Game.level_scenes.size() == on_disk and on_disk > 0,
		"%d discovered, %d on disk" % [Game.level_scenes.size(), on_disk])

	var player := _find_player()
	_check("player is instantiated", player != null)
	if player == null:
		_finish()
		return

	# --- Sand drains ---------------------------------------------------------
	var sand_at_start := Game.sand
	await _frames(30)
	_check("sand drains", Game.sand < sand_at_start,
		"%.0f → %.0f" % [sand_at_start, Game.sand])

	# --- Falling and landing -------------------------------------------------
	await _frames(60)
	_check("player lands on the floor", player.is_on_floor(),
		"y=%.1f" % player.global_position.y)

	# --- The jump: flips the glass and swaps plane ---------------------------
	var plane_before := Game.plane
	var sand_before := Game.sand
	await _press("jump", 4)
	await _frames(4)
	_check("jump swaps plane", Game.plane != plane_before)
	_check("jump refuels the hourglass (max - sand)",
		Game.sand > sand_before,
		"%.0f → %.0f (expected ≈ %.0f)" % [sand_before, Game.sand,
			Tuning.cfg.sand_max - sand_before])
	_check("jump leaves the ground", not player.is_on_floor())

	# --- Two jumps return you to the starting plane --------------------------
	await _frames(60)
	await _press("jump", 4)
	await _frames(4)
	_check("second jump returns to the starting plane", Game.plane == plane_before)

	# --- Walking straight must KILL: on level 1 the sand starts at half, and
	# the crossing is longer than the reserve. That is the heart of the design.
	Game.restart()
	await _frames(5)
	Input.action_press("move_right")
	var died := false
	for i in 600:
		await get_tree().physics_frame
		if Game.status == Game.Status.DEAD:
			died = true
			break
	Input.action_release("move_right")
	_check("walking without jumping empties the glass and kills", died,
		"status=%s" % Game.status)

	# --- Walking WHILE jumping refuels and gets you to the door: the whole
	# gameplay loop, end to end.
	Game.restart()
	await _frames(5)
	player = _find_player()
	var level_before := Game.level_index
	Input.action_press("move_right")
	var reached := false
	for i in 900:
		# A jump every ~1.5 s: the sand is low, so the flip gives back nearly
		# everything.
		if i % 90 == 0:
			Input.action_press("jump")
		elif i % 90 == 6:
			Input.action_release("jump")
		await get_tree().physics_frame
		if Game.status == Game.Status.LEVEL_CLEAR or Game.level_index != level_before:
			reached = true
			break
	Input.action_release("move_right")
	Input.action_release("jump")
	_check("walking while jumping reaches the level 1 door", reached,
		"status=%s x=%.0f sand=%.0f" % [Game.status, player.global_position.x, Game.sand])

	# --- Every level loads and runs ------------------------------------------
	# Catches a broken scene, a mis-wired entity, a spawn placed over a pit:
	# start each level and let it stand still for as long as its own clock
	# allows. The window is derived from the level's sand budget rather than
	# fixed at a second, because "The Last Grain" opens 1.2 s from death by
	# design — a fixed window would read that design as a bug, and a
	# hand-maintained list of exceptions would rot the moment a level is retuned.
	var double_jump_levels: Array[int] = []
	for i in Game.level_scenes.size():
		Game.start_level(i)
		await _load_level_scene()
		var level := _current_level()
		_check("level %d loads and spawns a player" % [i + 1],
			level != null and _find_player() != null and _level_name() != "")
		if level == null:
			continue
		if level.double_jump:
			double_jump_levels.append(i)
		_check("level %d (%s) grants exactly the rules it declares" % [i + 1, _level_name()],
			Game.double_jump == level.double_jump
				and Game.chamber_count == level.chambers
				and (level.sand_start_override <= 0.0
					or is_equal_approx(Game.sand, level.sand_start_override)),
			"double_jump=%s chambers=%d/%d sand=%.0f (override %.0f)"
				% [Game.double_jump, Game.chamber_count, level.chambers, Game.sand,
					level.sand_start_override])

		var budget := level.sand_start_override if level.sand_start_override > 0.0 \
			else Tuning.cfg.sand_start
		# Six frames of slack: this asks "does anything here kill you", not
		# "is the drain rate exactly what I think it is".
		var frames := mini(60, int(budget / Tuning.cfg.sand_drain_rate * 60.0) - 6)
		await _frames(frames)
		_check("level %d (%s) runs %d frames without dying" % [i + 1, _level_name(), frames],
			Game.status == Game.Status.PLAY, "status=%s" % Game.status)

	# --- The air jump --------------------------------------------------------
	_check("some level grants the double jump", not double_jump_levels.is_empty())
	if not double_jump_levels.is_empty():
		await _check_air_jump(double_jump_levels[0])

	# --- Spikes obey the plane, like every other entity -----------------------
	var spikes := preload("res://scenes/entities/spikes.tscn").instantiate() as Spikes
	spikes.plane = Planes.Kind.P0
	add_child(spikes)
	Game.set_plane(Planes.Kind.P0)
	_check("spikes are armed inside their own plane", spikes.monitoring)
	Game.set_plane(Planes.Kind.P1)
	_check("spikes go inert in the other plane", not spikes.monitoring)
	spikes.queue_free()

	# --- The glass turns as far as its chamber count says --------------------
	# A jump moves you exactly one plane on, whatever the glass is. At two
	# chambers that is the flip the game shipped with; at four it is a quarter
	# turn, and it takes four of them to get back where you started.
	for count in [2, 3, 4]:
		Game.arm_glass(count, Tuning.cfg.sand_start)
		Game.set_plane(Planes.Kind.P0)
		var walked := true
		for turn in count:
			Game.jump_flip(1.0)
			var wanted: int = posmod(turn + 1, count)
			walked = walked and int(Game.plane) == wanted
		_check("N=%d: turning one way walks the planes in order" % count, walked,
			"landed on %d" % int(Game.plane))
		_check("N=%d: a full lap comes home" % count, int(Game.plane) == 0)

	# --- Which way you turn ---------------------------------------------------
	# The input HELD at the moment of the jump decides, not the speed you happen
	# to be carrying. Pinned against a wall your velocity reads zero, and on a
	# four-chamber glass that is the difference between reaching a chamber and
	# stranding it for good.
	Game.arm_glass(4, Tuning.cfg.sand_start)
	Game.set_plane(Planes.Kind.P0)
	Game.jump_flip(1.0)
	_check("holding right turns the glass clockwise", int(Game.plane) == 1,
		"landed on %d" % int(Game.plane))
	Game.jump_flip(-1.0)
	_check("holding left turns it back", int(Game.plane) == 0,
		"landed on %d" % int(Game.plane))
	Game.jump_flip(0.0)
	_check("a jump with nothing held keeps the last direction", int(Game.plane) == 3,
		"landed on %d" % int(Game.plane))

	_finish()


## On a level that grants it, a second jump must fire in mid-air — and because
## it is a real flip, it must land you back in the plane you jumped from.
func _check_air_jump(index: int) -> void:
	Game.start_level(index)
	await _load_level_scene()
	var player := _find_player()
	if player == null:
		_check("air jump: player spawned", false)
		return
	for i in 120:
		await get_tree().physics_frame
		if player.is_on_floor():
			break
	_check("air jump: landed before testing", player.is_on_floor())

	var plane_before := Game.plane
	await _press("jump", 4)
	await _frames(10)
	_check("air jump: the ground jump swapped plane", Game.plane != plane_before)
	var height_before := player.global_position.y
	await _press("jump", 4)
	await _frames(4)
	_check("air jump: a second jump fires in mid-air",
		Game.plane == plane_before and player.global_position.y < height_before,
		"plane=%s y %.0f → %.0f" % [Game.plane, height_before, player.global_position.y])

	# And it must not leak: the next level gets none of it.
	Game.start_level(0)
	_check("air jump: does not leak into the next level", not Game.double_jump)


# ----- Harness ---------------------------------------------------------------

func _find_player() -> Player:
	var found := get_tree().root.find_children("", "Player", true, false)
	return found[0] if not found.is_empty() else null


## Replays `main.gd`'s scene load after a `Game.start_level`, then waits a frame.
##
## The wait is not politeness. `_load_current_level` only `queue_free`s the level
## it replaces, so until the frame ends BOTH are in the tree and `find_children`
## hands back the old one — which reads as levels reporting their predecessor's
## name and rules, and as a freed player if you touch it.
func _load_level_scene() -> void:
	_main._load_current_level()
	await get_tree().process_frame


func _current_level() -> Level:
	var found := get_tree().root.find_children("", "Level", true, false)
	return found[0] as Level if not found.is_empty() else null


func _level_name() -> String:
	var level := _current_level()
	return level.level_name if level != null else ""


## Counts the .tscn files the level folder actually holds, so the discovery
## check has a source of truth that is not this file.
func _levels_on_disk() -> int:
	var dir := DirAccess.open(Game.LEVELS_DIR)
	if dir == null:
		return -1
	var count := 0
	for file in dir.get_files():
		if file.trim_suffix(".remap").get_extension() == "tscn":
			count += 1
	return count


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _press(action: String, frames: int) -> void:
	Input.action_press(action)
	await _frames(frames)
	Input.action_release(action)


func _check(label: String, ok: bool, detail := "") -> void:
	if ok:
		print("  ok   %s" % label)
	else:
		_failures += 1
		print("  FAIL %s%s" % [label, "  (%s)" % detail if detail else ""])


func _finish() -> void:
	print("")
	if _failures == 0:
		print("All checks passed.")
		get_tree().quit(0)
	else:
		print("%d failure(s)." % _failures)
		get_tree().quit(1)
