(() => {
'use strict';
// Distances in world pixels, times in ms, angles in radians. Tiles only
// build the level; movement and vision are fully continuous / vector based.
const TILE = 40;

const GRID_W = 44;
const GRID_H = 30;

const WORLD_W = GRID_W * TILE;
const WORLD_H = GRID_H * TILE;

const VIEW_W = 1000;
const VIEW_H = 680;

const PLAYER_RADIUS = 11;
const PLAYER_SPEED = 168;
const PLAYER_VIEW_RADIUS = 240;

const MOTHER_RADIUS = 13;
const MOTHER_SPEED = 116; // slower than the player, so she is escapable
const MOTHER_CONE_HALF_ANGLE = Math.PI * 0.22;
const MOTHER_CONE_RANGE = 300;
const MOTHER_NOISE_INTERVAL_MS = 1500;
const MOTHER_NOISE_MAX_RADIUS = 90;
const MOTHER_REPATH_SLOP = 6;
const MOTHER_HEARING_RADIUS = 230; // she homes in on the player within this range while they move

// Breath: you can only hold still-and-silent for so long. The meter drains
// while holding breath and refills only by moving in the open (which is
// noisy); empty means you gasp and she can hear you.
const BREATH_MAX_MS = 5000;
const BREATH_REFILL_RATE = 1.5;

// Bed check: the recurring countdown that is the heart of the game. Each
// survived check shortens the next window, down to the floor.
const BED_CHECK_START_MS = 15000;
const BED_CHECK_MIN_MS = 5000;
const BED_CHECK_STEP_MS = 2000;
const CHECK_TELEGRAPH_MS = 3000; // final "get to cover 3..2..1" window

const COOKIE_PICKUP_DIST = 26;
const WIN_DIST = 34;

const COLORS = {
  floor: '#2c2540',
  floorLit: '#5a4d7a',
  wall: '#141019',
  wallLit: '#3a3350',
  table: '#6b4a2b',
  tableLit: '#a9743f',
  bed: '#3f6fb0',
  bedLit: '#6ea0e6',
  cookie: '#e8a24a',
  player: '#ffe08a',
  mother: '#d94c6a',
  cone: 'rgba(217, 76, 106, 0.16)',
  coneHunt: 'rgba(255, 90, 90, 0.30)',
};



// Tile kinds used by the level builder. Only WALL and TABLE block
// vision; only WALL blocks movement. TABLE is walkable and also acts as
// a hiding spot (Mom cannot see the player standing on one).

const T = {
  WALL: 0,
  FLOOR: 1,
  TABLE: 2,
};

// Tile kind at grid coords, treating out-of-bounds as solid wall.
function tileKindAt(grid, tx, ty) {
  if (tx < 0 || ty < 0 || tx >= GRID_W || ty >= GRID_H) return T.WALL;
  return grid[ty][tx];
}

function isWalkable(kind) {
  return kind === T.FLOOR || kind === T.TABLE;
}

// Occluders block line of sight, for both the visibility polygon and
// Mom's detection ray.
function isOccluder(kind) {
  return kind === T.WALL || kind === T.TABLE;
}




// Vision works on line segments, not tiles: every edge between an occluder
// and a non-occluder is a boundary, with collinear runs merged into one.
// Tile (exTx,exTy) is treated as open so the player standing on a table
// still sees out instead of being trapped inside the occluder.
function buildWallSegments(grid, exTx = -1, exTy = -1) {
  const occluderAt = (tx, ty) =>
    tx === exTx && ty === exTy ? false : isOccluder(tileKindAt(grid, tx, ty));
  const segments = [];

  for (let y = 0; y <= GRID_H; y++) {
    let runStart = -1;
    let runDir = 0; // +1 occluder below, -1 occluder above, 0 none
    for (let x = 0; x <= GRID_W; x++) {
      let dir = 0;
      if (x < GRID_W) {
        const above = occluderAt(x, y - 1);
        const below = occluderAt(x, y);
        if (below && !above) dir = 1;
        else if (above && !below) dir = -1;
      }
      if (dir !== runDir) {
        if (runDir !== 0) {
          segments.push({ x1: runStart * TILE, y1: y * TILE, x2: x * TILE, y2: y * TILE });
        }
        runDir = dir;
        runStart = x;
      }
    }
  }

  for (let x = 0; x <= GRID_W; x++) {
    let runStart = -1;
    let runDir = 0; // +1 occluder right, -1 occluder left
    for (let y = 0; y <= GRID_H; y++) {
      let dir = 0;
      if (y < GRID_H) {
        const left = occluderAt(x - 1, y);
        const right = occluderAt(x, y);
        if (right && !left) dir = 1;
        else if (left && !right) dir = -1;
      }
      if (dir !== runDir) {
        if (runDir !== 0) {
          segments.push({ x1: x * TILE, y1: runStart * TILE, x2: x * TILE, y2: y * TILE });
        }
        runDir = dir;
        runStart = y;
      }
    }
  }

  return segments;
}

// Distance t >= 0 along ray (ox,oy)+t*(dx,dy) to segment, or Infinity.
function raySegmentDist(ox, oy, dx, dy, seg) {
  const sx = seg.x2 - seg.x1;
  const sy = seg.y2 - seg.y1;
  const denom = dx * sy - dy * sx;
  if (Math.abs(denom) < 1e-9) return Infinity; // parallel
  const diffx = seg.x1 - ox;
  const diffy = seg.y1 - oy;
  const t = (diffx * sy - diffy * sx) / denom; // along ray
  const u = (diffx * dy - diffy * dx) / denom; // along segment
  if (t >= 0 && u >= 0 && u <= 1) return t;
  return Infinity;
}

// True if segments AB and CD touch or cross. Used for Mom's line-of-sight
// check, so a sightline grazing a wall corner counts as blocked (fair to
// the player) rather than leaking through.
function segmentsIntersect(ax, ay, bx, by, cx, cy, dx, dy) {
  const d1 = cross(dx - cx, dy - cy, ax - cx, ay - cy);
  const d2 = cross(dx - cx, dy - cy, bx - cx, by - cy);
  const d3 = cross(bx - ax, by - ay, cx - ax, cy - ay);
  const d4 = cross(bx - ax, by - ay, dx - ax, dy - ay);
  if (((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) && ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))) {
    return true;
  }
  if (d1 === 0 && onSegment(cx, cy, dx, dy, ax, ay)) return true;
  if (d2 === 0 && onSegment(cx, cy, dx, dy, bx, by)) return true;
  if (d3 === 0 && onSegment(ax, ay, bx, by, cx, cy)) return true;
  if (d4 === 0 && onSegment(ax, ay, bx, by, dx, dy)) return true;
  return false;
}

function cross(ax, ay, bx, by) {
  return ax * by - ay * bx;
}

// True if point (px,py), known collinear with AB, lies within its extent.
function onSegment(ax, ay, bx, by, px, py) {
  return (
    px >= Math.min(ax, bx) &&
    px <= Math.max(ax, bx) &&
    py >= Math.min(ay, by) &&
    py <= Math.max(ay, by)
  );
}

// True if the straight line origin->target is blocked by any segment.
function lineBlocked(ox, oy, tx, ty, segments) {
  for (const s of segments) {
    if (segmentsIntersect(ox, oy, tx, ty, s.x1, s.y1, s.x2, s.y2)) return true;
  }
  return false;
}

const EPS = 0.00025; // angular nudge so rays slip past segment corners
const DISC_RAYS = 120; // uniform rays for a smooth round boundary in the open

function castRay(ox, oy, angle, segments, radius) {
  const dx = Math.cos(angle);
  const dy = Math.sin(angle);
  let best = radius;
  for (const s of segments) {
    const t = raySegmentDist(ox, oy, dx, dy, s);
    if (t < best) best = t;
  }
  return { x: ox + dx * best, y: oy + dy * best, angle: normalizeAngle(angle) };
}

function endpointAngles(ox, oy, segments, radius) {
  const angles = [];
  const r2 = (radius + TILE) * (radius + TILE);
  const pushAngle = (px, py) => {
    const dx = px - ox;
    const dy = py - oy;
    if (dx * dx + dy * dy > r2) return;
    const a = Math.atan2(dy, dx);
    angles.push(a - EPS, a, a + EPS);
  };
  for (const s of segments) {
    pushAngle(s.x1, s.y1);
    pushAngle(s.x2, s.y2);
  }
  return angles;
}

// Full 360deg visibility disc around (ox,oy). Uniform rays give the round
// boundary; endpoint rays add the crisp shadow corners.
function computeVisibility(ox, oy, radius, segments) {
  const angles = endpointAngles(ox, oy, segments, radius);
  for (let i = 0; i < DISC_RAYS; i++) angles.push((i / DISC_RAYS) * Math.PI * 2 - Math.PI);
  const points = angles.map((a) => castRay(ox, oy, a, segments, radius));
  points.sort((p, q) => p.angle - q.angle);
  return points;
}

// A cone facing `facing` with half-width `half`, occluded by walls.
// Returned as a pie polygon that starts and ends at the origin.
function computeCone(ox, oy, facing, half, radius, segments) {
  const raw = endpointAngles(ox, oy, segments, radius).filter((a) =>
    Math.abs(normalizeAngle(a - facing)) <= half,
  );
  const steps = 40;
  for (let i = 0; i <= steps; i++) raw.push(facing - half + (i / steps) * 2 * half);
  const points = raw.map((a) => castRay(ox, oy, a, segments, radius));
  for (const p of points) p.rel = normalizeAngle(p.angle - facing);
  points.sort((p, q) => p.rel - q.rel);
  return [{ x: ox, y: oy }, ...points, { x: ox, y: oy }];
}

// Wraps an angle into (-PI, PI].
function normalizeAngle(a) {
  while (a <= -Math.PI) a += Math.PI * 2;
  while (a > Math.PI) a -= Math.PI * 2;
  return a;
}

// True if point p is inside polygon (array of {x,y}). Ray-cast test.
function pointInPolygon(px, py, poly) {
  let inside = false;
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    const xi = poly[i].x;
    const yi = poly[i].y;
    const xj = poly[j].x;
    const yj = poly[j].y;
    if ((yi > py) !== (yj > py) && px < ((xj - xi) * (py - yi)) / (yj - yi) + xi) {
      inside = !inside;
    }
  }
  return inside;
}




// Random house via binary space partitioning: split into regions, carve a
// room per leaf, connect room centers with corridors so all stay reachable.
const MIN_ROOM = 5;
const MIN_REGION = 9;
const SPLIT_DEPTH = 4;

function randInt(min, max) {
  return min + Math.floor(Math.random() * (max - min + 1));
}

function makeGrid(fill) {
  const g = [];
  for (let y = 0; y < GRID_H; y++) {
    g.push(new Array(GRID_W).fill(fill));
  }
  return g;
}

function splitRegion(region, depth, rooms) {
  const { x, y, w, h } = region;
  if (depth <= 0 || (w < MIN_REGION * 2 && h < MIN_REGION * 2)) {
    rooms.push(carveRoomRect(region));
    return;
  }

  const canH = w >= MIN_REGION * 2;
  const canV = h >= MIN_REGION * 2;
  const horizontal = canH && (!canV || Math.random() < 0.5);

  let a;
  let b;
  if (horizontal) {
    const cut = randInt(MIN_REGION, w - MIN_REGION);
    a = { x, y, w: cut, h };
    b = { x: x + cut, y, w: w - cut, h };
  } else {
    const cut = randInt(MIN_REGION, h - MIN_REGION);
    a = { x, y, w, h: cut };
    b = { x, y: y + cut, w, h: h - cut };
  }

  splitRegion(a, depth - 1, rooms);
  splitRegion(b, depth - 1, rooms);
}

// A room is a rectangle inset from its region, leaving 1-tile walls.
function carveRoomRect(region) {
  const maxW = region.w - 2;
  const maxH = region.h - 2;
  const rw = Math.max(MIN_ROOM, randInt(Math.min(MIN_ROOM, maxW), maxW));
  const rh = Math.max(MIN_ROOM, randInt(Math.min(MIN_ROOM, maxH), maxH));
  const rx = region.x + 1 + randInt(0, Math.max(0, region.w - 2 - rw));
  const ry = region.y + 1 + randInt(0, Math.max(0, region.h - 2 - rh));
  return { x: rx, y: ry, w: rw, h: rh, cx: Math.floor(rx + rw / 2), cy: Math.floor(ry + rh / 2) };
}

function carveRoom(grid, room) {
  for (let ty = room.y; ty < room.y + room.h; ty++) {
    for (let tx = room.x; tx < room.x + room.w; tx++) {
      grid[ty][tx] = T.FLOOR;
    }
  }
}

// L-shaped 1-wide corridor between two tile points.
function carveCorridor(grid, ax, ay, bx, by) {
  const x1 = Math.min(ax, bx);
  const x2 = Math.max(ax, bx);
  for (let x = x1; x <= x2; x++) grid[ay][x] = T.FLOOR;
  const y1 = Math.min(ay, by);
  const y2 = Math.max(ay, by);
  for (let y = y1; y <= y2; y++) grid[y][bx] = T.FLOOR;
}

function bfsRoomDistances(rooms, startIdx, adjacency) {
  const dist = new Array(rooms.length).fill(-1);
  dist[startIdx] = 0;
  const queue = [startIdx];
  while (queue.length) {
    const cur = queue.shift();
    for (const nxt of adjacency[cur]) {
      if (dist[nxt] === -1) {
        dist[nxt] = dist[cur] + 1;
        queue.push(nxt);
      }
    }
  }
  return dist;
}

function scatterTables(grid, rooms, blocked) {
  for (const room of rooms) {
    const count = randInt(0, 2);
    for (let i = 0; i < count; i++) {
      const tx = randInt(room.x + 1, room.x + room.w - 2);
      const ty = randInt(room.y + 1, room.y + room.h - 2);
      const key = `${tx},${ty}`;
      if (blocked.has(key)) continue;
      if (grid[ty][tx] !== T.FLOOR) continue;
      grid[ty][tx] = T.TABLE;
    }
  }
}

function generateHouse() {
  const grid = makeGrid(T.WALL);
  const rooms = [];

  splitRegion({ x: 0, y: 0, w: GRID_W, h: GRID_H }, SPLIT_DEPTH, rooms);

  for (const room of rooms) carveRoom(grid, room);

  // Connect rooms in a chain (sorted by position) plus a few extra links
  // so there are loops, then guarantee full connectivity via nearest links.
  const ordered = rooms.slice().sort((a, b) => a.cx - b.cx || a.cy - b.cy);
  const adjacency = rooms.map(() => new Set());
  const linkByCenter = (i, j) => {
    carveCorridor(grid, ordered[i].cx, ordered[i].cy, ordered[j].cx, ordered[j].cy);
    const gi = rooms.indexOf(ordered[i]);
    const gj = rooms.indexOf(ordered[j]);
    adjacency[gi].add(gj);
    adjacency[gj].add(gi);
  };
  for (let i = 1; i < ordered.length; i++) linkByCenter(i - 1, i);
  // a couple of extra corridors for non-linear layouts
  for (let k = 0; k < Math.max(1, Math.floor(ordered.length / 3)); k++) {
    const i = randInt(0, ordered.length - 1);
    const j = randInt(0, ordered.length - 1);
    if (i !== j) linkByCenter(i, j);
  }

  // Bedroom (spawn) = a random room; cookie room = the room graph-farthest
  // from it, so the player must cross the house.
  const spawnIdx = randInt(0, rooms.length - 1);
  const dist = bfsRoomDistances(rooms, spawnIdx, adjacency);
  let cookieIdx = spawnIdx;
  let best = -1;
  for (let i = 0; i < rooms.length; i++) {
    if (dist[i] > best) {
      best = dist[i];
      cookieIdx = i;
    }
  }

  const spawnRoom = rooms[spawnIdx];
  const cookieRoom = rooms[cookieIdx];

  // Entrance = the room whose center is closest to a map border (Mom comes
  // in from outside there). Prefer one that is neither spawn nor cookie.
  let entranceIdx = 0;
  let entranceScore = Infinity;
  for (let i = 0; i < rooms.length; i++) {
    if (i === spawnIdx || i === cookieIdx) continue;
    const r = rooms[i];
    const edge = Math.min(r.cx, GRID_W - r.cx, r.cy, GRID_H - r.cy);
    if (edge < entranceScore) {
      entranceScore = edge;
      entranceIdx = i;
    }
  }
  const entranceRoom = rooms[entranceIdx];

  const spawn = { x: (spawnRoom.cx + 0.5) * TILE, y: (spawnRoom.cy + 0.5) * TILE };
  const cookie = { x: (cookieRoom.cx + 0.5) * TILE, y: (cookieRoom.cy + 0.5) * TILE };
  const entrance = { x: (entranceRoom.cx + 0.5) * TILE, y: (entranceRoom.cy + 0.5) * TILE };

  const blocked = new Set([
    `${spawnRoom.cx},${spawnRoom.cy}`,
    `${cookieRoom.cx},${cookieRoom.cy}`,
    `${entranceRoom.cx},${entranceRoom.cy}`,
  ]);
  scatterTables(grid, rooms, blocked);

  return { grid, spawn, cookie, entrance };
}

function tileAt(grid, worldX, worldY) {
  return tileKindAt(grid, Math.floor(worldX / TILE), Math.floor(worldY / TILE));
}

function walkableAtPixel(grid, worldX, worldY) {
  return isWalkable(tileAt(grid, worldX, worldY));
}




function createPlayer(spawn) {
  return {
    x: spawn.x,
    y: spawn.y,
    facing: 0,
    hasCookie: false,
    moving: false, // displaced this frame -> makes noise Mom can home in on
  };
}

// Collision is continuous: the player is a circle, walls are solid tiles.
// We resolve one axis at a time so sliding along a wall feels smooth, and
// probe the circle's leading edge rather than snapping to the grid.
function blocked(grid, x, y) {
  const r = PLAYER_RADIUS;
  return (
    !walkableAtPixel(grid, x - r, y - r) ||
    !walkableAtPixel(grid, x + r, y - r) ||
    !walkableAtPixel(grid, x - r, y + r) ||
    !walkableAtPixel(grid, x + r, y + r)
  );
}

function updatePlayer(player, input, grid, dtSeconds) {
  let dx = 0;
  let dy = 0;
  if (input.up) dy -= 1;
  if (input.down) dy += 1;
  if (input.left) dx -= 1;
  if (input.right) dx += 1;

  if (dx !== 0 || dy !== 0) {
    const len = Math.hypot(dx, dy);
    dx = (dx / len) * PLAYER_SPEED * dtSeconds;
    dy = (dy / len) * PLAYER_SPEED * dtSeconds;
    player.facing = Math.atan2(dy, dx);
  }

  const startX = player.x;
  const startY = player.y;

  const nextX = player.x + dx;
  if (!blocked(grid, nextX, player.y)) player.x = nextX;

  const nextY = player.y + dy;
  if (!blocked(grid, player.x, nextY)) player.y = nextY;

  player.moving = Math.abs(player.x - startX) > 0.01 || Math.abs(player.y - startY) > 0.01;
}






const DIRS = [[1, 0], [-1, 0], [0, 1], [0, -1]];

function createMother(entrance) {
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

function updateMother(mother, grid, dtSeconds, player, audible) {
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
function motherSeesPlayer(mother, player, segments, playerHidden) {
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
function isPlayerHidden(player, grid) {
  return tileAt(grid, player.x, player.y) === T.TABLE;
}





const renderOptions = { revealExplored: false };

function cameraOffset(player) {
  let cx = player.x - VIEW_W / 2;
  let cy = player.y - VIEW_H / 2;
  cx = Math.max(0, Math.min(WORLD_W - VIEW_W, cx));
  cy = Math.max(0, Math.min(WORLD_H - VIEW_H, cy));
  return { cx, cy };
}

function tileColor(kind, lit) {
  if (kind === T.WALL) return lit ? COLORS.wallLit : COLORS.wall;
  if (kind === T.TABLE) return lit ? COLORS.tableLit : COLORS.table;
  return lit ? COLORS.floorLit : COLORS.floor;
}

function drawTiles(ctx, grid, px0, py0, px1, py1, lit) {
  const x0 = Math.max(0, Math.floor(px0 / TILE));
  const y0 = Math.max(0, Math.floor(py0 / TILE));
  const x1 = Math.min(GRID_W, Math.ceil(px1 / TILE));
  const y1 = Math.min(GRID_H, Math.ceil(py1 / TILE));
  for (let ty = y0; ty < y1; ty++) {
    for (let tx = x0; tx < x1; tx++) {
      ctx.fillStyle = tileColor(grid[ty][tx], lit);
      ctx.fillRect(tx * TILE, ty * TILE, TILE, TILE);
    }
  }
}

// Tables occlude, so the clipped floor pass leaves them dark. Redraw the
// ones the player can see (a point just in front of the tile lies inside
// the visibility polygon) so they read as solid hiding spots, not black
// holes. Walls stay black: the lit-floor edge already traces them.
function drawSeenTables(ctx, grid, player, vis) {
  const x0 = Math.max(0, Math.floor((player.x - PLAYER_VIEW_RADIUS) / TILE));
  const y0 = Math.max(0, Math.floor((player.y - PLAYER_VIEW_RADIUS) / TILE));
  const x1 = Math.min(GRID_W, Math.ceil((player.x + PLAYER_VIEW_RADIUS) / TILE));
  const y1 = Math.min(GRID_H, Math.ceil((player.y + PLAYER_VIEW_RADIUS) / TILE));
  for (let ty = y0; ty < y1; ty++) {
    for (let tx = x0; tx < x1; tx++) {
      if (grid[ty][tx] !== T.TABLE) continue;
      let nx = Math.max(tx * TILE, Math.min(player.x, (tx + 1) * TILE));
      let ny = Math.max(ty * TILE, Math.min(player.y, (ty + 1) * TILE));
      const ddx = player.x - nx;
      const ddy = player.y - ny;
      const d = Math.hypot(ddx, ddy);
      if (d > PLAYER_VIEW_RADIUS) continue;
      if (d > 0.001) {
        nx += (ddx / d) * 4;
        ny += (ddy / d) * 4;
      }
      if (!pointInPolygon(nx, ny, vis)) continue;
      ctx.fillStyle = tileColor(T.TABLE, true);
      ctx.fillRect(tx * TILE, ty * TILE, TILE, TILE);
    }
  }
}

function polygonPath(poly) {
  const path = new Path2D();
  if (poly.length) {
    path.moveTo(poly[0].x, poly[0].y);
    for (let i = 1; i < poly.length; i++) path.lineTo(poly[i].x, poly[i].y);
    path.closePath();
  }
  return path;
}

function drawBed(ctx, spawn, lit) {
  const s = TILE * 0.8;
  ctx.fillStyle = lit ? COLORS.bedLit : COLORS.bed;
  ctx.fillRect(spawn.x - s / 2, spawn.y - s / 2, s, s);
  ctx.fillStyle = lit ? '#dce8ff' : '#8fb0dd';
  ctx.fillRect(spawn.x - s / 2, spawn.y - s / 2, s, s * 0.32);
}

function drawCookie(ctx, cookie, t) {
  const pulse = 1 + 0.12 * Math.sin(t / 260);
  ctx.fillStyle = COLORS.cookie;
  ctx.beginPath();
  ctx.arc(cookie.x, cookie.y, 9 * pulse, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#5a3210';
  for (const [ox, oy] of [[-3, -2], [3, -1], [0, 3], [-2, 3]]) {
    ctx.beginPath();
    ctx.arc(cookie.x + ox, cookie.y + oy, 1.3, 0, Math.PI * 2);
    ctx.fill();
  }
}

function drawPlayer(ctx, player) {
  ctx.fillStyle = COLORS.player;
  ctx.beginPath();
  ctx.arc(player.x, player.y, PLAYER_RADIUS, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#8a6d1f';
  ctx.beginPath();
  ctx.arc(
    player.x + Math.cos(player.facing) * PLAYER_RADIUS * 0.6,
    player.y + Math.sin(player.facing) * PLAYER_RADIUS * 0.6,
    3.5,
    0,
    Math.PI * 2,
  );
  ctx.fill();
}

function drawMother(ctx, mother, segments) {
  const cone = computeCone(
    mother.x,
    mother.y,
    mother.facing,
    MOTHER_CONE_HALF_ANGLE,
    MOTHER_CONE_RANGE,
    segments,
  );
  ctx.fillStyle = mother.mode === 'hunt' ? COLORS.coneHunt : COLORS.cone;
  ctx.fill(polygonPath(cone));

  ctx.fillStyle = COLORS.mother;
  ctx.beginPath();
  ctx.arc(mother.x, mother.y, MOTHER_RADIUS, 0, Math.PI * 2);
  ctx.fill();
}

// Noise rings are drawn WITHOUT the visibility clip: the player senses
// Mom's position through walls by the sound she makes.
function drawNoise(ctx, mother) {
  for (const p of mother.pings) {
    const frac = p.age / MOTHER_NOISE_INTERVAL_MS;
    const r = 12 + frac * MOTHER_NOISE_MAX_RADIUS;
    ctx.strokeStyle = `rgba(255, 220, 120, ${0.8 * (1 - frac)})`;
    ctx.lineWidth = 2.5;
    ctx.beginPath();
    ctx.arc(p.x, p.y, r, 0, Math.PI * 2);
    ctx.stroke();
  }
}

// When Mom is off-screen, clamp a pulsing arrow to the screen edge that
// points toward her, so the player always has a rough sense of her position.
function drawOffscreenMother(ctx, mother, cam, timeMs) {
  const mx = mother.x - cam.cx;
  const my = mother.y - cam.cy;
  if (mx >= 0 && mx <= VIEW_W && my >= 0 && my <= VIEW_H) return;

  const cx = VIEW_W / 2;
  const cy = VIEW_H / 2;
  const margin = 30;
  const ang = Math.atan2(my - cy, mx - cx);
  const dx = Math.cos(ang);
  const dy = Math.sin(ang);
  const scale = Math.min(
    (VIEW_W / 2 - margin) / Math.abs(dx || 1e-6),
    (VIEW_H / 2 - margin) / Math.abs(dy || 1e-6),
  );
  const px = cx + dx * scale;
  const py = cy + dy * scale;

  const pulse = 0.55 + 0.35 * Math.sin(timeMs / 180);
  ctx.save();
  ctx.translate(px, py);
  ctx.rotate(ang);
  ctx.globalAlpha = pulse;
  ctx.fillStyle = COLORS.mother;
  ctx.beginPath();
  ctx.arc(-16, 0, 11, 0, Math.PI * 2);
  ctx.fill();
  ctx.beginPath();
  ctx.moveTo(14, 0);
  ctx.lineTo(-4, -9);
  ctx.lineTo(-4, 9);
  ctx.closePath();
  ctx.fill();
  ctx.globalAlpha = 1;
  ctx.restore();
}

function drawGame(ctx, state, timeMs) {
  const { house, segments, viewSegments, player, mother } = state;
  const cam = cameraOffset(player);

  ctx.clearRect(0, 0, VIEW_W, VIEW_H);
  ctx.fillStyle = '#07050c';
  ctx.fillRect(0, 0, VIEW_W, VIEW_H);

  ctx.save();
  ctx.translate(-cam.cx, -cam.cy);

  if (renderOptions.revealExplored) {
    ctx.globalAlpha = 0.28;
    drawTiles(ctx, house.grid, cam.cx, cam.cy, cam.cx + VIEW_W, cam.cy + VIEW_H, false);
    ctx.globalAlpha = 1;
    drawBed(ctx, house.spawn, false);
  }

  // Bright pass, clipped to the analytic visibility polygon. Only tiles
  // within view radius can show, so the loop stays tight around the player.
  const vis = computeVisibility(player.x, player.y, PLAYER_VIEW_RADIUS, viewSegments);
  const visPath = polygonPath(vis);
  ctx.save();
  ctx.clip(visPath);
  drawTiles(
    ctx,
    house.grid,
    player.x - PLAYER_VIEW_RADIUS,
    player.y - PLAYER_VIEW_RADIUS,
    player.x + PLAYER_VIEW_RADIUS,
    player.y + PLAYER_VIEW_RADIUS,
    true,
  );
  drawBed(ctx, house.spawn, true);
  if (!player.hasCookie) drawCookie(ctx, house.cookie, timeMs);
  ctx.restore();

  drawSeenTables(ctx, house.grid, player, vis);

  // Mother + cone, only the parts inside the player's sight.
  ctx.save();
  ctx.clip(visPath);
  drawMother(ctx, mother, segments);
  ctx.restore();
  drawNoise(ctx, mother);

  drawPlayer(ctx, player);

  ctx.restore();

  drawOffscreenMother(ctx, mother, cam, timeMs);
  drawHud(ctx, state, timeMs);
}

function drawHud(ctx, state, timeMs) {
  ctx.fillStyle = 'rgba(0,0,0,0.55)';
  ctx.fillRect(0, 0, VIEW_W, 46);
  ctx.textBaseline = 'middle';

  ctx.font = '600 18px system-ui, sans-serif';
  ctx.textAlign = 'left';
  ctx.fillStyle = state.player.hasCookie ? COLORS.cookie : '#8a8397';
  ctx.fillText(state.player.hasCookie ? '🍪 Cookie grabbed' : '🍪 Find the cookie', 16, 23);

  ctx.textAlign = 'right';
  ctx.fillStyle = '#b8b0c8';
  ctx.fillText(`Round ${state.round}`, VIEW_W - 16, 23);

  // Bed-check countdown, centered and escalating.
  const telegraph = state.checkMs <= CHECK_TELEGRAPH_MS;
  const secs = Math.max(0, Math.ceil(state.checkMs / 1000));
  ctx.textAlign = 'center';
  ctx.fillStyle = telegraph ? '#ff7a7a' : '#e6e0f0';
  ctx.font = '700 24px system-ui, sans-serif';
  ctx.fillText(`Bed check in ${secs}s`, VIEW_W / 2, 23);

  if (telegraph) {
    const pulse = 0.6 + 0.4 * Math.sin(timeMs / 120);
    ctx.globalAlpha = pulse;
    ctx.fillStyle = '#ff7a7a';
    ctx.font = '800 30px system-ui, sans-serif';
    ctx.fillText('GET TO COVER', VIEW_W / 2, 78);
    ctx.globalAlpha = 1;
  }

  // Breath meter: a bar that drains while holding your breath.
  const bw = 220;
  const bh = 10;
  const bx = VIEW_W / 2 - bw / 2;
  const by = VIEW_H - 40;
  const frac = Math.max(0, Math.min(1, state.breathMs / BREATH_MAX_MS));
  const empty = state.breathMs <= 0;
  ctx.fillStyle = 'rgba(255,255,255,0.12)';
  ctx.fillRect(bx, by, bw, bh);
  ctx.fillStyle = empty ? '#ff7a7a' : frac < 0.3 ? '#e0a24a' : '#9be08a';
  ctx.fillRect(bx, by, bw * frac, bh);

  ctx.font = '600 13px system-ui, sans-serif';
  ctx.textAlign = 'center';
  if (empty) {
    ctx.fillStyle = '#ff7a7a';
    ctx.fillText('Out of breath — she can hear you!', VIEW_W / 2, VIEW_H - 16);
  } else if (state.audible) {
    ctx.fillStyle = '#e0a24a';
    ctx.fillText('Moving — she can hear you', VIEW_W / 2, VIEW_H - 16);
  } else {
    ctx.fillStyle = '#8a8397';
    ctx.fillText('Holding your breath', VIEW_W / 2, VIEW_H - 16);
  }

  // "Safe!" pulse after a passed check.
  if (state.flashMs > 0 && state.phase === 'playing') {
    ctx.globalAlpha = Math.min(1, state.flashMs / 900);
    ctx.fillStyle = '#9be08a';
    ctx.font = '800 34px system-ui, sans-serif';
    ctx.fillText('Safe!', VIEW_W / 2, VIEW_H / 2 - 60);
    ctx.globalAlpha = 1;
  }

  if (state.phase === 'won' || state.phase === 'lost') {
    ctx.fillStyle = 'rgba(0,0,0,0.72)';
    ctx.fillRect(0, 0, VIEW_W, VIEW_H);
    ctx.fillStyle = state.phase === 'won' ? '#9be08a' : '#ff7a7a';
    ctx.font = '700 40px system-ui, sans-serif';
    ctx.fillText(
      state.phase === 'won' ? 'Mission complete 🍪' : 'Caught! 😱',
      VIEW_W / 2,
      VIEW_H / 2 - 24,
    );
    ctx.fillStyle = '#e6e0f0';
    ctx.font = '500 20px system-ui, sans-serif';
    ctx.fillText(loseSubtitle(state), VIEW_W / 2, VIEW_H / 2 + 14);
    ctx.fillStyle = '#b8b0c8';
    ctx.font = '500 16px system-ui, sans-serif';
    ctx.fillText('Press R to play again', VIEW_W / 2, VIEW_H / 2 + 48);
  }
}

function loseSubtitle(state) {
  if (state.phase === 'won') return 'Back in bed, no one the wiser.';
  return state.lostReason === 'check'
    ? 'Mom checked your bed and you were gone.'
    : 'Mom spotted you out of bed.';
}







// Chosen from the menu before a run starts; createGame reads it each time.
const gameOptions = { startMs: BED_CHECK_START_MS };

function checkWindow(round, startMs) {
  return Math.max(BED_CHECK_MIN_MS, startMs - (round - 1) * BED_CHECK_STEP_MS);
}

function createGame() {
  const house = generateHouse();
  const segments = buildWallSegments(house.grid);
  return {
    house,
    segments, // walls + tables: cast shadows and block Mom's sight
    viewSegments: segments, // player's occluders; swapped out while on a table
    viewTile: -1, // table tile currently excluded from viewSegments
    player: createPlayer(house.spawn),
    mother: createMother(house.entrance),
    phase: 'playing', // 'playing' | 'won' | 'lost'
    lostReason: '', // 'cone' | 'check'
    audible: false, // player is making noise Mom can hear
    breathMs: BREATH_MAX_MS, // held-breath meter; empty -> gasping
    round: 1,
    checkMs: gameOptions.startMs, // counts down to the next bed check
    flashMs: 0, // brief "Safe!" pulse after a passed check
  };
}

function dist(ax, ay, bx, by) {
  return Math.hypot(ax - bx, ay - by);
}

// At the check Mom looks everywhere (no cone): the player survives only in
// hard cover — in bed, under a table, or with a wall between them.
function safeAtCheck(state, hidden) {
  const { player, mother, house, segments } = state;
  if (hidden) return true;
  if (dist(player.x, player.y, house.spawn.x, house.spawn.y) <= WIN_DIST) return true;
  return lineBlocked(mother.x, mother.y, player.x, player.y, segments);
}

function updateGame(state, input, dtSeconds) {
  if (state.phase !== 'playing') return;
  if (state.flashMs > 0) state.flashMs -= dtSeconds * 1000;

  updatePlayer(state.player, input, state.house.grid, dtSeconds);

  const hidden = isPlayerHidden(state.player, state.house.grid);

  // Breath meter: moving in the open refills it (but is noisy); holding
  // still or hiding drains it, and running out makes you gasp audibly.
  const breathing = state.player.moving && !hidden;
  state.breathMs = breathing
    ? Math.min(BREATH_MAX_MS, state.breathMs + dtSeconds * 1000 * BREATH_REFILL_RATE)
    : Math.max(0, state.breathMs - dtSeconds * 1000);
  state.audible = breathing || state.breathMs <= 0;

  // While standing on a table, exclude that tile from the player's occluders
  // so tables still cast shadows but hiding never blacks out the view.
  const ptx = Math.floor(state.player.x / TILE);
  const pty = Math.floor(state.player.y / TILE);
  const exTile = hidden ? pty * GRID_W + ptx : -1;
  if (exTile !== state.viewTile) {
    state.viewTile = exTile;
    state.viewSegments = hidden ? buildWallSegments(state.house.grid, ptx, pty) : state.segments;
  }

  updateMother(state.mother, state.house.grid, dtSeconds, state.player, state.audible);

  if (
    !state.player.hasCookie &&
    dist(state.player.x, state.player.y, state.house.cookie.x, state.house.cookie.y) <=
      COOKIE_PICKUP_DIST
  ) {
    state.player.hasCookie = true;
  }

  // Lose: caught in Mom's roaming cone (unless hiding under a table).
  if (motherSeesPlayer(state.mother, state.player, state.segments, hidden)) {
    state.phase = 'lost';
    state.lostReason = 'cone';
    return;
  }

  // Bed check: survive in cover, then the next window shortens.
  state.checkMs -= dtSeconds * 1000;
  if (state.checkMs <= 0) {
    if (!safeAtCheck(state, hidden)) {
      state.phase = 'lost';
      state.lostReason = 'check';
      return;
    }
    state.round += 1;
    state.checkMs = checkWindow(state.round, gameOptions.startMs);
    state.flashMs = 900;
  }

  // Win: back at the bed with the cookie.
  if (
    state.player.hasCookie &&
    dist(state.player.x, state.player.y, state.house.spawn.x, state.house.spawn.y) <= WIN_DIST
  ) {
    state.phase = 'won';
  }
}





const canvas = document.getElementById('game');
canvas.width = VIEW_W;
canvas.height = VIEW_H;
const ctx = canvas.getContext('2d');

const revealToggle = document.getElementById('reveal-toggle');
if (revealToggle) {
  renderOptions.revealExplored = revealToggle.checked;
  revealToggle.addEventListener('change', () => {
    renderOptions.revealExplored = revealToggle.checked;
  });
}

const input = { up: false, down: false, left: false, right: false };

const KEY_MAP = {
  ArrowUp: 'up',
  ArrowDown: 'down',
  ArrowLeft: 'left',
  ArrowRight: 'right',
  KeyW: 'up',
  KeyS: 'down',
  KeyA: 'left',
  KeyD: 'right',
};

// Slider: length of the first bed-check window. Set before the first game
// so it honors the slider's restored value on reload; live label while
// dragging, restart with the new time on release.
const countdownSlider = document.getElementById('countdown-slider');
const countdownValue = document.getElementById('countdown-value');
if (countdownSlider) {
  const syncLabel = () => {
    if (countdownValue) countdownValue.textContent = `${countdownSlider.value}s`;
  };
  gameOptions.startMs = Number(countdownSlider.value) * 1000;
  syncLabel();
  countdownSlider.addEventListener('input', syncLabel);
  countdownSlider.addEventListener('change', () => {
    gameOptions.startMs = Number(countdownSlider.value) * 1000;
    game = createGame();
  });
}

let game = createGame();

window.addEventListener('keydown', (e) => {
  if (e.code === 'KeyR') {
    game = createGame();
    return;
  }
  const dir = KEY_MAP[e.code];
  if (dir) {
    input[dir] = true;
    e.preventDefault();
  }
});

window.addEventListener('keyup', (e) => {
  const dir = KEY_MAP[e.code];
  if (dir) {
    input[dir] = false;
    e.preventDefault();
  }
});

let last = performance.now();

function frame(now) {
  // Clamp dt so tab-switch pauses don't teleport entities through walls.
  const dt = Math.min(0.05, (now - last) / 1000);
  last = now;

  updateGame(game, input, dt);
  drawGame(ctx, game, now);

  requestAnimationFrame(frame);
}

requestAnimationFrame(frame);

})();
