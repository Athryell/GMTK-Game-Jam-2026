import { OPPOSITE } from './house.mjs';

export function createRunState(kidsRoom) {
  return {
    currentRoom: kidsRoom,
    phase: 'forward',
    sequence: [],
    backwardIndex: -1,
    hasCookie: false,
  };
}

// Pure state transition for one directional input, independent of timing
// and the DOM, so the forward/reversal mechanic can be unit tested.
export function move(runState, dir) {
  const door = runState.currentRoom.doors[dir];
  if (!door) return { ...runState, outcome: 'blocked' };

  if (runState.phase === 'forward') {
    const sequence = [...runState.sequence, dir];
    if (door.type === 'kitchen') {
      return {
        ...runState,
        sequence,
        currentRoom: door,
        phase: 'backward',
        backwardIndex: sequence.length - 1,
        hasCookie: true,
        outcome: 'cookie-grabbed',
      };
    }
    return { ...runState, sequence, currentRoom: door, outcome: 'moved' };
  }

  if (runState.phase === 'backward') {
    const requiredDir = OPPOSITE[runState.sequence[runState.backwardIndex]];
    if (dir !== requiredDir) {
      return { ...runState, phase: 'lost', outcome: 'wrong-turn' };
    }
    const backwardIndex = runState.backwardIndex - 1;
    if (backwardIndex < 0) {
      return { ...runState, currentRoom: door, backwardIndex, phase: 'won', outcome: 'won' };
    }
    return { ...runState, currentRoom: door, backwardIndex, outcome: 'moved' };
  }

  return { ...runState, outcome: 'blocked' };
}
