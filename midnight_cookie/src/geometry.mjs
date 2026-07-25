import { TILE, GRID_W, GRID_H } from './config.mjs';
import { isOccluder, tileKindAt } from './tiles.mjs';

// Vision works on line segments, not tiles: every edge between an occluder
// and a non-occluder is a boundary, with collinear runs merged into one.
// Tile (exTx,exTy) is treated as open so the player standing on a table
// still sees out instead of being trapped inside the occluder.
export function buildWallSegments(grid, exTx = -1, exTy = -1) {
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
export function raySegmentDist(ox, oy, dx, dy, seg) {
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
export function segmentsIntersect(ax, ay, bx, by, cx, cy, dx, dy) {
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
export function lineBlocked(ox, oy, tx, ty, segments) {
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
export function computeVisibility(ox, oy, radius, segments) {
  const angles = endpointAngles(ox, oy, segments, radius);
  for (let i = 0; i < DISC_RAYS; i++) angles.push((i / DISC_RAYS) * Math.PI * 2 - Math.PI);
  const points = angles.map((a) => castRay(ox, oy, a, segments, radius));
  points.sort((p, q) => p.angle - q.angle);
  return points;
}

// A cone facing `facing` with half-width `half`, occluded by walls.
// Returned as a pie polygon that starts and ends at the origin.
export function computeCone(ox, oy, facing, half, radius, segments) {
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
export function normalizeAngle(a) {
  while (a <= -Math.PI) a += Math.PI * 2;
  while (a > Math.PI) a -= Math.PI * 2;
  return a;
}

// True if point p is inside polygon (array of {x,y}). Ray-cast test.
export function pointInPolygon(px, py, poly) {
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
