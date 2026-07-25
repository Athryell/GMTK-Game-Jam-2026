import {
  TILE,
  GRID_W,
  BED_CHECK_START_MS,
  BED_CHECK_MIN_MS,
  BED_CHECK_STEP_MS,
  BREATH_MAX_MS,
  BREATH_REFILL_RATE,
  COOKIE_PICKUP_DIST,
  WIN_DIST,
} from './config.mjs';
import { generateHouse } from './house.mjs';
import { buildWallSegments, lineBlocked } from './geometry.mjs';
import { createPlayer, updatePlayer } from './player.mjs';
import {
  createMother,
  updateMother,
  motherSeesPlayer,
  isPlayerHidden,
} from './mother.mjs';

// Chosen from the menu before a run starts; createGame reads it each time.
export const gameOptions = { startMs: BED_CHECK_START_MS };

function checkWindow(round, startMs) {
  return Math.max(BED_CHECK_MIN_MS, startMs - (round - 1) * BED_CHECK_STEP_MS);
}

export function createGame() {
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

export function updateGame(state, input, dtSeconds) {
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
