extends Node2D

@export var enemy_scene: PackedScene
@export var spawn_interval := 2.0
@export var min_spawn_interval := 0.6
@export var spawn_decrease_per_kill := 0.02

var spawn_timer := 0.0

func _ready() -> void:
	GameState.reset()
	GameState.game_over_triggered.connect(_on_game_over)

func _process(delta: float) -> void:
	spawn_timer += delta
	var interval: float = max(min_spawn_interval, spawn_interval - GameState.score * spawn_decrease_per_kill)
	if spawn_timer >= interval:
		spawn_timer = 0.0
		_spawn_enemy()

func _spawn_enemy() -> void:
	var view_size := get_viewport_rect().size
	var edge := randi() % 4
	var pos := Vector2.ZERO
	match edge:
		0: pos = Vector2(randf() * view_size.x, -20)
		1: pos = Vector2(randf() * view_size.x, view_size.y + 20)
		2: pos = Vector2(-20, randf() * view_size.y)
		3: pos = Vector2(view_size.x + 20, randf() * view_size.y)
	var enemy := enemy_scene.instantiate()
	enemy.global_position = pos
	add_child(enemy)

func _on_game_over() -> void:
	get_tree().paused = true
	print("Game Over — Punteggio: ", GameState.score)
