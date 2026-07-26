# Why Sandbound works the way it does

Reference for the systems behind the game. For how to build a level, see
[LEVELS.md](LEVELS.md).

## Architecture

Two ideas hold the code together:

- **Nobody talks to anybody directly.** `Game` owns the run state and emits
  `plane_changed` / `next_plane_changed` / `status_changed` / `level_loaded`;
  entities and the HUD listen. Adding an entity type means writing one script.
- **Plane switching is one uniform rule.** On `plane_changed`, every entity asks
  `Planes.is_active(plane, current)` and either leaves the physics layer
  (solids) or stops monitoring (areas), then redraws as a ghost.

## The sand economy

The glass carries one bulb of sand per turn it takes to get a drained bulb back
on top — one at two and three chambers, two at four, where the sand lands
opposite. The top always opens at `sand_start`, so the runway before the first
turn is the same everywhere; the count only changes what comes back. Three
chambers split every drain in two and hand back only the half you turn into.

`sand_flip_base` is 0, so on a two-chamber glass a turn gives back exactly
`max - sand`: an involution. Two turns return you to your starting plane **and**
your starting sand, so a double jump is pure height and pure time — free while
you are full, ruinous while you are empty. `sand_test.gd` guards the identity.

## How the sand moves

The sand is a liquid, not a block glued inside the glass. `HourglassMotion`
works out `down` — where gravity points *in the glass's own frame* — and
`HourglassShape` cuts every free surface square to it, bisecting for the cut
that leaves exactly the right area below. Tip the glass and the sand pools in
whatever corner is lowest.

- **The neck gates the sand.** Each bulb keeps its own contents mid-tumble,
  which is why a real hourglass laid on its side does not empty.
- **A flip lands seamlessly: the bulbs are each other turned half a turn.**
  The glass snaps from π back to 0, and at that same instant `chambers()` swaps
  which bulb holds what. The two cancel exactly; `sand_test.tscn` guards it.
- **There is one glass, drawn twice.** The sprite and the HUD gauge both read
  the single `HourglassMotion` held by the `Glass` autoload, so they cannot
  drift.

## Gravity

Gravity is a pad you place, not a level rule, so any level can gain one without
being rebuilt. Underneath it is one signed number, `Game.gravity_sign`: every
vertical quantity is a downward component times that sign, so an upside-down
world runs the same arithmetic as every other.

A pad SETS a direction and never toggles one. That is what makes it safe to
stand on and lets two pads facing the same way agree instead of cancelling.
Every level starts the right way up.

## Light and shadows

`CanvasModulate` sits the world at `world_light` and every light adds back on
top. The glass carries the only one that casts: `CastShadows` gives each solid
a `LightOccluder2D` built from the outline it is drawn from, parented to the
caster so a moving platform drags its shadow along. A solid in another plane is
walk-through, so it stops casting.

The result is subtractive — nothing is painted over the world, the lamp simply
does not arrive behind a wall — so two shadows crossing are no darker than one.
Occluders are inset a few px inside their solid: Godot's shadow map darkens
everything past the first surface a ray meets, the caster included, so an
outline sitting exactly on the drawn surface bands along its own lit face.
