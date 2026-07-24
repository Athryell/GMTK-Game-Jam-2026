import assert from 'node:assert/strict';
import { MOTHER_CONE_RANGE, GRID_W, GRID_H } from '../src/config.mjs';
import { createMother, updateMother, motherSeesPlayer } from '../src/mother.mjs';

const entrance = { x: 500, y: 500 };

// Player straight ahead within range and cone, no walls -> seen.
{
  const mom = { ...createMother(entrance), facing: 0 };
  const player = { x: 600, y: 500 };
  assert.equal(motherSeesPlayer(mom, player, [], false), true);
}

// A wall between them blocks the line of sight.
{
  const mom = { ...createMother(entrance), facing: 0 };
  const player = { x: 600, y: 500 };
  const wall = [{ x1: 550, y1: 460, x2: 550, y2: 540 }];
  assert.equal(motherSeesPlayer(mom, player, wall, false), false);
}

// Hiding (under a table) beats a clear line of sight.
{
  const mom = { ...createMother(entrance), facing: 0 };
  const player = { x: 600, y: 500 };
  assert.equal(motherSeesPlayer(mom, player, [], true), false);
}

// Outside the cone angle -> not seen.
{
  const mom = { ...createMother(entrance), facing: 0 };
  const player = { x: 500, y: 600 }; // 90 deg off her facing
  assert.equal(motherSeesPlayer(mom, player, [], false), false);
}

// Beyond cone range -> not seen.
{
  const mom = { ...createMother(entrance), facing: 0 };
  const player = { x: 500 + MOTHER_CONE_RANGE + 50, y: 500 };
  assert.equal(motherSeesPlayer(mom, player, [], false), false);
}

// updateMother advances toward the next waypoint.
{
  const mom = createMother(entrance);
  mom.path = [{ x: 700, y: 500 }];
  const before = mom.x;
  updateMother(mom, null, 0.1, { x: 0, y: 0 }, false);
  assert.ok(mom.x > before, 'mother should move toward waypoint');
  assert.ok(Math.abs(mom.facing) < 1e-6, 'mother should face +x');
}

// Hearing a moving player nearby switches her to hunt mode.
{
  const grid = [];
  for (let y = 0; y < GRID_H; y++) grid.push(new Array(GRID_W).fill(1));
  const mom = { ...createMother({ x: 100, y: 100 }), x: 100, y: 100 };
  const player = { x: 140, y: 100 };
  updateMother(mom, grid, 0.016, player, true);
  assert.equal(mom.mode, 'hunt', 'moving player in earshot -> hunt');
  // Holding breath drops her back to searching.
  updateMother(mom, grid, 0.016, player, false);
  assert.equal(mom.mode, 'search', 'quiet player -> back to search');
}

console.log('mother.test.mjs: all assertions passed');
