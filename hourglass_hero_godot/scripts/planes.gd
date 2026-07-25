## The level's two superimposed planes. Every entity belongs to one or both; the
## player alternates FRONT/BACK on every jump, and only the current plane is solid.
class_name Planes
extends RefCounted

enum Kind {
	FRONT, ## Foreground — bright colours.
	BACK, ## Background — cool colours.
	BOTH, ## Present in both planes (shared floor, walls).
}


## Is an entity in plane `kind` active while the player is in `current`?
static func is_active(kind: Kind, current: Kind) -> bool:
	return kind == Kind.BOTH or kind == current


static func opposite(kind: Kind) -> Kind:
	return Kind.BACK if kind == Kind.FRONT else Kind.FRONT
