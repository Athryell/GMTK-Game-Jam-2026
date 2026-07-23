import assert from 'node:assert/strict';
import {
  createPlayer,
  createEnemy,
  createPickup,
  updatePickup,
  easeOutBack,
  findPrimaryTarget,
  findShotgunTargets,
} from '../src/entities.mjs';
import { PICKUP_SPREAD, PICKUP_TWEEN_DURATION, SHOTGUN_OFFSET, SHOTGUN_HALF_LENGTH, SHOTGUN_RADIUS } from '../src/constants.mjs';

function test(name, fn) {
  fn();
  console.log(`ok - ${name}`);
}

test('findPrimaryTarget ignores enemies behind the player', () => {
  const player = createPlayer(0, 0);
  player.angle = 0; // aiming along +x
  const behind = createEnemy(-50, 0);
  assert.equal(findPrimaryTarget(player, [behind], 14), null);
});

test('findPrimaryTarget ignores enemies too far off the aim line', () => {
  const player = createPlayer(0, 0);
  player.angle = 0;
  const offAxis = createEnemy(50, 30);
  assert.equal(findPrimaryTarget(player, [offAxis], 14), null);
});

test('findPrimaryTarget picks the nearest in-line enemy', () => {
  const player = createPlayer(0, 0);
  player.angle = 0;
  const far = createEnemy(100, 0);
  const near = createEnemy(40, 2);
  assert.equal(findPrimaryTarget(player, [far, near], 14), near);
});

test('findShotgunTargets hits enemies inside the paddle-shaped capsule', () => {
  const player = createPlayer(0, 0);
  player.angle = 0; // forward = +x, side = +y
  const inFront = createEnemy(SHOTGUN_OFFSET, 0);
  const tooFarSide = createEnemy(SHOTGUN_OFFSET, SHOTGUN_HALF_LENGTH + SHOTGUN_RADIUS + 5);
  const behindPlayer = createEnemy(-30, 0);
  const opts = { offset: SHOTGUN_OFFSET, halfLength: SHOTGUN_HALF_LENGTH, radius: SHOTGUN_RADIUS };
  const hits = findShotgunTargets(player, [inFront, tooFarSide, behindPlayer], opts);
  assert.deepEqual(hits, [inFront]);
});

test('easeOutBack starts at 0 and ends at 1', () => {
  assert.ok(Math.abs(easeOutBack(0)) < 1e-9);
  assert.equal(easeOutBack(1), 1);
});

test('createPickup offsets stay within the configured spread', () => {
  const pickup = createPickup(100, 100);
  assert.ok(Math.abs(pickup.targetX - 100) <= PICKUP_SPREAD);
  assert.ok(Math.abs(pickup.targetY - 100) <= PICKUP_SPREAD);
});

test('updatePickup settles exactly on the target after the tween duration', () => {
  const pickup = createPickup(0, 0);
  updatePickup(pickup, PICKUP_TWEEN_DURATION + 1);
  assert.equal(pickup.settled, true);
  assert.equal(pickup.x, pickup.targetX);
  assert.equal(pickup.y, pickup.targetY);
});

console.log('all entities tests passed');
