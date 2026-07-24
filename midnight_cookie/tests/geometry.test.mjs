import assert from 'node:assert/strict';
import {
  raySegmentDist,
  segmentsIntersect,
  lineBlocked,
  normalizeAngle,
  pointInPolygon,
  buildWallSegments,
  computeVisibility,
  computeCone,
} from '../src/geometry.mjs';
import { T } from '../src/tiles.mjs';
import { GRID_W, GRID_H, TILE } from '../src/config.mjs';

// raySegmentDist: ray going +x hits a vertical wall at x=100.
{
  const wall = { x1: 100, y1: -50, x2: 100, y2: 50 };
  assert.equal(raySegmentDist(0, 0, 1, 0, wall), 100);
}

// raySegmentDist: ray pointing away from the segment misses.
{
  const wall = { x1: 100, y1: -50, x2: 100, y2: 50 };
  assert.equal(raySegmentDist(0, 0, -1, 0, wall), Infinity);
}

// segmentsIntersect: crossing vs disjoint.
assert.equal(segmentsIntersect(0, 0, 10, 10, 0, 10, 10, 0), true);
assert.equal(segmentsIntersect(0, 0, 1, 0, 0, 5, 1, 5), false);

// lineBlocked: a wall between endpoints blocks; empty set does not.
{
  const wall = [{ x1: 50, y1: -20, x2: 50, y2: 20 }];
  assert.equal(lineBlocked(0, 0, 100, 0, wall), true);
  assert.equal(lineBlocked(0, 0, 100, 0, []), false);
  assert.equal(lineBlocked(0, 0, 0, 100, wall), false);
}

// normalizeAngle wraps into (-PI, PI].
assert.ok(Math.abs(normalizeAngle(Math.PI * 3) - Math.PI) < 1e-9);
assert.ok(Math.abs(normalizeAngle(-Math.PI * 1.5) - Math.PI * 0.5) < 1e-9);

// pointInPolygon on a unit square.
{
  const sq = [{ x: 0, y: 0 }, { x: 10, y: 0 }, { x: 10, y: 10 }, { x: 0, y: 10 }];
  assert.equal(pointInPolygon(5, 5, sq), true);
  assert.equal(pointInPolygon(15, 5, sq), false);
}

// computeVisibility: a wall casts a real shadow. A point behind the wall
// is outside the lit polygon; a point in the open is inside. A bounding
// box stands in for the map border, which always encloses the player.
{
  const box = [
    { x1: -150, y1: -150, x2: 150, y2: -150 },
    { x1: 150, y1: -150, x2: 150, y2: 150 },
    { x1: 150, y1: 150, x2: -150, y2: 150 },
    { x1: -150, y1: 150, x2: -150, y2: -150 },
  ];
  const segs = [...box, { x1: 40, y1: -30, x2: 40, y2: 30 }];
  const poly = computeVisibility(0, 0, 400, segs);
  assert.ok(poly.length >= 3);
  assert.equal(pointInPolygon(20, 0, poly), true); // in front of wall
  assert.equal(pointInPolygon(120, 0, poly), false); // shadowed behind wall
}

// buildWallSegments must read the tile grid so real occlusion works: a
// point behind a wall built from tiles is shadowed. (Regression guard: the
// occluder lookup once ignored its coords and produced no segments.)
{
  const g = [];
  for (let y = 0; y < GRID_H; y++) g.push(new Array(GRID_W).fill(T.FLOOR));
  for (let y = 6; y <= 10; y++) g[y][12] = T.WALL;
  const segs = buildWallSegments(g);
  assert.ok(segs.length > 4, 'a walled grid must yield boundary segments');
  const poly = computeVisibility(11.5 * TILE, 8.5 * TILE, 400, segs);
  assert.equal(pointInPolygon(13.5 * TILE, 8.5 * TILE, poly), false); // behind wall
  assert.equal(pointInPolygon(10.5 * TILE, 8.5 * TILE, poly), true); // in the open
}

// computeCone: pie polygon anchored at the origin, all rays within the cone.
{
  const cone = computeCone(0, 0, 0, Math.PI / 6, 150, []);
  assert.equal(cone[0].x, 0);
  assert.equal(cone[0].y, 0);
  assert.equal(cone[cone.length - 1].x, 0);
  for (const p of cone.slice(1, -1)) {
    const a = Math.atan2(p.y - 0, p.x - 0);
    assert.ok(Math.abs(normalizeAngle(a)) <= Math.PI / 6 + 1e-3);
  }
}

console.log('geometry.test.mjs: all assertions passed');
