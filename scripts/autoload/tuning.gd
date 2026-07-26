## Autoload `Tuning` — owns the single shared GameConfig instance, read
## everywhere as `Tuning.cfg.<variable>`.
extends Node

const CONFIG_PATH := "res://resources/game_config.tres"

var cfg: GameConfig


func _ready() -> void:
	# `load`, not `preload`: a missing .tres must still let the game start.
	var res := load(CONFIG_PATH) if ResourceLoader.exists(CONFIG_PATH) else null
	cfg = res as GameConfig
	if cfg == null:
		push_warning("game_config.tres not found — falling back to defaults.")
		cfg = GameConfig.new()
