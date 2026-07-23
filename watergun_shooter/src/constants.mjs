// Ported 1:1 from autoloads/constants.gd + autoloads/game_state.gd defaults
// and the @export values on scenes/player.gd, scenes/enemy.gd, scenes/arena.gd,
// scenes/pickup.gd (Godot source of truth for this game).

export const MAX_MOVE = 10.0;
export const MAX_SHOOT_PRIMARY = 10.0;
export const MAX_SHOOT_SECONDARY = 3.0;
export const ALLOC_COST = 1.0;
export const PICKUP_VALUE = 1.0;
export const MOVE_PASSIVE_DRAIN = 0.1;
export const ENERGY_BAR_MAX = 100.0;

export const PLAYER_RADIUS = 11;
export const PLAYER_SPEED = 260.0;
export const PLAYER_MOVE_DRAIN = 1.5;
export const PLAYER_SLOW_MULTIPLIER = 0.35;
export const PRIMARY_COOLDOWN = 0.18;
export const PRIMARY_HIT_RADIUS = 14;
export const SECONDARY_COOLDOWN = 0.6;
export const SHOTGUN_OFFSET = 26;
export const SHOTGUN_RADIUS = 20;
export const SHOTGUN_HALF_LENGTH = 7; // (capsule height 54 - 2 * radius 20) / 2
export const AIM_LINE_LENGTH = 20;

export const ENEMY_RADIUS = 11;
export const ENEMY_SPEED = 90.0;
export const HURT_CONTACT_DIST = PLAYER_RADIUS + ENEMY_RADIUS;

export const PICKUP_RADIUS = 5;
export const PICKUP_COLLECT_DIST = PLAYER_RADIUS + PICKUP_RADIUS;
export const PICKUP_SPREAD = 12;
export const PICKUP_TWEEN_DURATION = 0.3;
export const PICKUP_MIN_COUNT = 2;
export const PICKUP_MAX_COUNT = 4;

export const SPAWN_INTERVAL = 2.0;
export const MIN_SPAWN_INTERVAL = 0.6;
export const SPAWN_DECREASE_PER_KILL = 0.02;
export const SPAWN_EDGE_MARGIN = 20;

export const REFILL_REPEAT_INTERVAL = 0.15;
