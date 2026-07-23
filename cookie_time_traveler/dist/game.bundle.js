(() => {
'use strict';
const DIRS = ['up', 'down', 'left', 'right'];
const OPPOSITE = { up: 'down', down: 'up', left: 'right', right: 'left' };

const ROOM_TYPES = {
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
const MIN_HUBS = 2;
const MAX_HUBS = 4;

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
function generateHouse() {
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


function createRunState(kidsRoom) {
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
function move(runState, dir) {
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


const MAX_FORWARD_MS = 25000;
const LIGHT_DURATION_MS = 18000;
const DARK_DOOR_COLOR = '#333333';

function hexToRgb(hex) {
  const n = parseInt(hex.slice(1), 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

// Fades a door's fill color toward DARK_DOOR_COLOR as light runs out,
// without touching opacity - the border (which always marks "a door
// exists here") must stay fully visible regardless of light level.
function litColor(hex, fraction) {
  const [r1, g1, b1] = hexToRgb(hex);
  const [r2, g2, b2] = hexToRgb(DARK_DOOR_COLOR);
  const mix = (a, b) => Math.round(b + (a - b) * fraction);
  return `rgb(${mix(r1, r2)}, ${mix(g1, g2)}, ${mix(b1, b2)})`;
}

const el = {
  phaseLabel: document.getElementById('phase-label'),
  timerFill: document.getElementById('timer-fill'),
  timerText: document.getElementById('timer-text'),
  lightBar: document.getElementById('light-bar'),
  lightFill: document.getElementById('light-fill'),
  room: document.getElementById('room'),
  roomLabel: document.getElementById('room-label'),
  kid: document.getElementById('kid'),
  cookie: document.getElementById('cookie'),
  doors: {
    up: document.getElementById('door-up'),
    down: document.getElementById('door-down'),
    left: document.getElementById('door-left'),
    right: document.getElementById('door-right'),
  },
  message: document.getElementById('message'),
  messageText: document.getElementById('message-text'),
  restart: document.getElementById('restart'),
  restartHud: document.getElementById('restart-hud'),
};

let state = null;

function newRun() {
  state = {
    ...createRunState(generateHouse()),
    forwardStartTime: performance.now(),
    backwardStartTime: null,
    backwardLimitMs: null,
  };
  el.message.hidden = true;
  render();
}

function endRun(phase, text) {
  state.phase = phase;
  el.messageText.textContent = text;
  el.message.hidden = false;
  render();
}

function attemptMove(dir) {
  if (!state || (state.phase !== 'forward' && state.phase !== 'backward')) return;
  const { outcome, ...next } = move(state, dir);
  state = { ...state, ...next };

  if (outcome === 'cookie-grabbed') {
    const elapsed = performance.now() - state.forwardStartTime;
    state.backwardLimitMs = elapsed;
    state.backwardStartTime = performance.now();
  } else if (outcome === 'wrong-turn') {
    endRun('lost', "Wrong way! Mom will notice the missing cookie.");
    return;
  } else if (outcome === 'won') {
    endRun('won', "Back in bed before Mom noticed a thing.");
    return;
  }
  render();
}

function lightFraction() {
  if (!state || state.phase !== 'forward') return 0;
  const elapsed = performance.now() - state.forwardStartTime;
  return Math.max(0, 1 - elapsed / LIGHT_DURATION_MS);
}

function render() {
  if (!state) return;
  const room = state.currentRoom;
  const def = ROOM_TYPES[room.type];

  el.room.style.backgroundColor = def.color;
  el.roomLabel.textContent = def.label;
  el.kid.hidden = false;
  el.cookie.hidden = !state.hasCookie;

  const light = lightFraction();
  for (const dir of DIRS) {
    const doorEl = el.doors[dir];
    const neighbor = room.doors[dir];
    doorEl.classList.toggle('wall', !neighbor);
    doorEl.classList.toggle('open', !!neighbor);
    if (!neighbor) {
      doorEl.style.backgroundColor = '';
      continue;
    }

    doorEl.style.backgroundColor =
      state.phase === 'forward' ? litColor(ROOM_TYPES[neighbor.type].color, light) : DARK_DOOR_COLOR;
  }

  el.phaseLabel.textContent =
    state.phase === 'forward'
      ? 'Sneak to the kitchen'
      : state.phase === 'backward'
      ? 'Sneak back to bed'
      : state.phase === 'won'
      ? 'Success'
      : 'Caught';

  el.lightBar.hidden = state.phase !== 'forward';
}

function tick() {
  if (state && state.phase === 'forward') {
    const elapsed = performance.now() - state.forwardStartTime;
    const remaining = Math.max(0, MAX_FORWARD_MS - elapsed);
    el.timerFill.style.width = `${(remaining / MAX_FORWARD_MS) * 100}%`;
    el.timerText.textContent = (remaining / 1000).toFixed(1);
    el.lightFill.style.width = `${lightFraction() * 100}%`;
    if (remaining <= 0) {
      endRun('lost', "Mom's home! She caught you out of your room.");
    } else {
      render();
    }
  } else if (state && state.phase === 'backward') {
    const elapsed = performance.now() - state.backwardStartTime;
    const remaining = Math.max(0, state.backwardLimitMs - elapsed);
    el.timerFill.style.width = `${(remaining / state.backwardLimitMs) * 100}%`;
    el.timerText.textContent = (remaining / 1000).toFixed(1);
    if (remaining <= 0) {
      endRun('lost', "Time's up! Mom will notice the missing cookie.");
    }
  }
  requestAnimationFrame(tick);
}

const KEY_TO_DIR = {
  ArrowUp: 'up',
  ArrowDown: 'down',
  ArrowLeft: 'left',
  ArrowRight: 'right',
  KeyW: 'up',
  KeyS: 'down',
  KeyA: 'left',
  KeyD: 'right',
};

window.addEventListener('keydown', (event) => {
  const dir = KEY_TO_DIR[event.code];
  if (!dir) return;
  event.preventDefault();
  attemptMove(dir);
});

for (const [dir, doorEl] of Object.entries(el.doors)) {
  doorEl.addEventListener('click', () => attemptMove(dir));
}

el.restart.addEventListener('click', newRun);
el.restartHud.addEventListener('click', newRun);

newRun();
requestAnimationFrame(tick);

})();
