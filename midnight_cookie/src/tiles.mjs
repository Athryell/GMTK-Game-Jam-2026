import { GRID_W, GRID_H } from './config.mjs';

// Tile kinds used by the level builder. Only WALL and TABLE block
// vision; only WALL blocks movement. TABLE is walkable and also acts as
// a hiding spot (Mom cannot see the player standing on one).

export const T = {
  WALL: 0,
  FLOOR: 1,
  TABLE: 2,
};

// Tile kind at grid coords, treating out-of-bounds as solid wall.
export function tileKindAt(grid, tx, ty) {
  if (tx < 0 || ty < 0 || tx >= GRID_W || ty >= GRID_H) return T.WALL;
  return grid[ty][tx];
}

export function isWalkable(kind) {
  return kind === T.FLOOR || kind === T.TABLE;
}

// Occluders block line of sight, for both the visibility polygon and
// Mom's detection ray.
export function isOccluder(kind) {
  return kind === T.WALL || kind === T.TABLE;
}
