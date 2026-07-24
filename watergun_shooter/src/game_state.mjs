// Ported from autoloads/game_state.gd. No Godot signals: game.mjs re-reads
// this plain state object and refreshes the HUD DOM after every mutation.
import { MAX_MOVE, MAX_SHOOT_PRIMARY, MAX_SHOOT_SECONDARY, ALLOC_COST, MOVE_PASSIVE_DRAIN } from './constants.mjs';

export const METER_MAX = {
  move: MAX_MOVE,
  shoot_primary: MAX_SHOOT_PRIMARY,
  shoot_secondary: MAX_SHOOT_SECONDARY,
};

export function createGameState() {
  const state = {
    meters: { move: 0, shoot_primary: 0, shoot_secondary: 0 },
    energy: 0,
    score: 0,
    gameOver: false,
  };
  resetState(state);
  return state;
}

export function resetState(state) {
  state.meters.move = MAX_MOVE;
  state.meters.shoot_primary = MAX_SHOOT_PRIMARY;
  state.meters.shoot_secondary = MAX_SHOOT_SECONDARY;
  state.energy = 0;
  state.score = 0;
  state.gameOver = false;
}

// passive evaporation of the "move" meter only, matching GameState._process
export function tickPassiveDrain(state, dt) {
  spend(state, 'move', MOVE_PASSIVE_DRAIN * dt);
}

export function spend(state, meterName, amount) {
  if (state.meters[meterName] < amount) return false;
  state.meters[meterName] = Math.max(0, state.meters[meterName] - amount);
  return true;
}

export function addEnergy(state, amount) {
  state.energy += amount;
}

export function allocate(state, meterName) {
  const max = METER_MAX[meterName];
  if (state.energy < ALLOC_COST || state.meters[meterName] >= max) return;
  state.energy -= ALLOC_COST;
  state.meters[meterName] = Math.min(max, state.meters[meterName] + ALLOC_COST);
}

export function addScore(state, amount = 1) {
  state.score += amount;
}
