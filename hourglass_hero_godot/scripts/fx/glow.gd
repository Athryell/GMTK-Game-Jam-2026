## A soft breathing halo, drawn ADDITIVELY so it reads as light rather than as
## paint. Its own node, because the additive blend belongs to the halo alone and
## would otherwise wash out everything else its parent draws.
##
## Sits behind its parent's own drawing: negative `z_index`.
class_name Glow
extends Node2D

## Breaths per second, and how much of the radius a breath swings.
const PULSE_RATE := 2.1
const PULSE_DEPTH := 0.14

var tint := Color.WHITE
var radius := 40.0
var alpha := 0.5

var _pulse := 0.0


## Ready to be added as a child; starts hidden.
static func halo(tint: Color, radius: float, alpha: float) -> Glow:
	var glow := Glow.new()
	glow.tint = tint
	glow.radius = radius
	glow.alpha = alpha
	glow.hide()
	return glow


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	z_index = -1


func _process(delta: float) -> void:
	if not visible:
		return
	_pulse += delta
	queue_redraw()


func _draw() -> void:
	# Two passes: the wide one is the bloom, the tight one the core it comes off.
	var breath := 1.0 + PULSE_DEPTH * sin(_pulse * PULSE_RATE)
	_disc(radius * breath, alpha)
	_disc(radius * 0.45 * breath, alpha)


func _disc(r: float, a: float) -> void:
	draw_texture_rect(LightKit.falloff(), Rect2(Vector2(-r, -r), Vector2(r, r) * 2.0),
		false, Color(tint, a))
