export const DIRS = ['up', 'down', 'left', 'right'];
export const OPPOSITE = { up: 'down', down: 'up', left: 'right', right: 'left' };

export const ROOM_TYPES = {
  kidsroom: { label: "Kid's Room", color: '#9e9e9e', max: 1, deadEnd: true },
  kitchen: { label: 'Kitchen', color: '#ff8fc7', max: 1, deadEnd: true },
  bathroom: { label: 'Bathroom', color: '#4aa8ff', max: 5, deadEnd: true },
  bedroom: { label: 'Bedroom', color: '#4caf50', max: 5, deadEnd: true },
  studio: { label: 'Studio', color: '#9c6ade', max: 2, deadEnd: true },
  diningroom: { label: 'Dining Room', color: '#f2f2f2', max: 2, deadEnd: false },
  livingroom: { label: 'Living Room', color: '#e05353', max: 2, deadEnd: false },
  hallway: { label: 'Hallway', color: '#8d5b3c', max: 4, deadEnd: false },
};

const HUB_TYPES = ['diningroom', 'livingroom', 'hallway'];
const DECOY_TYPES = ['bathroom', 'bedroom', 'studio'];

// hubCount is capped so that hubCount * 2 decoy slots never exceeds the
// total decoy room budget (bathroom + bedroom + studio maxes = 12).
export const MIN_HUBS = 2;
export const MAX_HUBS = 4;

let nextId = 1;

function makeRoom(type) {
  return { id: nextId++, type, doors: { up: null, down: null, left: null, right: null } };
}

function shuffled(arr) {
  const copy = arr.slice();
  for (let i = copy.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy;
}

function pickAvailable(types, counts) {
  const available = types.filter((t) => counts[t] < ROOM_TYPES[t].max);
  if (available.length === 0) return null;
  return available[Math.floor(Math.random() * available.length)];
}

function connect(parent, child, parentToChildDir) {
  parent.doors[parentToChildDir] = child;
  child.doors[OPPOSITE[parentToChildDir]] = parent;
}

// Builds a random house as a tree: a chain of "hub" rooms (always exactly
// 4 doors) from the kid's room to the kitchen, with dead-end rooms (always
// exactly 1 door) hanging off each hub as decoy branches.
export function generateHouse() {
  const counts = Object.fromEntries(Object.keys(ROOM_TYPES).map((t) => [t, 0]));

  const kidsRoom = makeRoom('kidsroom');
  counts.kidsroom++;

  const hubCount = MIN_HUBS + Math.floor(Math.random() * (MAX_HUBS - MIN_HUBS + 1));

  let parent = kidsRoom;
  let exitDir = shuffled(DIRS)[0];

  for (let i = 0; i < hubCount; i++) {
    const hubType = pickAvailable(HUB_TYPES, counts);
    if (!hubType) break;
    counts[hubType]++;
    const hub = makeRoom(hubType);
    connect(parent, hub, exitDir);

    const entrySide = OPPOSITE[exitDir];
    const [forwardSide, ...decoySides] = shuffled(DIRS.filter((d) => d !== entrySide));

    for (const side of decoySides) {
      const decoyType = pickAvailable(DECOY_TYPES, counts);
      if (!decoyType) continue;
      counts[decoyType]++;
      connect(hub, makeRoom(decoyType), side);
    }

    parent = hub;
    exitDir = forwardSide;
  }

  counts.kitchen++;
  connect(parent, makeRoom('kitchen'), exitDir);

  return kidsRoom;
}
