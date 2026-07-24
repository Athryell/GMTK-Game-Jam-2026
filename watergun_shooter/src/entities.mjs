// Ported from scenes/player.gd, scenes/enemy.gd, scenes/pickup.gd.
import * as C from './constants.mjs';
import { spend } from './game_state.mjs';

export function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

export function createPlayer(x, y) {
  return { x, y, angle: 0, primaryCooldown: 0, secondaryCooldown: 0 };
}

export function createEnemy(x, y) {
  return { x, y };
}

export function createPickup(x, y) {
  const spread = C.PICKUP_SPREAD;
  const rx = Math.floor(Math.random() * (spread * 2 + 1)) - spread; // randi_range(-spread, spread)
  const ry = Math.floor(Math.random() * (spread * 2 + 1)) - spread;
  return {
    startX: x,
    startY: y,
    x,
    y,
    targetX: x + rx,
    targetY: y + ry,
    t: 0,
    settled: false,
  };
}

// Tween.EASE_OUT + Tween.TRANS_BACK, matching pickup.gd's create_tween() call.
export function easeOutBack(t) {
  const c1 = 1.70158;
  const c3 = c1 + 1;
  const x = clamp(t, 0, 1);
  return 1 + c3 * Math.pow(x - 1, 3) + c1 * Math.pow(x - 1, 2);
}

export function updatePickup(pickup, dt) {
  if (pickup.settled) return;
  pickup.t += dt;
  const p = easeOutBack(pickup.t / C.PICKUP_TWEEN_DURATION);
  pickup.x = pickup.startX + (pickup.targetX - pickup.startX) * p;
  pickup.y = pickup.startY + (pickup.targetY - pickup.startY) * p;
  if (pickup.t >= C.PICKUP_TWEEN_DURATION) {
    pickup.x = pickup.targetX;
    pickup.y = pickup.targetY;
    pickup.settled = true;
  }
}

export function updateEnemy(enemy, player, dt) {
  const dx = player.x - enemy.x;
  const dy = player.y - enemy.y;
  const dist = Math.hypot(dx, dy) || 1;
  enemy.x += (dx / dist) * C.ENEMY_SPEED * dt;
  enemy.y += (dy / dist) * C.ENEMY_SPEED * dt;
}

export function updatePlayerMovement(player, input, state, dt) {
  let ix = (input.right ? 1 : 0) - (input.left ? 1 : 0);
  let iy = (input.down ? 1 : 0) - (input.up ? 1 : 0);
  const len = Math.hypot(ix, iy);
  if (len === 0) return false;
  ix /= len;
  iy /= len;

  if (state.meters.move > 0.01) {
    player.x += ix * C.PLAYER_SPEED * dt;
    player.y += iy * C.PLAYER_SPEED * dt;
    spend(state, 'move', C.PLAYER_MOVE_DRAIN * dt);
  } else {
    player.x += ix * C.PLAYER_SPEED * C.PLAYER_SLOW_MULTIPLIER * dt;
    player.y += iy * C.PLAYER_SPEED * C.PLAYER_SLOW_MULTIPLIER * dt;
  }
  return true;
}

// Hitscan along the aim ray: picks the nearest enemy within hitRadius of the
// ray, matching the projection/perpendicular-distance loop in _try_shoot_primary.
export function findPrimaryTarget(player, enemies, hitRadius) {
  const aimX = Math.cos(player.angle);
  const aimY = Math.sin(player.angle);
  let closest = null;
  let closestProj = Infinity;
  for (const enemy of enemies) {
    const toX = enemy.x - player.x;
    const toY = enemy.y - player.y;
    const proj = toX * aimX + toY * aimY;
    if (proj < 0) continue;
    const closestX = player.x + aimX * proj;
    const closestY = player.y + aimY * proj;
    const perpDist = Math.hypot(enemy.x - closestX, enemy.y - closestY);
    if (perpDist <= hitRadius && proj < closestProj) {
      closestProj = proj;
      closest = enemy;
    }
  }
  return closest;
}

// Capsule check for the shotgun: capsule long axis runs sideways (perpendicular
// to the aim direction), offset forward of the player, matching the
// ShotgunArea/CollisionShape2D layout in player.tscn.
export function findShotgunTargets(player, enemies, { offset, halfLength, radius }) {
  const fx = Math.cos(player.angle);
  const fy = Math.sin(player.angle);
  const sx = -fy;
  const sy = fx;
  const hits = [];
  for (const enemy of enemies) {
    const dx = enemy.x - player.x;
    const dy = enemy.y - player.y;
    const forward = dx * fx + dy * fy - offset;
    const side = dx * sx + dy * sy;
    const clampedSide = clamp(side, -halfLength, halfLength);
    const distSq = forward * forward + (side - clampedSide) * (side - clampedSide);
    if (distSq <= radius * radius) hits.push(enemy);
  }
  return hits;
}
