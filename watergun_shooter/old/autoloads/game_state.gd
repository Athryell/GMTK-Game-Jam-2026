extends Node

const MAX_MOVE := 10.0
const MAX_SHOOT_PRIMARY := 10.0
const MAX_SHOOT_SECONDARY := 3.0
const ALLOC_COST := 1.0
const PICKUP_VALUE := 1.0

var constant_move_drain_per_second := 0.1

var meters := {
	"move": MAX_MOVE,
	"shoot_primary": MAX_SHOOT_PRIMARY,
	"shoot_secondary": MAX_SHOOT_SECONDARY,
}
var energy := 0.0
var score := 0

signal meters_changed
signal energy_changed
signal score_changed
signal game_over_triggered

func reset() -> void:
	meters["move"] = MAX_MOVE
	meters["shoot_primary"] = MAX_SHOOT_PRIMARY
	meters["shoot_secondary"] = MAX_SHOOT_SECONDARY
	energy = 0.0
	score = 0
	meters_changed.emit()
	energy_changed.emit()
	score_changed.emit()

func _process(delta: float) -> void:
	spend("move", constant_move_drain_per_second * delta)

func spend(meter_name: String, amount: float) -> bool:
	if meters[meter_name] < amount:
		return false
	meters[meter_name] = max(0.0, meters[meter_name] - amount)
	meters_changed.emit()
	return true

func add_energy(amount: float) -> void:
	energy += amount
	energy_changed.emit()

func allocate(meter_name: String) -> void:
	var max_values := {
		"move": MAX_MOVE,
		"shoot_primary": MAX_SHOOT_PRIMARY,
		"shoot_secondary": MAX_SHOOT_SECONDARY
	}
	if energy < ALLOC_COST or meters[meter_name] >= max_values[meter_name]:
		return
	energy -= ALLOC_COST
	meters[meter_name] = min(max_values[meter_name], meters[meter_name] + ALLOC_COST)
	energy_changed.emit()
	meters_changed.emit()

func add_score(amount: int = 1) -> void:
	score += amount
	score_changed.emit()

func trigger_game_over() -> void:
	game_over_triggered.emit()
