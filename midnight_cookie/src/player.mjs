import { PLAYER_RADIUS, PLAYER_SPEED } from './config.mjs';
import { walkableAtPixel } from './house.mjs';

export function createPlayer(spawn) {
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

export function updatePlayer(player, input, grid, dtSeconds) {
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
