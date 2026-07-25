import assert from 'node:assert/strict';
import { GRID_W, GRID_H, TILE } from '../src/config.mjs';
import { generateHouse, walkableAtPixel } from '../src/house.mjs';
import { isWalkable } from '../src/tiles.mjs';

function tileOf(p) {
  return [Math.floor(p.x / TILE), Math.floor(p.y / TILE)];
}

function reachable(grid, from, to) {
  const seen = new Set();
  const q = [from];
  const key = (x, y) => `${x},${y}`;
  seen.add(key(from[0], from[1]));
  while (q.length) {
    const [x, y] = q.shift();
    if (x === to[0] && y === to[1]) return true;
    for (const [ox, oy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const nx = x + ox;
      const ny = y + oy;
      if (nx < 0 || ny < 0 || nx >= GRID_W || ny >= GRID_H) continue;
      if (!isWalkable(grid[ny][nx])) continue;
      const k = key(nx, ny);
      if (seen.has(k)) continue;
      seen.add(k);
      q.push([nx, ny]);
    }
  }
  return false;
}

// Run several times: generation is random, invariants must always hold.
for (let run = 0; run < 40; run++) {
  const house = generateHouse();

  assert.equal(house.grid.length, GRID_H);
  assert.equal(house.grid[0].length, GRID_W);

  assert.ok(walkableAtPixel(house.grid, house.spawn.x, house.spawn.y));
  assert.ok(walkableAtPixel(house.grid, house.cookie.x, house.cookie.y));
  assert.ok(walkableAtPixel(house.grid, house.entrance.x, house.entrance.y));

  const spawn = tileOf(house.spawn);
  const cookie = tileOf(house.cookie);
  const entrance = tileOf(house.entrance);

  assert.notDeepEqual(spawn, cookie);
  assert.ok(reachable(house.grid, spawn, cookie), `run ${run}: cookie unreachable`);
  assert.ok(reachable(house.grid, spawn, entrance), `run ${run}: entrance unreachable`);
}

console.log('house.test.mjs: all assertions passed');
