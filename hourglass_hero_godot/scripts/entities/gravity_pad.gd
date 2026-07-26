@tool
## A pad that turns the world over: touch it and gravity pulls the way its
## arrows point, until another pad says otherwise.
##
## It SETS a direction rather than toggling one, so standing on it is safe and
## two pads facing the same way agree instead of cancelling. Nothing about the
## sand changes. Mounts on the surface OPPOSITE its arrows.
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
## False while the world already pulls this way: drawn as spent.
var _armed := true


func _init() -> void:
	# Same footprint as the spring, so one can be swapped for the other.
	size = Vector2(56.0, 16.0)
	# The spring's family: the world moves you, and it costs no sand.
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


## Read `_armed` first: `set_gravity` clears it through `gravity_changed` on the
## same call. A spent pad still flashes — you did touch it — but it stays silent,
## because nothing turned over.
func _touched(_player: Player) -> void:
	if _armed:
		Audio.sfx("gravity_up" if pulls_up else "gravity_down")
	Game.set_gravity(-1.0 if pulls_up else 1.0)
	_flash = 1.0
	queue_redraw()


func _on_gravity_changed(sign: float) -> void:
	_armed = (sign > 0.0) == pulls_up
	queue_redraw()


## A foot on the surface it is bolted to, and arrows pointing where you are
## about to go. Spent pads keep the silhouette and lose the light.
func _draw() -> void:
	var colour := _shade(Palette.SPRING)
	if not _armed:
		colour = colour.darkened(0.45)
	colour = colour.lerp(Color.WHITE, _flash * 0.8)

	var foot := maxf(3.0, size.y * FOOT)
	# The slab only; the chevrons above it are painted on the air.
	var foot_box := Rect2(Vector2(0.0, minf(_from_foot(0.0), _from_foot(foot))),
		Vector2(size.x, foot))
	Outline.rect(self, foot_box, colour.a)
	draw_rect(foot_box, colour.darkened(0.5))

	var inset := size.x * CHEVRON_INSET
	var slot := (size.y - foot) / float(CHEVRONS)
	for i in CHEVRONS:
		# The far arrow is the faint one: a direction, not a ladder.
		var fade := colour
		fade.a *= lerpf(1.0, 0.45, float(i) / maxf(CHEVRONS - 1.0, 1.0))
		var base := _from_foot(foot + slot * i)
		var tip := _from_foot(foot + slot * (i + 1))
		draw_polyline([
			Vector2(inset, base),
			Vector2(size.x / 2.0, tip),
			Vector2(size.x - inset, base)], fade, CHEVRON_WIDTH)


## Screen-y `offset` px from the mounted edge, measured along the arrows. The
## whole drawing goes through this, so the two orientations cannot drift apart.
func _from_foot(offset: float) -> float:
	return size.y - offset if pulls_up else offset


func _set_pulls_up(value: bool) -> void:
	pulls_up = value
	queue_redraw()
