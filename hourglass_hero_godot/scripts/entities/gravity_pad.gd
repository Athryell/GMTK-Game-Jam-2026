@tool
## A pad that turns the world over: touch it and gravity pulls the way its
## arrows point, until another pad says otherwise.
##
## It SETS a direction rather than toggling one. That is the whole reason it is
## safe to stand on: a toggle would flutter the world every time you brushed it,
## and two pads facing the same way would cancel instead of agreeing. A pad you
## are already obeying does nothing, and says so by going dim.
##
## Nothing about the sand changes. The glass still drains, a jump still refuels
## and still turns you a plane — the ceiling is simply where you land now. That
## keeps it composable: any level can gain one without its timing being redone.
##
## The node's origin is the TOP-LEFT corner of `size`, like every other solid.
## The pad mounts on the surface OPPOSITE its arrows: one that pulls up sits on
## a floor, one that pulls down hangs from a ceiling.
class_name GravityPad
extends PlaneArea

## Foot slab, as a fraction of the pad's height.
const FOOT := 0.22
## Arrows stacked between the foot and the open end.
const CHEVRONS := 2
const CHEVRON_WIDTH := 3.0
## Inset of each arrow from the pad's ends, as a fraction of its width.
const CHEVRON_INSET := 0.18
## Seconds the pad stays lit after it has fired.
const FLASH_TIME := 0.45

## Which way this pad makes the world pull. Up sends you to the ceiling.
@export var pulls_up := true: set = _set_pulls_up

## 1 the instant it fires, decaying back to 0.
var _flash := 0.0
## False while the world already pulls the way this pad points: it has nothing
## left to give, and is drawn as spent.
var _armed := true


func _init() -> void:
	# Same footprint as the spring — both are pads you run over, and a shared
	# size is what lets an author swap one for the other without re-measuring.
	size = Vector2(56.0, 16.0)
	# The mint of the spring, deliberately: the hue budget spends gold on time
	# and red on danger, and this is the spring's family — the world moves you,
	# and it costs no sand.
	light_tint = Palette.SPRING
	light_radius = 140.0
	light_energy = 0.9


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	Game.gravity_changed.connect(_on_gravity_changed)
	_on_gravity_changed(Game.gravity_sign)


func _process(delta: float) -> void:
	if _flash <= 0.0:
		return
	_flash = maxf(0.0, _flash - delta / FLASH_TIME)
	queue_redraw()


func _touched(_player: Player) -> void:
	Game.set_gravity(-1.0 if pulls_up else 1.0)
	_flash = 1.0
	queue_redraw()


func _on_gravity_changed(sign: float) -> void:
	_armed = (sign > 0.0) == pulls_up
	queue_redraw()


## A foot on the surface it is bolted to, and arrows pointing where you are
## about to go. Spent pads keep the silhouette and lose the light, so the shape
## still reads as a pad and the colour tells you it has nothing to offer.
func _draw() -> void:
	var colour := _shade(Palette.SPRING)
	if not _armed:
		colour = colour.darkened(0.45)
	colour = colour.lerp(Color.WHITE, _flash * 0.8)

	var foot := maxf(3.0, size.y * FOOT)
	draw_rect(Rect2(Vector2(0.0, minf(_from_foot(0.0), _from_foot(foot))),
		Vector2(size.x, foot)), colour.darkened(0.5))

	var inset := size.x * CHEVRON_INSET
	var slot := (size.y - foot) / float(CHEVRONS)
	for i in CHEVRONS:
		# The far arrow is the faint one, so the stack reads as a direction and
		# not as a ladder.
		var fade := colour
		fade.a *= lerpf(1.0, 0.45, float(i) / maxf(CHEVRONS - 1.0, 1.0))
		var base := _from_foot(foot + slot * i)
		var tip := _from_foot(foot + slot * (i + 1))
		draw_polyline([
			Vector2(inset, base),
			Vector2(size.x / 2.0, tip),
			Vector2(size.x - inset, base)], fade, CHEVRON_WIDTH)


## Screen-y `offset` px from the mounted edge, measured along the arrows. Every
## piece of the drawing is placed through this, so the two orientations are one
## drawing seen from either end rather than two that can drift apart.
func _from_foot(offset: float) -> float:
	return size.y - offset if pulls_up else offset


func _set_pulls_up(value: bool) -> void:
	pulls_up = value
	queue_redraw()
