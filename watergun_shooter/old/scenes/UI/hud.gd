extends CanvasLayer

@export var move_bar: ProgressBar
@export var shoot_primary_bar: ProgressBar
@export var shoot_secondary_bar: ProgressBar
@export var energy_bar: ProgressBar
@export var score_label: Label
@export var energy_label: Label

@export var alloc_move_btn: Button
@export var alloc_shoot_primary_btn: Button
@export var alloc_shoot_secondary_btn: Button

func _ready() -> void:
	move_bar.max_value = GameState.MAX_MOVE
	shoot_primary_bar.max_value = GameState.MAX_SHOOT_PRIMARY
	shoot_secondary_bar.max_value = GameState.MAX_SHOOT_SECONDARY
	energy_bar.value = 0

	# colori indicativi, coerenti col prototipo web (blu / arancio / viola)
	move_bar.modulate = Color(0.30, 0.64, 1.0)
	shoot_primary_bar.modulate = Color(1.0, 0.62, 0.26)
	shoot_secondary_bar.modulate = Color(0.78, 0.49, 1.0)
	energy_bar.modulate = Color(0.375, 0.704, 0.383, 1.0)

	GameState.meters_changed.connect(_update_meters)
	GameState.energy_changed.connect(_update_energy)
	GameState.score_changed.connect(_update_score)

	_update_meters()
	_update_energy()
	_update_score()

func _update_meters() -> void:
	move_bar.value = GameState.meters["move"]
	shoot_primary_bar.value = GameState.meters["shoot_primary"]
	shoot_secondary_bar.value = GameState.meters["shoot_secondary"]

	alloc_move_btn.disabled = GameState.energy < GameState.ALLOC_COST \
		or GameState.meters["move"] >= GameState.MAX_MOVE
	alloc_shoot_primary_btn.disabled = GameState.energy < GameState.ALLOC_COST \
		or GameState.meters["shoot_primary"] >= GameState.MAX_SHOOT_PRIMARY
	alloc_shoot_secondary_btn.disabled = GameState.energy < GameState.ALLOC_COST \
		or GameState.meters["shoot_secondary"] >= GameState.MAX_SHOOT_SECONDARY

func _update_energy() -> void:
	energy_label.text = "Energy: %d" % int(GameState.energy)
	energy_bar.value = GameState.energy
	_update_meters()

func _update_score() -> void:
	score_label.text = str(GameState.score)
