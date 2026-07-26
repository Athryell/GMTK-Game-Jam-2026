@tool
## Monster: patrols along an axis and kills on contact, within its own plane only.
##
## Drawn as a clock, with a hand going round. The thing chasing you in a game
## about running out of time should look like the clock it is.
class_name Monster
extends PlaneArea

const FACE: Texture2D = preload("res://art/sprites/clock.png")

## The art is a 64×64 dial, and the hand is struck from measurements taken off
## it rather than guessed at, so retracing the sprite is the only thing that can
## put them out of step.
const ART_SIZE := 64.0
## The gold hub the hand turns on — dead centre, as it happens.
const ART_PIVOT := Vector2(32.0, 32.0)
## The hour ticks run from radius 12 out to 19. Stopping at 14 puts the tip just
## inside the ring, which is where a clock's own hand stops.
const ART_REACH := 14.0
const ART_WIDTH := 4.0

## Seconds for one full sweep, clockwise from twelve.
const HAND_PERIOD := 0.55

@export_group("Patrol")
@export var move_axis: PingPong.Axis = PingPong.Axis.X
## Patrol travel, in px, from the editor-placed position.
@export_range(0.0, 800.0, 1.0) var move_distance := 90.0
## Patrol speed, in px/s.
@export_range(0.0, 400.0, 1.0) var move_speed := 115.0
## Start offset in the cycle. All movers share one clock, so equal-period
## entities are locked in step at 0.
@export_range(0.0, 1.0, 0.05) var move_phase := 0.0

var _origin := Vector2.ZERO
var _elapsed := 0.0
## Where the hand has got to, in radians clockwise from twelve.
var _hand := 0.0


func _init() -> void:
	# Square, and exactly [constant ART_SIZE], so the dial is drawn one art px to
	# one world px like every other texture. Anything smaller shrinks the clock's
	# pixels below the brick ones it stands on.
	size = Vector2(ART_SIZE, ART_SIZE)
	plane = Planes.Kind.P0
	light_tint = Palette.MONSTER
	light_radius = 105.0
	# Kept low deliberately: at any strength the red wash swallows the clock face
	# and the hand along with it. Enough glow to be seen coming in the dark, not
	# enough to repaint what it is lighting.
	light_energy = 0.2


func _ready() -> void:
	_origin = position
	# The dial is pixel art at one art px to one world px; see `terrain.gd` for
	# why this is per-node rather than a project default.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	super()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	# Before the patrol guard, not after: a monster told to hold still is still a
	# clock, and its hand still has to go round.
	_hand = fmod(_hand + delta * TAU / HAND_PERIOD, TAU)
	queue_redraw()
	if move_axis == PingPong.Axis.NONE or move_speed <= 0.0:
		return
	_elapsed += delta
	position = _origin + PingPong.offset_vector(
		move_axis, _elapsed, move_distance, move_speed, move_phase)


func _touched(_player: Player) -> void:
	Game.kill()


## The dial, then the hand over it.
##
## Drawn SQUARE and centred on the hitbox rather than stretched to fill it. The
## art is a circle, so filling a rect that is not square turned the clock into an
## egg. At the default `size` the two are the same thing; this only matters if a
## level resizes one. The square takes the hitbox's longer side, so it still
## covers everything that can kill you — erring towards a clock whose edge you
## can brush without dying, rather than one that kills from a gap you can see
## through.
##
## Resizing a monster at all breaks the one-art-px-to-one-world-px rule the rest
## of the game keeps, and its pixels stop matching the brick behind it.
func _draw() -> void:
	var span := maxf(size.x, size.y)
	var face := Rect2((size - Vector2(span, span)) * 0.5, Vector2(span, span))
	# White modulate is the sprite's own colours untouched; out of plane `_shade`
	# takes the alpha down and ghosts the whole dial at once.
	draw_texture_rect(FACE, face, false, _shade(Color.WHITE))

	# Struck last, so it sweeps over the dial rather than under it. One scale for
	# both axes now the dial is round, so the tip keeps to the ring of ticks the
	# whole way round.
	#
	# The danger red the rest of the monster is lit in, rather than a red of its
	# own: the hand is the part of the clock that is coming for you, and it costs
	# no hue to say so.
	var pivot := face.position + face.size * 0.5
	draw_line(pivot, pivot + Vector2.UP.rotated(_hand) * (span * ART_REACH / ART_SIZE),
		_shade(Palette.MONSTER),
		maxf(span * ART_WIDTH / ART_SIZE, 1.0), true)
