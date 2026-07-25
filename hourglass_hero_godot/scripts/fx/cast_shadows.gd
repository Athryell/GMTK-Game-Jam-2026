## The shadow the terrain throws, drawn by hand.
##
## This replaces Godot's 2D shadow map, which cannot be made clean here. That
## system asks, per direction around the lamp, "how far is the first blocker",
## and the player's lamp SITS ON the surfaces it lights: rays running along a
## floor are almost parallel to it, so the blocker and the lit pixel are at
## near-identical distances and the comparison is decided by rounding. It flips
## in blocks of neighbouring directions, and a block of directions seen from a
## grazing lamp is a hard-edged rectangle on screen. Every occluder shape I tried
## kept it, because the cause is the lamp touching the floor, not the shape.
##
## So: no depth test, no per-direction anything. Each slab is stamped again,
## pushed away from the lamp, behind the terrain. It cannot band, cannot acne,
## and cannot disagree with itself between frames, because there is nothing in it
## to be uncertain about.
##
## It sits BETWEEN the backdrop and the level in `main.tscn`, and that placement
## is the whole trick: a slab covers its own stamp, so no shadow is ever drawn
## over the thing that cast it. What is left is the part that falls past the
## slab, onto the wall behind — which is exactly the part you want to see.
class_name CastShadows
extends Node2D

## Stacked copies per shadow. Each is pushed a little further and carries a
## fraction of the darkness, so the overlap builds a soft edge out of flat
## rectangles — a penumbra without a blur, and without a shader.
const LAYERS := 4

## Slightly wider than the caster, in px. A shadow the exact width of its slab
## reads as a misprint of the slab; a hair wider reads as a shadow.
const SPREAD := 2.0

var lamp: Node2D
var _casters: Array[Platform] = []
var _reach := 1.0


## Called on every level load. The list is cached because it only changes when
## the level does, but positions are read per frame — platforms move.
func configure(level: Level) -> void:
	_casters.clear()
	for node in level.find_children("*", "Platform", true, false):
		_casters.append(node as Platform)


func _process(_delta: float) -> void:
	# The lamp is the player's, so its reach is the player light's reach. Read
	# every frame rather than cached: it is live on the tuning panel.
	_reach = maxf(Tuning.cfg.player_light_radius, 1.0)
	queue_redraw()


func _draw() -> void:
	if lamp == null or not is_instance_valid(lamp):
		return
	var cfg := Tuning.cfg
	var origin := to_local(lamp.global_position)

	for caster in _casters:
		if not is_instance_valid(caster):
			continue
		# A slab in the other plane is a thing you can walk through. It has no
		# business darkening the room you are actually standing in.
		if not Planes.is_active(caster.plane, Game.plane):
			continue

		var rect := Rect2(to_local(caster.global_position), caster.size)
		var away := rect.get_center() - origin
		var distance := away.length()
		# Nothing to cast with: past the edge of the light, or the lamp is
		# inside the slab and there is no "away" to push towards.
		if distance >= _reach or distance < 0.001:
			continue

		# Near the lamp a caster throws far and dark; at the rim of the light it
		# throws nothing. Squared on the darkness so shadows fade out before they
		# shrink away, rather than snapping off at full strength.
		var closeness := 1.0 - distance / _reach
		var throw := away / distance * cfg.shadow_throw * closeness
		var shade := Color(0.0, 0.0, 0.02, cfg.shadow_strength * closeness * closeness / LAYERS)
		var grown := rect.grow(SPREAD)

		for i in LAYERS:
			var step := throw * float(i + 1) / LAYERS
			draw_rect(Rect2(grown.position + step, grown.size), shade)
