## Builds the game's 2D lights from numbers: a radial falloff baked into a
## `GradientTexture2D`, shared by every light (colour, reach and energy are
## per-light properties). The ramp is squared, not linear, so the edge dissolves.
class_name LightKit
extends RefCounted

const TEXTURE_SIZE := 256
const FALLOFF_STOPS := 6
## How far a shadow's edge is smeared, in px: enough to keep the rim off the
## pixel grid, not so much that a wall stops reading as a wall.
const SHADOW_SMOOTH := 2.0

static var _texture: GradientTexture2D


## The shared radial falloff. Built on first use, reused forever after.
static func falloff() -> GradientTexture2D:
	if _texture != null:
		return _texture

	var gradient := Gradient.new()
	# `Gradient` starts with two points of its own; clear them first.
	gradient.offsets = PackedFloat32Array()
	gradient.colors = PackedColorArray()
	for i in FALLOFF_STOPS + 1:
		var t := float(i) / FALLOFF_STOPS
		var a := (1.0 - t) * (1.0 - t)
		gradient.add_point(t, Color(1.0, 1.0, 1.0, a))

	_texture = GradientTexture2D.new()
	_texture.gradient = gradient
	_texture.width = TEXTURE_SIZE
	_texture.height = TEXTURE_SIZE
	_texture.fill = GradientTexture2D.FILL_RADIAL
	# From the centre out to the right edge: a radius, not a diameter.
	_texture.fill_from = Vector2(0.5, 0.5)
	_texture.fill_to = Vector2(1.0, 0.5)
	return _texture


## `texture_scale` needed for a light to reach `radius` px. Always go through
## this rather than dividing by TEXTURE_SIZE at the call site.
static func scale_for(radius: float) -> float:
	return radius * 2.0 / TEXTURE_SIZE


## A light reaching `radius` px, ready to be added as a child. `casts_shadows`
## is the player's lamp only: solids stop it, see [CastShadows].
static func point(colour: Color, radius: float, energy := 1.0,
		casts_shadows := false) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = falloff()
	light.texture_scale = scale_for(radius)
	light.color = colour
	light.energy = energy
	if casts_shadows:
		light.shadow_enabled = true
		light.shadow_filter = Light2D.SHADOW_FILTER_PCF13
		light.shadow_filter_smooth = SHADOW_SMOOTH
		light.shadow_item_cull_mask = CastShadows.MASK
	return light
