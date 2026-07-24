/*
 * engine.js — pure game logic for Hourglass Hero.
 *
 * No DOM, no Canvas: everything here is deterministic and unit-testable.
 * Exposed as `HH` on window (browser) and module.exports (node tests).
 *
 * Signature mechanic: a jump does three things at once — it flips the hourglass
 * (recharging sand by a pure swap), it swaps the player between the front and
 * back plane, and it applies the upward impulse. Two designed elements bend
 * that coupling: a SPRING bounces you without flipping, and a FLIP-PAD swaps
 * the sand without a jump or a plane change.
 */

// ----- Gameplay constants (source of truth) --------------------------------
const C = {
  WORLD_W: 960,
  WORLD_H: 540,

  GRAVITY: 2200, // px/s^2
  MOVE_SPEED: 260, // px/s
  JUMP_V: -760, // px/s (full upward impulse)
  JUMP_CUT_V: -280, // px/s: rising speed is capped to this once jump is released

  COYOTE: 0.09, // s: grace window to still jump just after leaving a ledge
  JUMP_BUFFER: 0.12, // s: a jump pressed just before landing still fires

  SAND_MAX: 6000, // ms: total sand in the hourglass (a full side)
  SAND_START: 3000, // ms on top at level start — half, so flips self-stabilise
  SAND_WARN: 2000, // ms threshold for the "running out" warning colour
  // Pure hourglass swap: a flip gives back exactly the drained sand (base 0).
  SAND_FLIP_BASE: 0,

  MAX_DT: 1 / 30, // clamp large frame gaps (tab refocus) to avoid tunnelling
  FLIP_DUR: 0.5, // seconds the 180° flip animation lasts
};

// ----- Small pure helpers (unit-tested directly) ---------------------------

// Axis-aligned bounding box overlap.
function aabbOverlap(a, b) {
  return a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y;
}

// Flipping the hourglass: the sand that has already drained becomes the sand
// available on the new side (drained = max - sand). Waiting longer (sand near
// 0) yields a near-full refill; flipping early (sand near max) leaves you
// little — the heart of the timing game. `base` is a floor for softer modes.
function flipSand(sand, sandMax, base = 0) {
  const flipped = sandMax - sand + base;
  if (flipped < 0) return 0;
  if (flipped > sandMax) return sandMax;
  return flipped;
}

// Is a level entity present in the plane the player currently occupies?
function inPlane(entity, plane) {
  return entity.plane === 'both' || entity.plane === plane;
}

function otherPlane(plane) {
  return plane === 'front' ? 'back' : 'front';
}

// ----- World construction --------------------------------------------------

// Deep-copy a level definition into a fresh mutable world state.
function createWorld(level) {
  const clone = (arr) => (arr || []).map((o) => ({ ...o, move: o.move ? { ...o.move } : undefined }));
  return {
    name: level.name,
    width: level.width || C.WORLD_W,
    solids: clone(level.solids), // may carry kind:'spring'|'flip' and power
    monsters: clone(level.monsters),
    door: { ...level.door, plane: level.door.plane || 'both' },
    player: {
      x: level.spawn.x,
      y: level.spawn.y,
      w: 26,
      h: 38,
      vx: 0,
      vy: 0,
      onGround: false,
      jumping: false, // true mid-jump; gates the variable-height cut
      plane: 'front',
      standing: null,
    },
    sand: C.SAND_START,
    sandMax: C.SAND_MAX,
    time: 0,
    status: 'play', // 'play' | 'dead' | 'win'
    justFlipped: 0, // seconds remaining on the flip animation cue
    flipDir: 1, // rotation sense of the flip animation (set from travel dir)
    padFlash: 0, // seconds remaining on the flip-pad recharge cue
    coyote: 0,
    jumpBuffer: 0,
  };
}

// ----- Moving entities ------------------------------------------------------

// Advance a patrolling/moving entity along its axis, bouncing at the bounds.
// Records the frame delta on `_dx`/`_dy` so riders can be carried along.
function moveEntity(e, dt) {
  e._dx = 0;
  e._dy = 0;
  if (!e.move) return;
  const m = e.move;
  const axis = m.axis; // 'x' | 'y'
  const before = e[axis];
  let next = before + m.speed * m.dir * dt;
  if (next > m.max) {
    next = m.max;
    m.dir = -1;
  } else if (next < m.min) {
    next = m.min;
    m.dir = 1;
  }
  e[axis] = next;
  if (axis === 'x') e._dx = next - before;
  else e._dy = next - before;
}

// The shared "a jump happened" effect: swap plane + flip sand + impulse + cue.
function doJump(world) {
  const p = world.player;
  p.vy = C.JUMP_V;
  p.onGround = false;
  p.standing = null;
  p.jumping = true;
  p.plane = otherPlane(p.plane);
  world.sand = flipSand(world.sand, world.sandMax, C.SAND_FLIP_BASE);
  world.justFlipped = C.FLIP_DUR;
  // Tumble according to travel direction; keep last dir on a straight-up jump.
  if (p.vx > 0) world.flipDir = -1;
  else if (p.vx < 0) world.flipDir = 1;
}

// ----- Main step ------------------------------------------------------------

// Advance the world by dt seconds.
// `input` = { left, right, jumpPressed (edge), jumpHeld (held state) }.
function updateWorld(world, input, dt) {
  if (world.status !== 'play') return world;
  if (dt > C.MAX_DT) dt = C.MAX_DT;
  world.time += dt;
  if (world.justFlipped > 0) world.justFlipped = Math.max(0, world.justFlipped - dt);
  if (world.padFlash > 0) world.padFlash = Math.max(0, world.padFlash - dt);

  const p = world.player;

  // 1. Move platforms & monsters, then carry the player if they ride one.
  for (const s of world.solids) moveEntity(s, dt);
  for (const m of world.monsters) moveEntity(m, dt);
  if (p.standing) {
    p.x += p.standing._dx || 0;
    p.y += p.standing._dy || 0;
  }

  // 2. Horizontal intent.
  p.vx = ((input.right ? 1 : 0) - (input.left ? 1 : 0)) * C.MOVE_SPEED;

  // 3. Coyote-time & jump-buffer timers, then fire a buffered jump if allowed.
  world.coyote = p.onGround ? C.COYOTE : Math.max(0, world.coyote - dt);
  world.jumpBuffer = input.jumpPressed ? C.JUMP_BUFFER : Math.max(0, world.jumpBuffer - dt);
  if (world.jumpBuffer > 0 && world.coyote > 0) {
    doJump(world);
    world.jumpBuffer = 0;
    world.coyote = 0;
  }

  // 4. Gravity, then variable jump height: releasing early cuts the rise.
  p.vy += C.GRAVITY * dt;
  if (p.jumping && !input.jumpHeld && p.vy < 0) p.vy = Math.max(p.vy, C.JUMP_CUT_V);

  // 5. Integrate & resolve horizontally. Springs never block sideways — you run
  // into their column and get launched, not walled.
  p.x += p.vx * dt;
  for (const s of world.solids) {
    if (s.kind === 'spring') continue;
    if (!inPlane(s, p.plane)) continue;
    if (!aabbOverlap(p, s)) continue;
    if (p.vx > 0) p.x = s.x - p.w;
    else if (p.vx < 0) p.x = s.x + s.w;
    p.vx = 0;
  }
  if (p.x < 0) p.x = 0;
  if (p.x + p.w > world.width) p.x = world.width - p.w;

  // 6. Integrate & resolve vertically. Springs bounce; flip-pads recharge.
  // Resolve against ALL overlapping solids at once: a sequential pass would let
  // the first one zero out vy, hiding a pad or spring sitting flush on a floor.
  p.y += p.vy * dt;
  const prevStanding = p.standing;
  const hits = [];
  for (const s of world.solids) {
    if (!inPlane(s, p.plane)) continue;
    if (aabbOverlap(p, s)) hits.push(s);
  }
  p.onGround = false;
  p.standing = null;

  if (hits.length) {
    if (p.vy > 0) {
      // Landing: settle on the highest surface; a special tile (spring/pad)
      // flush with a plain floor wins the tie so it still triggers.
      let best = hits[0];
      for (const s of hits) {
        if (s.y < best.y || (s.y === best.y && s.kind && !best.kind)) best = s;
      }
      p.y = best.y - p.h;
      if (best.kind === 'spring') {
        p.vy = -(best.power || 900); // bounce: no flip, stays airborne
        p.jumping = false; // spring height is fixed, not variable
      } else {
        p.vy = 0;
        p.onGround = true;
        p.standing = best;
        p.jumping = false;
      }
    } else if (p.vy < 0) {
      // Rising: bonk on the lowest ceiling.
      let low = hits[0];
      for (const s of hits) if (s.y + s.h > low.y + low.h) low = s;
      p.y = low.y + low.h;
      p.vy = 0;
    }
  }

  // Flip-pad: the moment you newly land on one, swap the sand — no jump, no
  // plane change. This is the designed exception to "you can't recharge
  // without flipping plane".
  if (p.standing && p.standing.kind === 'flip' && p.standing !== prevStanding) {
    world.sand = flipSand(world.sand, world.sandMax, C.SAND_FLIP_BASE);
    world.padFlash = 0.4;
  }

  // 7. Sand drains with time; empty = death.
  world.sand -= dt * 1000;
  if (world.sand <= 0) {
    world.sand = 0;
    world.status = 'dead';
    return world;
  }

  // 8. Death by monster contact (current plane only).
  for (const m of world.monsters) {
    if (!inPlane(m, p.plane)) continue;
    if (aabbOverlap(p, m)) {
      world.status = 'dead';
      return world;
    }
  }

  // 9. Death by falling out of the world.
  if (p.y > C.WORLD_H + 60) {
    world.status = 'dead';
    return world;
  }

  // 10. Reaching the door wins the level.
  if (aabbOverlap(p, world.door)) world.status = 'win';

  return world;
}

// ----- Exports --------------------------------------------------------------
const HH = { C, aabbOverlap, flipSand, inPlane, otherPlane, createWorld, moveEntity, doJump, updateWorld };
if (typeof module !== 'undefined' && module.exports) module.exports = HH;
if (typeof window !== 'undefined') window.HH = HH;
