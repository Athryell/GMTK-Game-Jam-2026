## Smoke test: boots the real game and plays itself. Exits 1 on failure.
##
##   godot --headless tests/smoke_test.tscn
extends Node

const MAIN := preload("res://scenes/main.tscn")

var _failures := 0
var _main: Node2D


func _ready() -> void:
	await get_tree().process_frame
	_main = MAIN.instantiate()
	add_child(_main)
	await _frames(10)

	# Counted from the folder, so adding a level stays "drop a .tscn in".
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

	# --- Walking straight must KILL: level 1 starts at half sand and the
	# crossing is longer than that reserve.
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

	# --- Walking WHILE jumping refuels and reaches the door: the whole loop.
	Game.restart()
	await _frames(5)
	player = _find_player()
	var level_before := Game.level_index
	Input.action_press("move_right")
	var reached := false
	for i in 900:
		# A jump every ~1.5 s.
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
	# The idle window is derived from each level's own sand budget, not fixed:
	# some levels deliberately open barely a second from death.
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
		# Six frames of slack: this asks "does anything here kill you".
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

	# --- The shipped game uses every glass ------------------------------------
	# Without this, deleting a chamber count from the levels folder leaves a
	# perfectly green suite testing a feature nothing plays.
	var counts := {}
	for i in Game.level_scenes.size():
		Game.start_level(i)
		await _load_level_scene()
		var level := _current_level()
		if level != null:
			counts[level.chambers] = true
	_check("some level is played on a three-chamber glass", counts.has(3))
	_check("some level is played on a four-chamber glass", counts.has(4))
	_check("and most of them are still the two-chamber hourglass", counts.has(2))

	# --- The camera keeps the player on screen --------------------------------
	await _check_camera_holds_a_launch()

	# --- The inversion zone, in the real game ---------------------------------
	await _check_inversion_zone()

	# --- Gravity the other way up ---------------------------------------------
	await _check_gravity_pad()

	_finish()


## The gravity pad, in the real game: the world starts the right way up, a pad
## turns it over, and the level is only crossable because of that.
func _check_gravity_pad() -> void:
	var index := -1
	for i in Game.level_scenes.size():
		var level := Game.level_scenes[i].instantiate() as Level
		var has_pad := level != null \
			and not level.find_children("", "GravityPad", true, false).is_empty()
		if level != null:
			level.free()
		if has_pad:
			index = i
			break
	_check("some level has a gravity pad", index >= 0)
	if index < 0:
		return

	Game.start_level(index)
	await _load_level_scene()
	var player := _find_player()
	if player == null:
		_check("gravity pad: player spawned", false)
		return
	_check("gravity pad: the level starts the right way up",
		is_equal_approx(player.pull, 1.0), "pull=%.1f" % player.pull)

	# The gap in the floor is wider than any jump, so reaching the door at all
	# proves the pads fired and the ceiling carried the crossing.
	var level_before := Game.level_index
	var reached := false
	var went_over := false
	var came_back := false
	Input.action_press("move_right")
	for i in 1200:
		if i % 90 == 0:
			Input.action_press("jump")
		elif i % 90 == 6:
			Input.action_release("jump")
		await get_tree().physics_frame
		if player.pull < 0.0:
			went_over = true
		elif went_over:
			came_back = true
		if Game.status == Game.Status.LEVEL_CLEAR or Game.level_index != level_before:
			reached = true
			break
	Input.action_release("move_right")
	Input.action_release("jump")
	_check("gravity pad: walking onto one turns the world over", went_over)
	_check("gravity pad: the opposite pad turns it back", came_back)
	_check("gravity pad: the crossing reaches the door", reached,
		"status=%s x=%.0f sand=%.0f" % [Game.status, player.global_position.x, Game.sand])

	# Setting the gravity already in force must be silent, or standing on a pad
	# would flutter the world every frame you touched it.
	var beats := 0
	var counter := func(_sign: float) -> void: beats += 1
	Game.gravity_changed.connect(counter)
	Game.set_gravity(Game.gravity_sign)
	Game.gravity_changed.disconnect(counter)
	_check("gravity pad: setting the gravity already in force says nothing", beats == 0)

	Game.start_level(0)
	await _load_level_scene()
	_check("gravity pad: the next level starts the right way up again",
		is_equal_approx(Game.gravity_sign, 1.0) and is_equal_approx(_find_player().pull, 1.0))


## A spring launch is the fastest the player ever moves. Asserted in px against
## the frame, so it survives changes to zoom, slack or spring power.
func _check_camera_holds_a_launch() -> void:
	Game.start_level(0)
	await _load_level_scene()
	var player := _find_player()
	var camera: CameraRig = get_tree().root.find_children("", "CameraRig", true, false)[0]
	if player == null or camera == null:
		_check("camera: player and camera exist", false)
		return

	for i in 120:
		await get_tree().physics_frame
		if player.is_on_floor():
			break

	var half: float = camera.get_viewport_rect().size.y / camera.zoom.y / 2.0
	player.bounce(Tuning.cfg.spring_power)
	var worst := 0.0
	for i in 90:
		await get_tree().physics_frame
		if not is_instance_valid(player) or Game.status != Game.Status.PLAY:
			break
		worst = maxf(worst, absf(player.global_position.y - camera.global_position.y))

	_check("camera keeps the player on screen through a spring launch",
		worst < half, "%.0f px off centre, frame reaches %.0f" % [worst, half])


## The zone with a real Area2D overlapping the real player. `sand_test` can only
## reach the arithmetic; this is what proves containment, the plane rule, and
## that a full glass actually kills.
func _check_inversion_zone() -> void:
	var index := Game.level_names.find("The Updraft")
	if index < 0:
		_check("level 'The Updraft' exists", false, "not in %s" % [Game.level_names])
		return
	Game.start_level(index)
	await _load_level_scene()
	await _frames(5)

	var zones := get_tree().get_nodes_in_group(Game.INVERSION_GROUP)
	_check("the level's zones join the inversion group", zones.size() >= 3,
		"found %d" % zones.size())
	if zones.is_empty():
		return

	var player := _find_player()
	if player == null:
		_check("player is instantiated on The Updraft", false)
		return
	# The spawn is the one point in the level guaranteed to be outside every
	# zone, so it is where "not in a zone" is measured from.
	var outside := player.global_position

	var zone: InversionZone = zones[0]
	var inside := zone.global_position + zone.size / 2.0
	Game.sand = Tuning.cfg.sand_max / 2.0
	await _hold(player, inside, 20)
	_check("standing in a zone reverses the flow", Game.sand_flow < 0.0)
	_check("sand climbs inside a zone", Game.sand > Tuning.cfg.sand_max / 2.0,
		"%.0f → %.0f" % [Tuning.cfg.sand_max / 2.0, Game.sand])

	# A full glass in a zone is death, exactly as an empty one is outside.
	Game.sand = Tuning.cfg.sand_max - 50.0
	var died := false
	for i in 120:
		await get_tree().physics_frame
		player.global_position = inside
		player.velocity = Vector2.ZERO
		if Game.status == Game.Status.DEAD:
			died = true
			break
	_check("a FULL glass kills inside a zone", died, "sand=%.0f" % Game.sand)

	# A zone in the other plane must do nothing at all.
	Game.restart()
	await _frames(5)
	player = _find_player()
	zone = get_tree().get_nodes_in_group(Game.INVERSION_GROUP)[0] as InversionZone
	# One plane along, which at two chambers is the opposite one — the only glass
	# any inversion level is played on.
	zone.plane = Planes.step(Game.plane, 1, Game.chamber_count)
	zone._on_plane_changed(Game.plane)
	await _hold(player, inside, 10)
	_check("a zone in the other plane leaves the flow alone", Game.sand_flow > 0.0)

	# And stepping out of one resumes the drain.
	zone.plane = Planes.Kind.BOTH
	zone._on_plane_changed(Game.plane)
	await _hold(player, outside, 10)
	var before := Game.sand
	await _hold(player, outside, 20)
	_check("leaving a zone resumes the drain", Game.sand < before,
		"%.0f → %.0f" % [before, Game.sand])


## Pins the player at `where` for `count` physics frames. Held every frame
## rather than placed once: gravity would otherwise carry them out of the zone
## mid-measurement and the check would pass or fail on the fall, not the rule.
func _hold(player: Player, where: Vector2, count: int) -> void:
	for i in count:
		player.global_position = where
		player.velocity = Vector2.ZERO
		await get_tree().physics_frame


## A second jump must fire in mid-air and, being a real flip, land you back in
## the plane you jumped from.
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

	Game.start_level(0)
	_check("air jump: does not leak into the next level", not Game.double_jump)


# ----- Harness ---------------------------------------------------------------

func _find_player() -> Player:
	var found := get_tree().root.find_children("", "Player", true, false)
	return found[0] if not found.is_empty() else null


## Replays `main.gd`'s scene load after a `Game.start_level`. The frame wait is
## required: the old level is only `queue_free`d, so until the frame ends both
## are in the tree and `find_children` returns the old one.
func _load_level_scene() -> void:
	_main._load_current_level()
	await get_tree().process_frame


func _current_level() -> Level:
	var found := get_tree().root.find_children("", "Level", true, false)
	return found[0] as Level if not found.is_empty() else null


func _level_name() -> String:
	var level := _current_level()
	return level.level_name if level != null else ""


## Counts the .tscn files in the level folder, independently of `Game`.
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
