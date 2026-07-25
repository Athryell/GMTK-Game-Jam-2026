## Builds the game's 2D lights, texture and all, from nothing but numbers.
##
## Every other asset in this project is drawn at runtime by a `_draw()` call, and
## the lights are no exception: a `PointLight2D` needs a texture, so this bakes a
## radial falloff into a `GradientTexture2D` instead of adding a PNG to a repo
## that has none. One texture is shared by every light in the game — the colour,
## the reach and the brightness are per-light properties, not per-texture, so
## caching it costs one 256×256 buffer for the whole run.
##
## The falloff is deliberately not linear. A straight ramp reads as a flat disc
## with a hard rim; squaring it puts most of the brightness in the middle and
## lets the edge dissolve, which is what makes a pool of light look like light
## rather than like a circle someone drew.
class_name LightKit
extends RefCounted

const TEXTURE_SIZE := 256
const FALLOFF_STOPS := 6

static var _texture: GradientTexture2D


## The shared radial falloff. Built on first use, reused forever after.
static func falloff() -> GradientTexture2D:
	if _texture != null:
		return _texture

	var gradient := Gradient.new()
	# `Gradient` starts with two points of its own; they are in the way.
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


## A light reaching `radius` px, ready to be added as a child.
##
## `offset` moves it off its parent's origin, which every entity here needs:
## entity origins are top-left corners, and a light hanging off a corner lights
## the room lopsidedly.
## Never casts. Godot's 2D shadow map cannot be made clean for a lamp that sits
## on the floor it lights — see [CastShadows], which draws the terrain's shadows
## by hand instead.
static func point(colour: Color, radius: float, energy := 1.0,
		offset := Vector2.ZERO) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = falloff()
	light.texture_scale = radius * 2.0 / TEXTURE_SIZE
	light.color = colour
	light.energy = energy
	light.position = offset
	return light
