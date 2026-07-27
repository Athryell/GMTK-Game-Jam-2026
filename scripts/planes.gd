## The level's superimposed planes, one per chamber of its glass. Every entity
## belongs to one or to all; the player moves to the next plane on every jump,
## and only the current one is solid.
class_name Planes
extends RefCounted

enum Kind {
	P0, ## The plane a level opens in.
	P1,
	P2, ## Only reached on a three-chamber level or better.
	P3, ## Only reached on a four-chamber level.
	BOTH, ## Present in every plane (shared floor, walls).
}

## The most planes a level may use. `BOTH` is not one of them — it sits after the
## real planes precisely so that `int(kind) < COUNT` means "a real plane".
const COUNT := 4


## Is an entity in plane `kind` active while the player is in `current`?
static func is_active(kind: Kind, current: Kind) -> bool:
	return kind == Kind.BOTH or kind == current


## Where `kind` lands after `steps` turns of a glass with `count` chambers.
## Negative steps turn the other way. `BOTH` is everywhere, so it never moves.
static func step(kind: Kind, steps: int, count: int) -> Kind:
	if kind == Kind.BOTH or count <= 0:
		return kind
	return posmod(int(kind) + steps, count) as Kind
