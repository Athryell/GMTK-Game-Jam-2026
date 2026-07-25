import { GRID_W, GRID_H, TILE } from './config.mjs';
import { T, isWalkable, tileKindAt } from './tiles.mjs';

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

export function generateHouse() {
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

export function tileAt(grid, worldX, worldY) {
  return tileKindAt(grid, Math.floor(worldX / TILE), Math.floor(worldY / TILE));
}

export function walkableAtPixel(grid, worldX, worldY) {
  return isWalkable(tileAt(grid, worldX, worldY));
}
