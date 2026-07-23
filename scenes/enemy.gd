class_name Enemy extends CharacterBody2D

@export var speed := 90.0

var player: Player
var energy_pickup_scene: PackedScene = preload(Constants.SCENE_PATH.energy_pickup)

func _ready() -> void:
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")


func _physics_process(_delta: float) -> void:
	if player == null:
		return
	velocity = (player.global_position - global_position).normalized() * speed
	move_and_slide()

func kill() -> void:
	GameState.add_score(1)
	
	_spawn_pickup()

	queue_free()
	
func _spawn_pickup() -> void:
	var rand_amount: int = randi_range(2, 4)
	for i in rand_amount:
		var pickup := energy_pickup_scene.instantiate()
		pickup.global_position = global_position
		get_tree().current_scene.add_child(pickup)
