class_name Player extends CharacterBody2D

@export var speed := 260.0
@export var move_drain_per_second := 1.5
@export var shoot_cooldown := 0.18
@export var shoot_secondary_cooldown := 0.6
@export var shoot_secondary_range := 130.0
@export var shoot_secondary_half_angle := deg_to_rad(45.0)
@export var hit_radius := 14.0
@export var aim_max_length := 100.0
@export var slow_speed_multiplier := 0.35
@export var pickup_scene: PackedScene
@export var shotgun_area: Area2D
@export var bullet_particles: GPUParticles2D
@export var shotgun_particles: GPUParticles2D

@onready var aim_line: Line2D = $AimLine

var can_shoot_primary := true
var can_shoot_secondary := true

func _ready() -> void:
	add_to_group("player")
	$HurtArea.body_entered.connect(_on_hurt_area_body_entered)

func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	look_at(get_global_mouse_position())
	_update_aim_line()
	_handle_input()

func _handle_movement(delta: float) -> void:
	var input_dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	).normalized()

	if input_dir != Vector2.ZERO:
		if GameState.meters["move"] > 0.01:
			velocity = input_dir * speed
			GameState.spend("move", move_drain_per_second * delta)
		else:
			velocity = input_dir * speed * slow_speed_multiplier
	else:
		velocity = Vector2.ZERO

	move_and_slide()

func _handle_input() -> void:
	if get_viewport().gui_get_hovered_control() != null:
		return  # il mouse è sopra un elemento UI, non sparare
	if Input.is_action_just_pressed("shoot_primary") and can_shoot_primary:
		_try_shoot_primary()
	if Input.is_action_just_pressed("shoot_secondary") and can_shoot_secondary:
		_try_shoot_secondary()


func _try_shoot_primary() -> void:
	if not GameState.spend("shoot_primary", 1.0):
		return
	can_shoot_primary = false
	get_tree().create_timer(shoot_cooldown).timeout.connect(func(): can_shoot_primary = true)



	var aim_dir := Vector2.RIGHT.rotated(rotation)
	var closest_enemy: Node2D = null
	var closest_dist := INF
	
	bullet_particles.restart()

	for enemy in get_tree().get_nodes_in_group("enemies"):
		var to_enemy: Vector2 = enemy.global_position - global_position
		var proj := to_enemy.dot(aim_dir)
		if proj < 0.0:
			continue
		var closest_point := global_position + aim_dir * proj
		var perp_dist = enemy.global_position.distance_to(closest_point)
		if perp_dist <= hit_radius and proj < closest_dist:
			closest_dist = proj
			closest_enemy = enemy

	if closest_enemy:
		closest_enemy.kill()


func _try_shoot_secondary() -> void:
	if not GameState.spend("shoot_secondary", 1.0):
		return
	can_shoot_secondary = false
	get_tree().create_timer(shoot_secondary_cooldown).timeout.connect(func(): can_shoot_secondary = true)
	
	shotgun_particles.restart()
	
	for enemy in shotgun_area.get_overlapping_bodies():
		enemy.kill()

	#var aim_dir := Vector2.RIGHT.rotated(rotation)
	#var to_kill: Array = []
#
	#for enemy in get_tree().get_nodes_in_group("enemies"):
		#var to_enemy: Vector2 = enemy.global_position - global_position
		#if to_enemy.length() > shoot_secondary_range:
			#continue
		#if abs(aim_dir.angle_to(to_enemy)) <= shoot_secondary_half_angle:
			#to_kill.append(enemy)
#
	#for enemy in to_kill:
		#enemy.kill()


func _on_hurt_area_body_entered(body: Node) -> void:
	if body.is_in_group("enemies"):
		GameState.trigger_game_over()

func _update_aim_line() -> void:
	var to_mouse := get_global_mouse_position() - global_position
	var length: float = min(to_mouse.length(), aim_max_length)
	aim_line.points = [Vector2.ZERO, Vector2(length, 0)]
	#aim_tip.position = Vector2(length, 0)
