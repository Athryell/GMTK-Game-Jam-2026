import {
  TILE,
  GRID_W,
  GRID_H,
  MOTHER_SPEED,
  MOTHER_CONE_HALF_ANGLE,
  MOTHER_CONE_RANGE,
  MOTHER_NOISE_INTERVAL_MS,
  MOTHER_REPATH_SLOP,
  MOTHER_HEARING_RADIUS,
} from './config.mjs';
import { T, isWalkable, tileKindAt } from './tiles.mjs';
import { tileAt } from './house.mjs';
import { lineBlocked, normalizeAngle } from './geometry.mjs';

const DIRS = [[1, 0], [-1, 0], [0, 1], [0, -1]];

export function createMother(entrance) {
  return {
    x: entrance.x,
    y: entrance.y,
    facing: 0,
    mode: 'search', // 'search' (random) | 'hunt' (homing on the player's noise)
    huntTile: -1, // player tile she is currently pathing toward while hunting
    path: [], // remaining world-space waypoints
    noiseTimer: 0,
    pings: [], // expanding noise rings the player can sense through walls
  };
}

function tileWalkable(grid, tx, ty) {
  return isWalkable(tileKindAt(grid, tx, ty));
}

// Breadth-first search over walkable tiles -> list of tile coords, or null.
function bfsPath(grid, sx, sy, gx, gy) {
  if (!tileWalkable(grid, gx, gy)) return null;
  const key = (x, y) => y * GRID_W + x;
  const prev = new Map();
  const start = key(sx, sy);
  prev.set(start, -1);
  const queue = [[sx, sy]];
  let head = 0;
  while (head < queue.length) {
    const [cx, cy] = queue[head++];
    if (cx === gx && cy === gy) break;
    for (const [ox, oy] of DIRS) {
      const nx = cx + ox;
      const ny = cy + oy;
      if (!tileWalkable(grid, nx, ny)) continue;
      const k = key(nx, ny);
      if (prev.has(k)) continue;
      prev.set(k, key(cx, cy));
      queue.push([nx, ny]);
    }
  }
  const goal = key(gx, gy);
  if (!prev.has(goal)) return null;
  const path = [];
  let cur = goal;
  while (cur !== -1) {
    path.push([cur % GRID_W, Math.floor(cur / GRID_W)]);
    cur = prev.get(cur);
  }
  path.reverse();
  return path;
}

function randomWalkableTile(grid) {
  for (let tries = 0; tries < 200; tries++) {
    const tx = Math.floor(Math.random() * GRID_W);
    const ty = Math.floor(Math.random() * GRID_H);
    if (tileWalkable(grid, tx, ty)) return [tx, ty];
  }
  return null;
}

// Convert a tile path (skipping the start tile) into world-space waypoints.
function setPath(mother, tiles) {
  mother.path = tiles.slice(1).map(([tx, ty]) => ({
    x: (tx + 0.5) * TILE,
    y: (ty + 0.5) * TILE,
  }));
}

function pickNewDestination(mother, grid) {
  const sx = Math.floor(mother.x / TILE);
  const sy = Math.floor(mother.y / TILE);
  const dest = randomWalkableTile(grid);
  if (!dest) return;
  const tiles = bfsPath(grid, sx, sy, dest[0], dest[1]);
  if (!tiles || tiles.length < 2) return;
  setPath(mother, tiles);
}

// Hearing: while the player moves within earshot she homes in on them;
// the moment they hold their breath (stop / hide) she loses the trail and
// goes back to wandering.
function updateHunt(mother, grid, player, audible) {
  const px = Math.floor(player.x / TILE);
  const py = Math.floor(player.y / TILE);
  const heard =
    audible && Math.hypot(player.x - mother.x, player.y - mother.y) <= MOTHER_HEARING_RADIUS;

  if (heard) {
    mother.mode = 'hunt';
    const tile = py * GRID_W + px;
    if (mother.huntTile !== tile) {
      mother.huntTile = tile;
      const tiles = bfsPath(grid, Math.floor(mother.x / TILE), Math.floor(mother.y / TILE), px, py);
      if (tiles && tiles.length >= 2) setPath(mother, tiles);
    }
  } else if (mother.mode === 'hunt') {
    mother.mode = 'search';
    mother.huntTile = -1;
    mother.path = [];
  }
}

export function updateMother(mother, grid, dtSeconds, player, audible) {
  mother.noiseTimer += dtSeconds * 1000;
  if (mother.noiseTimer >= MOTHER_NOISE_INTERVAL_MS) {
    mother.noiseTimer -= MOTHER_NOISE_INTERVAL_MS;
    mother.pings.push({ x: mother.x, y: mother.y, age: 0 });
  }
  for (const p of mother.pings) p.age += dtSeconds * 1000;
  mother.pings = mother.pings.filter((p) => p.age < MOTHER_NOISE_INTERVAL_MS);

  updateHunt(mother, grid, player, audible);

  if (mother.path.length === 0) {
    pickNewDestination(mother, grid);
    if (mother.path.length === 0) return;
  }

  const target = mother.path[0];
  const dx = target.x - mother.x;
  const dy = target.y - mother.y;
  const dist = Math.hypot(dx, dy);

  if (dist <= MOTHER_REPATH_SLOP) {
    mother.path.shift();
    return;
  }

  const step = MOTHER_SPEED * dtSeconds;
  mother.facing = Math.atan2(dy, dx);
  mother.x += (dx / dist) * step;
  mother.y += (dy / dist) * step;
}

// True if the player is inside Mom's occluded cone and not hiding.
export function motherSeesPlayer(mother, player, segments, playerHidden) {
  if (playerHidden) return false;

  const dx = player.x - mother.x;
  const dy = player.y - mother.y;
  const dist = Math.hypot(dx, dy);
  if (dist > MOTHER_CONE_RANGE) return false;

  const angle = Math.atan2(dy, dx);
  if (Math.abs(normalizeAngle(angle - mother.facing)) > MOTHER_CONE_HALF_ANGLE) return false;

  if (lineBlocked(mother.x, mother.y, player.x, player.y, segments)) return false;
  return true;
}

// The player is hidden if standing on a table tile.
export function isPlayerHidden(player, grid) {
  return tileAt(grid, player.x, player.y) === T.TABLE;
}
