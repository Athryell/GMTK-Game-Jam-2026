## Autoload `Tuning` — owns the single shared GameConfig instance, read
## everywhere as `Tuning.cfg.<variable>` and live-editable from the F1 panel.
extends Node

const CONFIG_PATH := "res://resources/game_config.tres"

## A tunable value changed; listeners holding derived numbers should refresh.
signal changed

var cfg: GameConfig

## Values as of the last load or save, for the panel's Reset button.
var _baseline: Dictionary = {}


func _ready() -> void:
	# `load`, not `preload`: a missing .tres must still let the game start.
	var res := load(CONFIG_PATH) if ResourceLoader.exists(CONFIG_PATH) else null
	cfg = res as GameConfig
	if cfg == null:
		push_warning("game_config.tres not found — falling back to defaults.")
		cfg = GameConfig.new()
	_baseline = snapshot()


## The tunable variables, grouped, as the tuning panel reads them.
## Each entry: { group, name, min, max, step }.
func tunable_properties() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var group := ""
	for prop in cfg.get_property_list():
		if prop.usage & PROPERTY_USAGE_GROUP:
			group = prop.name
			continue
		if not (prop.usage & PROPERTY_USAGE_EDITOR):
			continue
		if prop.type != TYPE_FLOAT or prop.hint != PROPERTY_HINT_RANGE:
			continue
		# An @export_range hint_string reads "min,max,step" (suffixes ignored).
		var parts: PackedStringArray = prop.hint_string.split(",")
		if parts.size() < 2:
			continue
		out.append({
			"group": group,
			"name": prop.name,
			"min": float(parts[0]),
			"max": float(parts[1]),
			"step": float(parts[2]) if parts.size() > 2 else 0.01,
		})
	return out


func set_value(prop: String, value: float) -> void:
	cfg.set(prop, value)
	changed.emit()


func snapshot() -> Dictionary:
	var d := {}
	for p in tunable_properties():
		d[p.name] = cfg.get(p.name)
	return d


## Restores the values as of the last load or save.
func reset() -> void:
	for key in _baseline:
		cfg.set(key, _baseline[key])
	changed.emit()


## Writes the values back to the .tres. Editor-only: res:// is read-only in an
## exported build.
func save() -> bool:
	if not OS.has_feature("editor"):
		push_warning("Cannot save tuning outside the editor.")
		return false
	var err := ResourceSaver.save(cfg, CONFIG_PATH)
	if err != OK:
		push_error("Failed to save tuning: %s" % error_string(err))
		return false
	_baseline = snapshot()
	return true
