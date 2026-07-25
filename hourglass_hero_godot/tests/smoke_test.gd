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

	_check("6 levels discovered", Game.level_scenes.size() == 6,
		"found %d" % Game.level_scenes.size())

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
	# start each level and let it run for a second.
	for i in Game.level_scenes.size():
		Game.start_level(i)
		_load_level_scene()
		await _frames(60)
		var p := _find_player()
		var name_ok := _level_name() != ""
		_check("level %d (%s) runs without dying" % [i + 1, _level_name()],
			p != null and Game.status == Game.Status.PLAY and name_ok,
			"status=%s" % Game.status)

	_finish()


# ----- Harness ---------------------------------------------------------------

func _find_player() -> Player:
	var found := get_tree().root.find_children("", "Player", true, false)
	return found[0] if not found.is_empty() else null


## Replays `main.gd`'s scene load after a `Game.start_level`.
func _load_level_scene() -> void:
	_main._load_current_level()


func _level_name() -> String:
	var found := get_tree().root.find_children("", "Level", true, false)
	return (found[0] as Level).level_name if not found.is_empty() else ""


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
