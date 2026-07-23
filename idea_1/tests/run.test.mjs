import assert from 'node:assert/strict';
import { DIRS, OPPOSITE, generateHouse } from '../src/house.mjs';
import { createRunState, move } from '../src/run.mjs';

// The house is a tree, so there is exactly one path from the kid's room
// to the kitchen; BFS reconstructs the sequence of directions for it.
function findPathToKitchen(kidsRoom) {
  const cameFrom = new Map([[kidsRoom, null]]);
  const queue = [kidsRoom];
  let kitchen = null;
  while (queue.length) {
    const room = queue.shift();
    if (room.type === 'kitchen') {
      kitchen = room;
      break;
    }
    for (const dir of DIRS) {
      const next = room.doors[dir];
      if (next && !cameFrom.has(next)) {
        cameFrom.set(next, { parent: room, dir });
        queue.push(next);
      }
    }
  }
  const path = [];
  let node = kitchen;
  while (cameFrom.get(node)) {
    const { parent, dir } = cameFrom.get(node);
    path.unshift(dir);
    node = parent;
  }
  return path;
}

function playSequence(runState, dirs) {
  let s = runState;
  const outcomes = [];
  for (const dir of dirs) {
    const result = move(s, dir);
    outcomes.push(result.outcome);
    s = result;
  }
  return { state: s, outcomes };
}

// 1. Straight run: walk the true path forward, then its exact reversal.
for (let run = 0; run < 200; run++) {
  const kidsRoom = generateHouse();
  const forwardPath = findPathToKitchen(kidsRoom);
  assert.ok(forwardPath.length > 0, 'expected a non-empty path to the kitchen');

  let s = createRunState(kidsRoom);
  const forward = playSequence(s, forwardPath);
  assert.equal(forward.state.phase, 'backward', 'should enter backward phase on reaching the kitchen');
  assert.equal(forward.state.hasCookie, true);
  assert.deepEqual(
    forward.outcomes.slice(0, -1),
    forward.outcomes.slice(0, -1).map(() => 'moved')
  );
  assert.equal(forward.outcomes.at(-1), 'cookie-grabbed');

  const reversedPath = [...forwardPath].reverse().map((d) => OPPOSITE[d]);
  const backward = playSequence(forward.state, reversedPath);
  assert.equal(backward.state.phase, 'won', 'exact reversal should win the run');
  assert.equal(backward.state.currentRoom.type, 'kidsroom');
  assert.equal(backward.outcomes.at(-1), 'won');
}

// 2. A dead-end detour forward must still be exactly reversible.
{
  const kidsRoom = generateHouse();
  const forwardPath = findPathToKitchen(kidsRoom);
  let s = createRunState(kidsRoom);

  // Step onto the first hub, then take a detour into any decoy dead end
  // and back out (if one exists) before continuing toward the kitchen.
  const step1 = move(s, forwardPath[0]);
  assert.equal(step1.outcome, 'moved');
  s = step1;

  const decoyDir = DIRS.find(
    (d) => d !== OPPOSITE[forwardPath[0]] && d !== forwardPath[1] && s.currentRoom.doors[d]
  );
  let detourDirs = [];
  if (decoyDir) {
    const into = move(s, decoyDir);
    assert.equal(into.outcome, 'moved');
    const back = move(into, OPPOSITE[decoyDir]);
    assert.equal(back.outcome, 'moved');
    assert.equal(back.currentRoom, s.currentRoom, 'should return to the same hub');
    s = back;
    detourDirs = [decoyDir, OPPOSITE[decoyDir]];
  }

  const rest = playSequence(s, forwardPath.slice(1));
  assert.equal(rest.state.phase, 'backward');

  const fullForward = [forwardPath[0], ...detourDirs, ...forwardPath.slice(1)];
  assert.deepEqual(rest.state.sequence, fullForward, 'sequence should record the detour moves');

  const reversedPath = [...fullForward].reverse().map((d) => OPPOSITE[d]);
  const backward = playSequence(rest.state, reversedPath);
  assert.equal(backward.state.phase, 'won', 'reversing a run with a detour should still win');
}

// 3. A wrong turn during backward at a hub must lose immediately. The
// kitchen itself only has one door (forced, correct move by construction),
// so the earliest a wrong turn is even possible is one step further back,
// at the hub the kitchen hangs off of.
{
  const kidsRoom = generateHouse();
  const forwardPath = findPathToKitchen(kidsRoom);
  const forward = playSequence(createRunState(kidsRoom), forwardPath);
  assert.equal(forward.state.phase, 'backward');

  const backOneStep = move(forward.state, OPPOSITE[forwardPath.at(-1)]);
  assert.equal(backOneStep.outcome, 'moved');

  const correctDir = OPPOSITE[forwardPath.at(-2)];
  const wrongDir = DIRS.find((d) => d !== correctDir && backOneStep.currentRoom.doors[d]);
  assert.ok(wrongDir, 'the hub before the kitchen always has 4 real doors');

  const result = move(backOneStep, wrongDir);
  assert.equal(result.outcome, 'wrong-turn');
  assert.equal(result.phase, 'lost');
}

console.log('OK: forward/backward reversal mechanic verified across generated houses.');
