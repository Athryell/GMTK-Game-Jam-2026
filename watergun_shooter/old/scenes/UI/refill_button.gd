extends Button

@export var meter_name: String = "move"
@export var repeat_interval := 0.15  ## ogni quanto versa energia mentre tieni premuto

var _timer: Timer

func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = repeat_interval
	_timer.one_shot = false
	add_child(_timer)
	_timer.timeout.connect(_on_timeout)
	button_down.connect(_on_pressed)
	button_up.connect(_on_released)

func _on_pressed() -> void:
	GameState.allocate(meter_name)  # un versamento immediato al click
	_timer.start()

func _on_released() -> void:
	_timer.stop()

func _on_timeout() -> void:
	GameState.allocate(meter_name)  # continua a versare finché tieni premuto
