extends Area2D

var spread: int = 12

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "global_position", global_position + Vector2(randi_range(-spread, spread), randi_range(-spread, spread)), 0.3)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		GameState.add_energy(GameState.PICKUP_VALUE)
		queue_free()
