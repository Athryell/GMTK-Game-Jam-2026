import assert from 'node:assert/strict';
import { generateHouse, ROOM_TYPES, DIRS, MIN_HUBS, MAX_HUBS } from '../src/house.mjs';

function collectRooms(root) {
  const dist = new Map([[root, 0]]);
  const queue = [root];
  while (queue.length) {
    const room = queue.shift();
    for (const dir of DIRS) {
      const next = room.doors[dir];
      if (next && !dist.has(next)) {
        dist.set(next, dist.get(room) + 1);
        queue.push(next);
      }
    }
  }
  return dist;
}

const RUNS = 500;
for (let run = 0; run < RUNS; run++) {
  const kidsRoom = generateHouse();
  const rooms = collectRooms(kidsRoom);

  assert.equal(kidsRoom.type, 'kidsroom');

  const counts = {};
  let edgeEndpoints = 0;
  let kitchenDist = -1;

  for (const [room, dist] of rooms) {
    counts[room.type] = (counts[room.type] || 0) + 1;
    const doorCount = DIRS.filter((d) => room.doors[d]).length;
    edgeEndpoints += doorCount;

    const expected = ROOM_TYPES[room.type].deadEnd ? 1 : 4;
    assert.equal(
      doorCount,
      expected,
      `run ${run}: ${room.type} should have ${expected} door(s), got ${doorCount}`
    );

    if (room.type === 'kitchen') kitchenDist = dist;
  }

  for (const [type, def] of Object.entries(ROOM_TYPES)) {
    assert.ok(
      (counts[type] || 0) <= def.max,
      `run ${run}: ${type} count ${counts[type]} exceeds max ${def.max}`
    );
  }

  assert.equal(counts.kidsroom, 1, `run ${run}: exactly one kidsroom expected`);
  assert.equal(counts.kitchen, 1, `run ${run}: exactly one kitchen expected`);
  assert.ok(kitchenDist >= 0, `run ${run}: kitchen must be reachable from kidsroom`);

  // Each door is stored on both sides of the connection, so summing every
  // room's door count double-counts every edge in the house.
  assert.equal(
    edgeEndpoints / 2,
    rooms.size - 1,
    `run ${run}: house should be a tree (no cycles), got ${rooms.size} rooms / ${edgeEndpoints / 2} edges`
  );

  assert.ok(
    kitchenDist >= MIN_HUBS + 1 && kitchenDist <= MAX_HUBS + 1,
    `run ${run}: kitchen path length ${kitchenDist} out of expected [${MIN_HUBS + 1}, ${MAX_HUBS + 1}]`
  );
}

console.log(`OK: ${RUNS} generated houses passed all invariants.`);
