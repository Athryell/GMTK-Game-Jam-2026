# Game Design Document

## Jam theme

COUNTDOWN.

## Concept

A kid wants a cookie from the kitchen jar, but mom does not allow it.
Mom leaves the house at 5PM and comes back at 7PM. Within that window
the kid must reach the kitchen, grab a cookie, and get back to his
room undetected.

Grabbing the cookie starts a second countdown: the kid must undo his
own path exactly, action by action, in reverse. If he fails either
countdown, mom notices (catches him out of his room, or finds the
missing cookie) and the run is lost.

The whole game is one mechanic: perform a sequence forward, then
recall and invert it under time pressure.

## Core loop

1. **Forward phase**: explore a randomized house (room graph) to
   find the kitchen, choosing a door (direction) in each room.
2. Grab the cookie in the kitchen.
3. **Backward phase**: retrace the exact path taken, in reverse
   order, using the opposite direction for each step, before time
   runs out.

## Forward phase

- The house is a graph of rooms connected by doors on 4 sides
  (up/down/left/right). Layout is randomized per run so no persistent
  "meta-map" can be learned across sessions.
- The player picks a direction each time they enter a room. There is
  no other hint system (no proximity glow, no audio cue) — the only
  information available comes from actually seeing the room.
- **Dead ends are part of the design, not a punishment to avoid
  entirely**: entering a wrong room and backing out appends *both*
  moves (enter direction + exit direction) to the sequence the player
  will later have to reverse. Careless/rushed exploration directly
  inflates the difficulty of the backward phase. This is the only
  stakes system tying the two phases together — no separate noise or
  health meter needed.

### Light mechanic (forward only)

- The kid has a flashlight/lamp with a visibility radius: a circle of
  light centered on the kid, showing the current room (and only the
  current room).
- The radius shrinks over a **separate, shorter timer** than the
  forward phase's overall countdown (e.g. forward phase ~20-25s,
  light lasts less than that). Once depleted, the radius bottoms out
  at roughly the kid's own size — barely enough to see himself.
- The light provides **no explicit hint** (no glowing doors, no
  directional signal). It only controls how much of the room the
  player can actually see and read (props, room type, layout) to make
  an informed guess about which door to take.
- Effect: early exploration is easier to reason about (wide visibility
  gives real information), later exploration becomes a blind gamble
  (small/no visibility). This rewards moving quickly and decisively,
  without any bespoke hint-generation system — just a shrinking vision
  mask.

## Backward phase

- Full visibility, but **only of the room the kid is currently in** —
  no glimpses of adjacent rooms, no lookahead. This is what keeps the
  challenge honestly about memory rather than re-derivable from the
  environment.
- No light mechanic, no hints of any kind.
- The player must recall, in reverse order, the exact sequence of
  directions taken forward (including any dead-end detours) and press
  the **opposite** direction for each step (e.g. entered a room via
  "right" forward -> must exit via "left" backward).
- Same overall time budget as the forward phase.

## Timing & pacing (starting point, to tune via playtesting)

- Forward: ~20-25s. Backward: ~20-25s. Total run: ~45-50s.
- Target total sequence length (successful moves + dead-end
  backtracks): **6-10 direction inputs**. Enough for a house with
  real branching, capped so recall stays achievable — spatial/motor
  sequences that the player physically performed hold up better under
  recall than raw digit-span, but pressure + time limits erode that
  margin, so avoid growing the sequence past this range.
- Original tighter budget (15s/15s, 30s total) was found too short to
  produce a house with genuine branching once visibility per phase
  was decided; timings were loosened accordingly.

## Rejected alternatives (kept for context)

- **Free exploration with a full house map** (multi-floor house,
  fixed layout): rejected because a fixed layout becomes trivially
  memorizable across sessions (players learn "room 3 is always the
  box room"), removing the in-run memory challenge.
- **Wide-open flashlight exploration** (see far in the direction
  pointed, depleting over the whole run): rejected early on because
  it drifted away from the "repeat actions backward" concept and gave
  the backward phase no clear role.
- **Door-glow / proximity hint toward the kitchen** (sound or light
  cue indicating the correct direction): rejected because any hint
  that also works in reverse (pointing toward the bedroom on the way
  back) would let the player just follow the cue instead of
  remembering anything, defeating the point of the backward phase.
- **Discrete mini-actions per room** (climb over a box, open a
  drawer, sneak past a floorboard, etc.): considered, but rejected in
  favor of keeping the core mechanic purely about directional
  movement — remembering both the order of rooms and the direction
  used to enter each one.
- **Noise/attention meter as a mistake-forgiveness system**:
  considered, but the dead-end-appends-to-sequence rule already
  provides consequences for mistakes without adding a new system, so
  it was dropped in favor of scope.

## MVP implementation (current state)

Tech stack: plain HTML/CSS + vanilla JS (ES modules), no build step,
no engine. Chosen for zero setup and instant playability given no
platform/engine had been picked yet. Files:

- `index.html` — page shell, layout, styling.
- `src/house.mjs` — pure house-generation logic (no DOM).
- `src/game.mjs` — game loop, input, rendering, DOM wiring.
- `tests/house.test.mjs` — generates 500 houses and asserts the
  invariants below (run with `node tests/house.test.mjs`).

Run locally with a static server from the project root, e.g.
`python3 -m http.server 8000` then open `http://localhost:8000`.
Opening `index.html` directly via `file://` will not work — browsers
block ES module imports from the local filesystem.

### Room types, colors, counts

| Type         | Color   | Max | Entrances |
|--------------|---------|-----|-----------|
| Kid's room   | grey    | 1   | 1 (start) |
| Kitchen      | pink    | 1   | 1 (goal)  |
| Bathroom     | blue    | 5   | 1         |
| Bedroom      | green   | 5   | 1         |
| Studio       | purple  | 2   | 1         |
| Dining room  | white   | 2   | 4         |
| Living room  | red     | 2   | 4         |
| Hallway      | brown   | 4   | 4         |

Studio's entrance count/color were not specified in the brief; it was
assumed to behave like bathroom/bedroom (dead end, 1 entrance) with
purple as a placeholder color. Flag if it should instead be a 4-door
connector room.

### Generation algorithm

The house is generated as a tree, not a general graph: a chain of
"hub" rooms (dining/living/hallway — always exactly 4 real doors) runs
from the kid's room to the kitchen, and every hub has 2 of its
remaining sides filled with dead-end decoy rooms (bathroom/bedroom/
studio — always exactly 1 real door). This produces branching paths
without needing degree-2/3 rooms, which the given room set doesn't
support (every type is either always-1-door or always-4-door).

Chain length is randomized between **2 and 4 hubs** (down from an
initial 4-6, which produced houses that felt too large — 14 to 20
rooms total). At 2-4 hubs, total rooms range **8-14**, and the true
(no-detour) path length is **3-5 moves**. Hub count is capped so decoy
demand (2 per hub) never exceeds the total decoy room budget
(5+5+2 = 12); the current range is well under that ceiling.

### Cookie grab / timer symmetry

Grabbing the cookie is automatic and immediate on entering the
kitchen room (no separate "grab" action or confirmation), specifically
to prevent the player from idling in the kitchen to mentally rehearse
the reversal before the backward countdown starts. The backward phase
timer is set to exactly however long the forward phase took (measured
at the instant the kitchen is entered), not a fixed value — so faster,
more efficient forward play is rewarded with a shorter (but exactly
matched) backward window.

### Light mechanic (as implemented)

Since only the current room is ever rendered (no house map), the
"shrinking light circle" is implemented as: while in the forward
phase, each real door shows the color of the room behind it, fading
toward a bare outline over a separate 10s light timer (shorter than
the 25s forward phase limit). Once depleted, doors still show an
outline (so the player knows a direction is a real door) but no
longer reveal what's behind it. Backward phase never reveals door
colors, regardless of the (unused) light timer, per the "no hints
when reversing" rule — matching the design intent without needing an
actual 2D spatial/fog-of-war renderer.

### Wrong-turn handling (assumption)

Hub rooms always have all 4 sides real, so during the backward phase
a wrong-but-real direction is a genuine wrong turn, not a wall bump.
This MVP treats any such wrong turn as an instant loss ("mom notices"),
rather than letting the kid actually walk into the wrong room and
attempt to recover. Simplest option and consistent with "must retrace
exactly" — reconsider if a softer failure state is wanted later.

## Open questions / not yet decided

- Confirm studio's entrance count/color (see assumption above).
- Confirm wrong-turn-during-backward should be an instant loss, not a
  recoverable mistake (see assumption above).
- Exact timer numbers (25s forward cap, 18s light) are untuned
  defaults — adjust after playtesting.
- With hub count reduced to 2-4, the true (no-detour) path is now
  3-5 moves, trending below the original 6-10 total-sequence target
  from the design section above unless the player takes 1-2 dead-end
  detours. Revisit if runs feel too short/easy once playtested.
- Touch/mobile input (currently keyboard + click only).
- Win/lose presentation polish (sound, animation, actual mom sprite,
  etc. — currently just text + a color-coded HUD).
- Whether decoy branches should ever be more than one room deep
  (currently every wrong turn is an immediate dead end, not a false
  path with its own further choices).
