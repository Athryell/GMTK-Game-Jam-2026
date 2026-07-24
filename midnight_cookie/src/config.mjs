// Distances in world pixels, times in ms, angles in radians. Tiles only
// build the level; movement and vision are fully continuous / vector based.
export const TILE = 40;

export const GRID_W = 44;
export const GRID_H = 30;

export const WORLD_W = GRID_W * TILE;
export const WORLD_H = GRID_H * TILE;

export const VIEW_W = 1000;
export const VIEW_H = 680;

export const PLAYER_RADIUS = 11;
export const PLAYER_SPEED = 168;
export const PLAYER_VIEW_RADIUS = 240;

export const MOTHER_RADIUS = 13;
export const MOTHER_SPEED = 116; // slower than the player, so she is escapable
export const MOTHER_CONE_HALF_ANGLE = Math.PI * 0.22;
export const MOTHER_CONE_RANGE = 300;
export const MOTHER_NOISE_INTERVAL_MS = 1500;
export const MOTHER_NOISE_MAX_RADIUS = 90;
export const MOTHER_REPATH_SLOP = 6;
export const MOTHER_HEARING_RADIUS = 230; // she homes in on the player within this range while they move

// Breath: you can only hold still-and-silent for so long. The meter drains
// while holding breath and refills only by moving in the open (which is
// noisy); empty means you gasp and she can hear you.
export const BREATH_MAX_MS = 5000;
export const BREATH_REFILL_RATE = 1.5;

// Bed check: the recurring countdown that is the heart of the game. Each
// survived check shortens the next window, down to the floor.
export const BED_CHECK_START_MS = 15000;
export const BED_CHECK_MIN_MS = 5000;
export const BED_CHECK_STEP_MS = 2000;
export const CHECK_TELEGRAPH_MS = 3000; // final "get to cover 3..2..1" window

export const COOKIE_PICKUP_DIST = 26;
export const WIN_DIST = 34;

export const COLORS = {
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
