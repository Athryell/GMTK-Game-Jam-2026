## Back-and-forth motion for moving platforms and patrolling monsters. Derived
## from elapsed time, not accumulated per frame, so it never drifts.
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


## Offset from the start at time `elapsed`: 0 to `distance` and back, repeating.
static func offset(elapsed: float, distance: float, speed: float) -> float:
	if distance <= 0.0 or speed <= 0.0:
		return 0.0
	var half := distance / speed # time for one leg
	var t := fmod(elapsed, half * 2.0)
	return t * speed if t <= half else distance - (t - half) * speed


## The offset projected onto `axis`. `phase` shifts the start along the cycle;
## all movers share one clock, so equal-period entities are otherwise in step.
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
