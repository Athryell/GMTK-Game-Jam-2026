import assert from 'node:assert/strict';
import { createGameState, resetState, tickPassiveDrain, spend, addEnergy, allocate, addScore } from '../src/game_state.mjs';
import { MAX_MOVE, MAX_SHOOT_SECONDARY } from '../src/constants.mjs';

function test(name, fn) {
  fn();
  console.log(`ok - ${name}`);
}

test('spend refuses when amount exceeds the meter and leaves it untouched', () => {
  const state = createGameState();
  state.meters.move = 0.5;
  assert.equal(spend(state, 'move', 1.0), false);
  assert.equal(state.meters.move, 0.5);
});

test('spend clamps to zero and never goes negative', () => {
  const state = createGameState();
  state.meters.shoot_primary = 1.0;
  assert.equal(spend(state, 'shoot_primary', 1.0), true);
  assert.equal(state.meters.shoot_primary, 0);
});

test('tickPassiveDrain only drains the move meter', () => {
  const state = createGameState();
  const gunBefore = state.meters.shoot_primary;
  const shotgunBefore = state.meters.shoot_secondary;
  tickPassiveDrain(state, 1);
  assert.equal(state.meters.move, MAX_MOVE - 0.1);
  assert.equal(state.meters.shoot_primary, gunBefore);
  assert.equal(state.meters.shoot_secondary, shotgunBefore);
});

test('allocate spends 1 energy to refill 1 unit of a meter, capped at max', () => {
  const state = createGameState();
  state.meters.shoot_secondary = MAX_SHOOT_SECONDARY - 0.5;
  addEnergy(state, 2);
  allocate(state, 'shoot_secondary');
  assert.equal(state.meters.shoot_secondary, MAX_SHOOT_SECONDARY);
  assert.equal(state.energy, 1);
});

test('allocate does nothing without enough energy', () => {
  const state = createGameState();
  state.meters.move = 5;
  state.energy = 0;
  allocate(state, 'move');
  assert.equal(state.meters.move, 5);
  assert.equal(state.energy, 0);
});

test('allocate does nothing once the meter is already at max', () => {
  const state = createGameState();
  addEnergy(state, 5);
  allocate(state, 'move');
  assert.equal(state.meters.move, MAX_MOVE);
  assert.equal(state.energy, 5);
});

test('addScore accumulates and resetState restores defaults', () => {
  const state = createGameState();
  addScore(state, 3);
  addScore(state);
  assert.equal(state.score, 4);
  state.gameOver = true;
  resetState(state);
  assert.equal(state.score, 0);
  assert.equal(state.energy, 0);
  assert.equal(state.gameOver, false);
  assert.equal(state.meters.move, MAX_MOVE);
});

console.log('all game_state tests passed');
