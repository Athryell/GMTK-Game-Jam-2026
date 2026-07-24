/*
 * Unit tests for the pure engine logic. Run with: node --test
 */
const assert = require('node:assert/strict');
const { test } = require('node:test');
const { flipSand, aabbOverlap, inPlane, otherPlane, createWorld, updateWorld, C } = require('../js/engine.js');
const { LEVELS } = require('../js/levels.js');

const NO_INPUT = { left: false, right: false, jumpPressed: false, jumpHeld: false };
const step = (w, input, n = 1, dt = 1 / 60) => {
  for (let i = 0; i < n; i++) updateWorld(w, input, dt);
};

// --- pure helpers -----------------------------------------------------------

test('flipSand returns the drained amount (proportional recharge)', () => {
  assert.equal(flipSand(6000, 6000), 0);
  assert.equal(flipSand(100, 6000), 5900);
  assert.equal(flipSand(3000, 6000), 3000);
});

test('flipSand clamps to [0, max]', () => {
  assert.equal(flipSand(-50, 6000), 6000);
  assert.equal(flipSand(7000, 6000), 0);
});

test('aabbOverlap detects overlap and separation', () => {
  const a = { x: 0, y: 0, w: 10, h: 10 };
  assert.equal(aabbOverlap(a, { x: 5, y: 5, w: 10, h: 10 }), true);
  assert.equal(aabbOverlap(a, { x: 20, y: 0, w: 10, h: 10 }), false);
  assert.equal(aabbOverlap(a, { x: 10, y: 0, w: 10, h: 10 }), false);
});

test('inPlane / otherPlane', () => {
  assert.equal(inPlane({ plane: 'both' }, 'front'), true);
  assert.equal(inPlane({ plane: 'front' }, 'front'), true);
  assert.equal(inPlane({ plane: 'back' }, 'front'), false);
  assert.equal(otherPlane('front'), 'back');
  assert.equal(otherPlane('back'), 'front');
});

// --- sand & jump ------------------------------------------------------------

test('sand drains over time and empties into death', () => {
  const w = createWorld(LEVELS[0]);
  w.sand = 100;
  step(w, NO_INPUT, 1, 0.03);
  assert.ok(w.sand < 100 && w.status === 'play', `sand=${w.sand} status=${w.status}`);
  for (let i = 0; i < 10 && w.status === 'play'; i++) step(w, NO_INPUT, 1, 0.03);
  assert.equal(w.status, 'dead');
});

test('a held jump flips the plane and recharges sand proportionally', () => {
  const w = createWorld(LEVELS[0]);
  step(w, NO_INPUT, 30);
  assert.equal(w.player.onGround, true);
  assert.equal(w.player.plane, 'front');

  w.sand = 1000;
  updateWorld(w, { left: false, right: false, jumpPressed: true, jumpHeld: true }, 1 / 60);
  assert.equal(w.player.plane, 'back', 'jump swaps plane');
  assert.ok(w.player.vy < -600, `held jump keeps full rise, got ${w.player.vy}`);
  assert.ok(w.sand > 4900 && w.sand <= 5000, `expected ~5000, got ${w.sand}`);
});

test('player lands on the ground and stops falling', () => {
  const w = createWorld(LEVELS[0]);
  step(w, NO_INPUT, 60);
  assert.ok(Math.abs(w.player.y + w.player.h - 502) < 0.001);
  assert.equal(w.player.vy, 0);
});

// --- feel: coyote, buffer, variable height ----------------------------------

test('variable jump height: releasing early cuts the rise', () => {
  const w = createWorld(LEVELS[0]);
  step(w, NO_INPUT, 30);
  updateWorld(w, { left: false, right: false, jumpPressed: true, jumpHeld: false }, 1 / 60);
  assert.equal(w.player.vy, C.JUMP_CUT_V, `tap should cut to ${C.JUMP_CUT_V}, got ${w.player.vy}`);
});

test('coyote time lets you jump just after leaving the ground', () => {
  const w = createWorld(LEVELS[0]);
  step(w, NO_INPUT, 30); // settle
  // Simulate having just walked off: airborne but coyote still fresh.
  w.player.onGround = false;
  w.player.y -= 60;
  w.coyote = C.COYOTE;
  updateWorld(w, { left: false, right: false, jumpPressed: true, jumpHeld: true }, 1 / 60);
  assert.equal(w.player.plane, 'back', 'coyote jump should fire (plane swaps)');
});

test('no jump once coyote has expired', () => {
  const w = createWorld(LEVELS[0]);
  step(w, NO_INPUT, 30);
  w.player.onGround = false;
  w.player.y -= 200;
  w.coyote = 0;
  const plane = w.player.plane;
  updateWorld(w, { left: false, right: false, jumpPressed: true, jumpHeld: true }, 1 / 60);
  assert.equal(w.player.plane, plane, 'no mid-air jump without coyote');
});

test('jump buffer: a press just before landing still fires', () => {
  const w = createWorld(LEVELS[0]);
  // Airborne but only just above the ground, so we land within the buffer
  // window. Press jump now; it should fire on landing a couple frames later.
  w.player.y = 450;
  w.player.onGround = false;
  updateWorld(w, { left: false, right: false, jumpPressed: true, jumpHeld: true }, 1 / 60); // buffer set
  // Fall until it lands; the buffered jump should fire on contact.
  let flipped = false;
  for (let i = 0; i < 40; i++) {
    const planeBefore = w.player.plane;
    updateWorld(w, { left: false, right: false, jumpPressed: false, jumpHeld: true }, 1 / 60);
    if (w.player.plane !== planeBefore) { flipped = true; break; }
  }
  assert.ok(flipped, 'buffered jump fired shortly after landing');
});

// --- tools: spring & flip-pad ----------------------------------------------

function toolLevel(extra) {
  return {
    name: 'tool',
    spawn: { x: 100, y: 380 },
    door: { x: 5000, y: 0, w: 2, h: 2 },
    solids: [{ x: 0, y: 502, w: 960, h: 38, plane: 'both' }, extra],
    monsters: [],
  };
}

test('spring bounces without flipping plane or sand', () => {
  const w = createWorld(toolLevel({ x: 80, y: 470, w: 70, h: 16, plane: 'both', kind: 'spring', power: 1000 }));
  let minVy = 0;
  for (let i = 0; i < 60; i++) {
    step(w, NO_INPUT, 1);
    minVy = Math.min(minVy, w.player.vy);
  }
  assert.ok(minVy <= -600, `spring should bounce hard, min vy=${minVy}`);
  assert.equal(w.player.plane, 'front', 'spring does not swap plane');
  assert.ok(w.sand <= C.SAND_START, 'spring does not add sand');
});

test('flip-pad swaps sand once on landing, no jump, no plane change', () => {
  const w = createWorld(toolLevel({ x: 80, y: 470, w: 70, h: 16, plane: 'both', kind: 'flip' }));
  w.sand = 800; // drained low, so a swap is a big refill
  // Fall onto the pad.
  for (let i = 0; i < 40 && !w.player.onGround; i++) step(w, NO_INPUT, 1);
  assert.equal(w.player.onGround, true, 'lands on the pad');
  assert.ok(w.sand > 4000, `pad recharged the sand, got ${w.sand}`);
  assert.equal(w.player.plane, 'front', 'pad does not swap plane');
  // Standing still must not re-trigger the swap; sand only drains from here.
  const after = w.sand;
  step(w, NO_INPUT, 30);
  assert.ok(w.sand < after, 'pad triggers once, then sand just drains');
});
