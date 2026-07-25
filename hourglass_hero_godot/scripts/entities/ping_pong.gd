## Back-and-forth motion, shared by moving platforms and patrolling monsters.
##
## The offset is derived from elapsed time rather than accumulated frame by
## frame: no drift, and a re-placed entity lands exactly where it should.
class_name PingPong
extends RefCounted

enum Axis {
	NONE, ## Stationary.
	X, ## Horizontal back-and-forth.
	Y, ## Vertical back-and-forth.
}


## Seconds for a full there-and-back. 0 when the entity does not move.
static func cycle(distance: float, speed: float) -> float:
	if distance <= 0.0 or speed <= 0.0:
		return 0.0
	return distance * 2.0 / speed


## Offset from the starting position at time `elapsed`. Starts at 0, climbs to
## `distance`, comes back, and repeats.
static func offset(elapsed: float, distance: float, speed: float) -> float:
	if distance <= 0.0 or speed <= 0.0:
		return 0.0
	var half := distance / speed # time for one leg
	var t := fmod(elapsed, half * 2.0)
	return t * speed if t <= half else distance - (t - half) * speed


## The offset projected onto the requested axis.
##
## `phase` shifts the start along the cycle, as a fraction of a full there-and-
## back. Every mover derives its position from the same clock, so without it two
## entities of equal period are locked in step forever — which is exactly what
## "Metronome" needs to break, and is not something a level author can fake by
## nudging positions.
static func offset_vector(axis: Axis, elapsed: float, distance: float, speed: float,
		phase := 0.0) -> Vector2:
	var t := elapsed + phase * cycle(distance, speed)
	match axis:
		Axis.X:
			return Vector2(offset(t, distance, speed), 0.0)
		Axis.Y:
			return Vector2(0.0, offset(t, distance, speed))
		_:
			return Vector2.ZERO
