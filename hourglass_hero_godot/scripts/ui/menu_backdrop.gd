## The room behind the menu: the same painted city the levels stand in, on a slow
## pan of its own. Reuses `Backdrop`'s loader and parallax rates, so the menu and
## the game can never drift apart on what a background looks like.
class_name MenuBackdrop
extends Control

## Which `background N` folder the title screen stands in, numbered as the folders
## are. Three is the blue-violet night: `Palette.INVERSION_TINTS` records it as the
## one sky the gold of time survives against, and the title is that gold.
const THEME := 3

## How far the pan carries the city either side of centre, in px, and how long one
## round trip takes. Slow enough to read as drifting air rather than as travel.
const PAN := 120.0
const PAN_PERIOD := 40.0

var _layers: Array[BackdropLayer] = []
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var textures := Backdrop.load_layer_textures(
		"%s/background %d" % [Backdrop.BG_ROOT, THEME])
	if textures.is_empty():
		push_error("MenuBackdrop: no art in background %d" % THEME)
		return

	var frame := get_viewport_rect().size
	_build_sky(textures[0], frame)

	var fog := Backdrop.fog_colour(textures[0])
	var depth_count := textures.size() - 1
	for i in range(1, textures.size()):
		var t := float(i - 1) / float(maxi(depth_count - 1, 1))
		var layer := BackdropLayer.new()
		layer.texture = textures[i]
		layer.scroll = lerpf(Backdrop.FAR_SCROLL, Backdrop.NEAR_SCROLL, t)
		layer.fog = fog
		layer.fog_alpha = lerpf(Backdrop.FOG_FAR, Backdrop.FOG_NEAR, t)
		add_child(layer)
		# The menu has no terrain, so the skyline stands on the bottom of the frame.
		layer.configure(frame, frame.y)
		_layers.append(layer)

	_build_scrim(frame)


func _process(delta: float) -> void:
	_time += delta
	# Only x moves: `BackdropLayer` latches its vertical datum on the first sync, so
	# a constant y leaves the whole skyline where the art was planted.
	var pan := sin(_time * TAU / PAN_PERIOD) * PAN
	for layer in _layers:
		layer.sync(Vector2(pan, 0.0))


## The painted sky, stretched to the frame behind every parallax depth. Left on
## linear filtering, as `Backdrop` leaves it: the sky is a gradient, not pixel art.
func _build_sky(texture: Texture2D, frame: Vector2) -> void:
	var sky := TextureRect.new()
	sky.texture = texture
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.size = frame
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)


## The veil that holds the city back so the menu can be read over it. Added last,
## so it covers every depth: the room is only ever as bright as the text allows.
func _build_scrim(frame: Vector2) -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(Palette.UI_INK, Palette.UI_SCRIM_ALPHA)
	scrim.size = frame
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
