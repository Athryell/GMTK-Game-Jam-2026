## Smoke test: boots the real game and plays itself. Exits 1 on failure.
##
##   godot --headless tests/smoke_test.tscn
##
## Tests the RULES, not the levels. Everything that asserted level content —
## the level census, the level-1 crossings, the per-level survival sweep, the
## air jump, the camera launch, the gravity-pad and inversion-zone traversals —
## was removed when the art was rescaled to one art px per world px, because
## that doubled the player and invalidated every hand-placed level. Put those
## back once the levels are rebuilt; they were worth having.
##
## The one coupling left is the boot itself: this loads level 1 and expects
## ground under the spawn. Nothing here reads that level's shape beyond that.
extends Node

const MAIN := preload("res://scenes/main.tscn")

var _failures := 0
var _main: Node2D


func _ready() -> void:
	await get_tree().process_frame
	_main = MAIN.instantiate()
	add_child(_main)
	await _frames(10)

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


# ----- Harness ---------------------------------------------------------------

func _find_player() -> Player:
	var found := get_tree().root.find_children("", "Player", true, false)
	return found[0] if not found.is_empty() else null


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
