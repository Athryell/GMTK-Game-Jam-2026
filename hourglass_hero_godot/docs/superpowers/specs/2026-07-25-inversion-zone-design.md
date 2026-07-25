# Inversion Zone — design

Date: 2026-07-25
Status: approved, not yet implemented

## The idea

A region of the level where the hourglass runs backwards. Inside it, sand flows
from the bottom bulb to the top one, so `Game.sand` **rises** instead of
draining — and you die when the **bottom** bulb empties, not the top.

The fiction the player is sold is gravity. The implementation touches no
physics: the player falls, jumps and springs exactly as they always did. Only
the sand changes direction.

## Why this shape, and not a timer that stops

The obvious version of "a zone that helps you" is a zone where the clock pauses
or refills. Both invite camping: the safest play becomes standing still, which
is the opposite of what a game about a draining clock wants.

Inverting the flow removes the incentive instead of policing it. A zone is a
refuel station **and** a trap, depending only on how long you stay. There is no
safe place to stand anywhere in the game, because both ends of the gauge kill —
the zone only changes which end you are falling towards.

This also finishes a model the code already half-implements. `flip_sand()` is
`sand_max - sand + sand_flip_base`: the game has always treated `sand` as the
top bulb and `sand_max - sand` as the bottom one. `HourglassMotion.chambers()`
already returns both bulbs, and `HourglassShape.draw_glass()` already takes both
`chambers` and a `down` vector. The inversion is the second half of a model that
is already there, not a new concept bolted on.

## Architecture

### `Game` keeps sole ownership of the clock

One new query and one changed loop. Nothing else writes `Game.sand`.

```
# _process, while status == PLAY
sand += delta * rate * sand_flow()
die if sand <= 0.0    # normal flow: the top bulb is empty
die if sand >= sand_max  # inverted flow: the bottom bulb is empty
```

`rate` is `sand_drain_rate` when flowing normally and `sand_reverse_rate` when
inverted.

**Rejected:** letting each zone add to `Game.sand` itself every frame, on top of
the existing drain. It works, but then two places decide whether you die, and
the effective speed is `reverse_rate - drain_rate` — a number nobody chose and
nobody can read off a slider. A zone *declares* a direction; `Game` applies time
and `Game` kills.

### `Game` asks; zones never push

```gdscript
## -1 while the player stands in an inversion zone, +1 otherwise.
func sand_flow() -> float:
	for zone in get_tree().get_nodes_in_group(INVERSION_GROUP):
		if zone.contains_player():
			return -1.0
	return 1.0
```

Zones join the group `inversion_zones` from the scene file. Group membership is
managed by the scene tree, so unloading a level deregisters every zone for free
and no stale entry can survive a restart.

**Rejected:** a registry that zones write themselves into on `_ready` and remove
themselves from on exit. It has a real failure mode — dying or reloading inside
a zone does not guarantee the removal runs, and the game would stay inverted
forever. The group query has no state to corrupt.

Overlapping zones do not stack: one containing zone is enough, and the flow is
either inverted or it is not.

### `InversionZone extends PlaneArea`

It inherits the entity contract already shared by spikes, springs, doors and
monsters: `size`, `plane`, `_active`, `_shade()`, `_apply_size()`, a light set
in `_init`, and the origin at the **top-left corner** of `size`.

`PlaneArea` was built for a momentary trigger — `body_entered` fires once and
calls `_touched()`. Containment is a continuous state, so `InversionZone` does
not use `_touched()` at all:

```gdscript
func contains_player() -> bool:
	return _active and has_overlapping_bodies()
```

The area's collision mask is `Layers.PLAYER`, so any overlapping body is the
player; no reference to the player is needed. `PlaneArea._on_plane_changed()`
already sets `monitoring = _active`, so a zone in the other plane reports no
overlaps and the plane rule falls out for free with nothing written.

Godot updates overlap lists on the physics frame, so a `_process` read is at
most one frame behind. At 1000 ms of sand per second, one frame is 16 ms of
sand — below anything a player can perceive or a test needs to assert.

### `danger()` must measure the death that is active

Today `danger()` only watches the bottom: `sand < sand_warn`. Left alone, you
would enter a zone and the gauge would report "all clear" while you climbed
towards your death.

It becomes a measure of proximity to *whichever* end currently kills:

- flowing normally, closeness to `0`
- flowing inverted, closeness to `sand_max`

This is a one-place fix on purpose. `Palette.sand(danger)` is documented as
"three readings of one clock, which must never disagree" — the sprite, the HUD
gauge and the light the player carries all derive from it. Fixing `danger()`
turns all three around together; patching the HUD would split them.

`sand_warn` is reused unchanged as the width of the warning band at either end.

### The flip is already the escape hatch

Nothing to implement. Inside a zone, danger is `sand` near `sand_max`, and
`flip_sand()` returns `sand_max - sand + sand_flip_base` ≈ `sand_flip_base` —
near zero, which is maximum safety *inside* the zone and instant death outside
it. The panic button keeps working in both regimes, for exactly opposite
reasons. That inversion of meaning is the mechanic, not a side effect.

## Visuals

Two parts, and the second is nearly free.

**The glass.** `motion.down()` is a single vector both drawing sites already
consume. Flipping it while inverted should pool the sand at the top of each bulb
and run the trickle upward. This is stated as the intended approach, not as a
verified fact: it will be rendered in-engine and confirmed before being relied
on. If the shape function turns out to derive anything else from `down`, the
fallback is an explicit `up` flag threaded through `draw_glass`.

**The zone itself.** It must read as a region, not as an object, and it must not
invent a fifth hue — `palette.gd` budgets four families and says so. The zone is
a *time* thing, so it takes the WARM/gold family, but distinguished by treatment
rather than by colour: a large, low-saturation translucent field with a defined
boundary, against the small bright solids the gold family is otherwise spent on
(door, flip-pad). A player must never mistake a zone for something to collect.

Exact rendering is left to implementation and will be judged in-engine, in the
shipping renderer, since every visual in this game is `_draw()` primitives.

## Tuning

One new value in `game_config.gd`:

```gdscript
@export_range(0.0, 5000.0, 10.0) var sand_reverse_rate: float = 1000.0
```

Default equals `sand_drain_rate`, which makes the two directions symmetric. That
symmetry is already latent in the existing numbers: `sand_start` is 3000 of
`sand_max` 6000, exactly half, so you enter a zone with 3 seconds of headroom in
either direction. Sand is measured in milliseconds and drains at 1000/s, so the
gauge is a literal clock in both directions.

## Level 13 — "The Updraft"

`scenes/levels/level_13_the_updraft.tscn`. `Game._discover_levels()` scans the
folder and sorts by filename, so the file registers itself with nothing to wire.

The level teaches one sentence: **a zone refuels you, and kills you if you
overstay.** Three beats, in order:

1. **See it.** A zone crossed in passing, wide open, with the exit reachable far
   inside the time. The gauge visibly runs the wrong way. Nothing is at stake.
2. **Want it.** A stretch long enough to arrive nearly empty, ending in a zone.
   Here the inversion is purely a gift: entering with low sand is *good*, and
   the player learns to aim for one.
3. **Fear it.** A chamber where the only way on needs a full glass, so the
   player must sit in a zone to fill up and leave before it kills them. The
   flip is available as the panic button, at the cost of arriving empty.

Beat 2 before beat 3 matters: the player should learn the zone is desirable
before they learn it is lethal, or they will simply avoid every zone in the
game.

## Testing

All in `tests/sand_test.gd`, headless. Each assertion will be shown to **fail**
against the current code before the fix lands, the same way the camera
regression was proven.

- Standing in a zone raises `sand` instead of lowering it.
- Reaching `sand_max` inside a zone sets `Status.DEAD`.
- A zone in the other plane does nothing: `sand` still drains.
- Leaving a zone resumes draining.
- `danger()` reports the top end while inverted and the bottom end while normal.
- Two overlapping zones invert once, not twice.

`smoke_test` gets level 13 for free — it walks every discovered level.

## Out of scope

- Any change to gravity, jump height, fall speed or movement. "Gravity" is the
  fiction; nothing in `player.gd` is touched.
- Zones that alter the *rate* without reversing it, or that ramp over time.
- Audio for entering or leaving a zone.
