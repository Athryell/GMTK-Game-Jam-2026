(() => {
'use strict';
// Ported 1:1 from autoloads/constants.gd + autoloads/game_state.gd defaults
// and the @export values on scenes/player.gd, scenes/enemy.gd, scenes/arena.gd,
// scenes/pickup.gd (Godot source of truth for this game).

const MAX_MOVE = 10.0;
const MAX_SHOOT_PRIMARY = 10.0;
const MAX_SHOOT_SECONDARY = 3.0;
const ALLOC_COST = 1.0;
const PICKUP_VALUE = 1.0;
const MOVE_PASSIVE_DRAIN = 0.1;
const ENERGY_BAR_MAX = 100.0;

const PLAYER_RADIUS = 11;
const PLAYER_SPEED = 260.0;
const PLAYER_MOVE_DRAIN = 1.5;
const PLAYER_SLOW_MULTIPLIER = 0.35;
const PRIMARY_COOLDOWN = 0.18;
const PRIMARY_HIT_RADIUS = 14;
const SECONDARY_COOLDOWN = 0.6;
const SHOTGUN_OFFSET = 26;
const SHOTGUN_RADIUS = 20;
const SHOTGUN_HALF_LENGTH = 7; // (capsule height 54 - 2 * radius 20) / 2
const AIM_LINE_LENGTH = 20;

const ENEMY_RADIUS = 11;
const ENEMY_SPEED = 90.0;
const HURT_CONTACT_DIST = PLAYER_RADIUS + ENEMY_RADIUS;

const PICKUP_RADIUS = 5;
const PICKUP_COLLECT_DIST = PLAYER_RADIUS + PICKUP_RADIUS;
const PICKUP_SPREAD = 12;
const PICKUP_TWEEN_DURATION = 0.3;
const PICKUP_MIN_COUNT = 2;
const PICKUP_MAX_COUNT = 4;

const SPAWN_INTERVAL = 2.0;
const MIN_SPAWN_INTERVAL = 0.6;
const SPAWN_DECREASE_PER_KILL = 0.02;
const SPAWN_EDGE_MARGIN = 20;

const REFILL_REPEAT_INTERVAL = 0.15;

// Ported from autoloads/game_state.gd. No Godot signals: game.mjs re-reads
// this plain state object and refreshes the HUD DOM after every mutation.

const METER_MAX = {
  move: MAX_MOVE,
  shoot_primary: MAX_SHOOT_PRIMARY,
  shoot_secondary: MAX_SHOOT_SECONDARY,
};

function createGameState() {
  const state = {
    meters: { move: 0, shoot_primary: 0, shoot_secondary: 0 },
    energy: 0,
    score: 0,
    gameOver: false,
  };
  resetState(state);
  return state;
}

function resetState(state) {
  state.meters.move = MAX_MOVE;
  state.meters.shoot_primary = MAX_SHOOT_PRIMARY;
  state.meters.shoot_secondary = MAX_SHOOT_SECONDARY;
  state.energy = 0;
  state.score = 0;
  state.gameOver = false;
}

// passive evaporation of the "move" meter only, matching GameState._process
function tickPassiveDrain(state, dt) {
  spend(state, 'move', MOVE_PASSIVE_DRAIN * dt);
}

function spend(state, meterName, amount) {
  if (state.meters[meterName] < amount) return false;
  state.meters[meterName] = Math.max(0, state.meters[meterName] - amount);
  return true;
}

function addEnergy(state, amount) {
  state.energy += amount;
}

function allocate(state, meterName) {
  const max = METER_MAX[meterName];
  if (state.energy < ALLOC_COST || state.meters[meterName] >= max) return;
  state.energy -= ALLOC_COST;
  state.meters[meterName] = Math.min(max, state.meters[meterName] + ALLOC_COST);
}

function addScore(state, amount = 1) {
  state.score += amount;
}

// Ported from scenes/player.gd, scenes/enemy.gd, scenes/pickup.gd.
const C = { MAX_MOVE, MAX_SHOOT_PRIMARY, MAX_SHOOT_SECONDARY, ALLOC_COST, PICKUP_VALUE, MOVE_PASSIVE_DRAIN, ENERGY_BAR_MAX, PLAYER_RADIUS, PLAYER_SPEED, PLAYER_MOVE_DRAIN, PLAYER_SLOW_MULTIPLIER, PRIMARY_COOLDOWN, PRIMARY_HIT_RADIUS, SECONDARY_COOLDOWN, SHOTGUN_OFFSET, SHOTGUN_RADIUS, SHOTGUN_HALF_LENGTH, AIM_LINE_LENGTH, ENEMY_RADIUS, ENEMY_SPEED, HURT_CONTACT_DIST, PICKUP_RADIUS, PICKUP_COLLECT_DIST, PICKUP_SPREAD, PICKUP_TWEEN_DURATION, PICKUP_MIN_COUNT, PICKUP_MAX_COUNT, SPAWN_INTERVAL, MIN_SPAWN_INTERVAL, SPAWN_DECREASE_PER_KILL, SPAWN_EDGE_MARGIN, REFILL_REPEAT_INTERVAL };

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function createPlayer(x, y) {
  return { x, y, angle: 0, primaryCooldown: 0, secondaryCooldown: 0 };
}

function createEnemy(x, y) {
  return { x, y };
}

function createPickup(x, y) {
  const spread = C.PICKUP_SPREAD;
  const rx = Math.floor(Math.random() * (spread * 2 + 1)) - spread; // randi_range(-spread, spread)
  const ry = Math.floor(Math.random() * (spread * 2 + 1)) - spread;
  return {
    startX: x,
    startY: y,
    x,
    y,
    targetX: x + rx,
    targetY: y + ry,
    t: 0,
    settled: false,
  };
}

// Tween.EASE_OUT + Tween.TRANS_BACK, matching pickup.gd's create_tween() call.
function easeOutBack(t) {
  const c1 = 1.70158;
  const c3 = c1 + 1;
  const x = clamp(t, 0, 1);
  return 1 + c3 * Math.pow(x - 1, 3) + c1 * Math.pow(x - 1, 2);
}

function updatePickup(pickup, dt) {
  if (pickup.settled) return;
  pickup.t += dt;
  const p = easeOutBack(pickup.t / C.PICKUP_TWEEN_DURATION);
  pickup.x = pickup.startX + (pickup.targetX - pickup.startX) * p;
  pickup.y = pickup.startY + (pickup.targetY - pickup.startY) * p;
  if (pickup.t >= C.PICKUP_TWEEN_DURATION) {
    pickup.x = pickup.targetX;
    pickup.y = pickup.targetY;
    pickup.settled = true;
  }
}

function updateEnemy(enemy, player, dt) {
  const dx = player.x - enemy.x;
  const dy = player.y - enemy.y;
  const dist = Math.hypot(dx, dy) || 1;
  enemy.x += (dx / dist) * C.ENEMY_SPEED * dt;
  enemy.y += (dy / dist) * C.ENEMY_SPEED * dt;
}

function updatePlayerMovement(player, input, state, dt) {
  let ix = (input.right ? 1 : 0) - (input.left ? 1 : 0);
  let iy = (input.down ? 1 : 0) - (input.up ? 1 : 0);
  const len = Math.hypot(ix, iy);
  if (len === 0) return false;
  ix /= len;
  iy /= len;

  if (state.meters.move > 0.01) {
    player.x += ix * C.PLAYER_SPEED * dt;
    player.y += iy * C.PLAYER_SPEED * dt;
    spend(state, 'move', C.PLAYER_MOVE_DRAIN * dt);
  } else {
    player.x += ix * C.PLAYER_SPEED * C.PLAYER_SLOW_MULTIPLIER * dt;
    player.y += iy * C.PLAYER_SPEED * C.PLAYER_SLOW_MULTIPLIER * dt;
  }
  return true;
}

// Hitscan along the aim ray: picks the nearest enemy within hitRadius of the
// ray, matching the projection/perpendicular-distance loop in _try_shoot_primary.
function findPrimaryTarget(player, enemies, hitRadius) {
  const aimX = Math.cos(player.angle);
  const aimY = Math.sin(player.angle);
  let closest = null;
  let closestProj = Infinity;
  for (const enemy of enemies) {
    const toX = enemy.x - player.x;
    const toY = enemy.y - player.y;
    const proj = toX * aimX + toY * aimY;
    if (proj < 0) continue;
    const closestX = player.x + aimX * proj;
    const closestY = player.y + aimY * proj;
    const perpDist = Math.hypot(enemy.x - closestX, enemy.y - closestY);
    if (perpDist <= hitRadius && proj < closestProj) {
      closestProj = proj;
      closest = enemy;
    }
  }
  return closest;
}

// Capsule check for the shotgun: capsule long axis runs sideways (perpendicular
// to the aim direction), offset forward of the player, matching the
// ShotgunArea/CollisionShape2D layout in player.tscn.
function findShotgunTargets(player, enemies, { offset, halfLength, radius }) {
  const fx = Math.cos(player.angle);
  const fy = Math.sin(player.angle);
  const sx = -fy;
  const sy = fx;
  const hits = [];
  for (const enemy of enemies) {
    const dx = enemy.x - player.x;
    const dy = enemy.y - player.y;
    const forward = dx * fx + dy * fy - offset;
    const side = dx * sx + dy * sy;
    const clampedSide = clamp(side, -halfLength, halfLength);
    const distSq = forward * forward + (side - clampedSide) * (side - clampedSide);
    if (distSq <= radius * radius) hits.push(enemy);
  }
  return hits;
}

// Lightweight stand-in for the GPUParticles2D bursts on player.gd
// (DropTrailParticles, BulletParticles, ShotgunArea/GPUParticles2D).
function createParticleSystem() {
  return { list: [] };
}

function spawnBurst(system, x, y, count, opts) {
  const {
    angle = 0,
    spread = Math.PI,
    speedMin = 60,
    speedMax = 120,
    life = 0.3,
    size = 3,
    color = '#4ca3ff',
  } = opts;
  for (let i = 0; i < count; i++) {
    const a = angle + (Math.random() - 0.5) * spread;
    const speed = speedMin + Math.random() * (speedMax - speedMin);
    system.list.push({
      x,
      y,
      vx: Math.cos(a) * speed,
      vy: Math.sin(a) * speed,
      life,
      maxLife: life,
      size,
      color,
    });
  }
}

function updateParticles(system, dt) {
  for (let i = system.list.length - 1; i >= 0; i--) {
    const p = system.list[i];
    p.life -= dt;
    if (p.life <= 0) {
      system.list.splice(i, 1);
      continue;
    }
    p.x += p.vx * dt;
    p.y += p.vy * dt;
  }
}

function drawParticles(ctx, system) {
  for (const p of system.list) {
    const t = p.life / p.maxLife;
    ctx.globalAlpha = t;
    ctx.fillStyle = p.color;
    ctx.beginPath();
    ctx.arc(p.x, p.y, p.size * t, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.globalAlpha = 1;
}

// Ported from scenes/arena.gd + scenes/UI/hud.gd + scenes/UI/refill_button.gd,
// wired to the DOM/canvas instead of Godot nodes.


const canvas = document.getElementById('game');
const ctx = canvas.getContext('2d');

const scoreEl = document.getElementById('score');
const energyFill = document.getElementById('energy-fill');
const energyValue = document.getElementById('energy-value');
const moveFill = document.getElementById('move-fill');
const gunFill = document.getElementById('gun-fill');
const shotgunFill = document.getElementById('shotgun-fill');
const btnMove = document.getElementById('btn-move');
const btnGun = document.getElementById('btn-gun');
const btnShotgun = document.getElementById('btn-shotgun');
const gameOverEl = document.getElementById('game-over');
const finalScoreEl = document.getElementById('final-score');
const restartBtn = document.getElementById('restart');

const PLAYER_STOPS = [
  [0, 'rgba(120, 190, 255, 1)'],
  [0.55, 'rgba(70, 110, 235, 0.9)'],
  [1, 'rgba(70, 110, 235, 0)'],
];
const ENEMY_STOPS = [
  [0, 'rgba(235, 70, 100, 1)'],
  [0.55, 'rgba(190, 60, 20, 0.9)'],
  [1, 'rgba(190, 60, 20, 0)'],
];
const PICKUP_STOPS = [
  [0, 'rgba(255, 226, 120, 1)'],
  [0.6, 'rgba(255, 160, 40, 0.9)'],
  [1, 'rgba(255, 160, 40, 0)'],
];

const input = { left: false, right: false, up: false, down: false, mouseX: 0, mouseY: 0 };
const state = createGameState();
const particles = createParticleSystem();
let player = createPlayer(0, 0);
let enemies = [];
let pickups = [];
let spawnTimer = 0;
let dropTrailTimer = 0;

function resizeCanvas() {
  const dpr = window.devicePixelRatio || 1;
  canvas.width = Math.floor(window.innerWidth * dpr);
  canvas.height = Math.floor(window.innerHeight * dpr);
  canvas.style.width = `${window.innerWidth}px`;
  canvas.style.height = `${window.innerHeight}px`;
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
}

function worldSize() {
  return { w: canvas.clientWidth, h: canvas.clientHeight };
}

function setKey(code, value) {
  switch (code) {
    case 'KeyA':
    case 'ArrowLeft':
      input.left = value;
      break;
    case 'KeyD':
    case 'ArrowRight':
      input.right = value;
      break;
    case 'KeyW':
    case 'ArrowUp':
      input.up = value;
      break;
    case 'KeyS':
    case 'ArrowDown':
      input.down = value;
      break;
    default:
      break;
  }
}

window.addEventListener('keydown', (e) => setKey(e.code, true));
window.addEventListener('keyup', (e) => setKey(e.code, false));
window.addEventListener('mousemove', (e) => {
  const rect = canvas.getBoundingClientRect();
  input.mouseX = e.clientX - rect.left;
  input.mouseY = e.clientY - rect.top;
});
canvas.addEventListener('mousedown', (e) => {
  if (state.gameOver) return;
  if (e.button === 0) tryPrimary();
  else if (e.button === 2) trySecondary();
});
canvas.addEventListener('contextmenu', (e) => e.preventDefault());
window.addEventListener('resize', resizeCanvas);

function tryPrimary() {
  if (player.primaryCooldown > 0) return;
  if (!spend(state, 'shoot_primary', 1.0)) return;
  player.primaryCooldown = C.PRIMARY_COOLDOWN;
  spawnBurst(particles, player.x, player.y, 5, {
    angle: player.angle,
    spread: 0.12,
    speedMin: 500,
    speedMax: 800,
    life: 0.15,
    size: 3,
    color: '#8fd8ff',
  });
  const target = findPrimaryTarget(player, enemies, C.PRIMARY_HIT_RADIUS);
  if (target) killEnemy(target);
}

function trySecondary() {
  if (player.secondaryCooldown > 0) return;
  if (!spend(state, 'shoot_secondary', 1.0)) return;
  player.secondaryCooldown = C.SECONDARY_COOLDOWN;
  spawnBurst(
    particles,
    player.x + Math.cos(player.angle) * C.SHOTGUN_OFFSET,
    player.y + Math.sin(player.angle) * C.SHOTGUN_OFFSET,
    24,
    {
      angle: player.angle,
      spread: Math.PI / 1.6,
      speedMin: 150,
      speedMax: 350,
      life: 0.4,
      size: 3,
      color: '#e6cfff',
    }
  );
  const targets = findShotgunTargets(player, enemies, {
    offset: C.SHOTGUN_OFFSET,
    halfLength: C.SHOTGUN_HALF_LENGTH,
    radius: C.SHOTGUN_RADIUS,
  });
  for (const enemy of targets) killEnemy(enemy);
}

function killEnemy(enemy) {
  const idx = enemies.indexOf(enemy);
  if (idx === -1) return;
  enemies.splice(idx, 1);
  addScore(state, 1);
  const count = C.PICKUP_MIN_COUNT + Math.floor(Math.random() * (C.PICKUP_MAX_COUNT - C.PICKUP_MIN_COUNT + 1));
  for (let i = 0; i < count; i++) {
    pickups.push(createPickup(enemy.x, enemy.y));
  }
}

function spawnEnemy() {
  const { w, h } = worldSize();
  const m = C.SPAWN_EDGE_MARGIN;
  const edge = Math.floor(Math.random() * 4);
  let x;
  let y;
  switch (edge) {
    case 0:
      x = Math.random() * w;
      y = -m;
      break;
    case 1:
      x = Math.random() * w;
      y = h + m;
      break;
    case 2:
      x = -m;
      y = Math.random() * h;
      break;
    default:
      x = w + m;
      y = Math.random() * h;
      break;
  }
  enemies.push(createEnemy(x, y));
}

function triggerGameOver() {
  if (state.gameOver) return;
  state.gameOver = true;
  finalScoreEl.textContent = `Score: ${state.score}`;
  gameOverEl.hidden = false;
}

function resetGame() {
  resetState(state);
  enemies = [];
  pickups = [];
  particles.list.length = 0;
  spawnTimer = 0;
  dropTrailTimer = 0;
  const { w, h } = worldSize();
  player = createPlayer(w / 2, h / 2);
  gameOverEl.hidden = true;
  updateHud();
}

restartBtn.addEventListener('click', resetGame);

function wireRefillButton(btn, meterName) {
  let intervalId = null;
  const fire = () => {
    allocate(state, meterName);
    updateHud();
  };
  btn.addEventListener('mousedown', () => {
    if (btn.disabled) return;
    fire();
    intervalId = window.setInterval(fire, C.REFILL_REPEAT_INTERVAL * 1000);
  });
  const stop = () => {
    if (intervalId !== null) {
      window.clearInterval(intervalId);
      intervalId = null;
    }
  };
  btn.addEventListener('mouseup', stop);
  btn.addEventListener('mouseleave', stop);
}

wireRefillButton(btnMove, 'move');
wireRefillButton(btnGun, 'shoot_primary');
wireRefillButton(btnShotgun, 'shoot_secondary');

function setBar(el, value, max) {
  el.style.width = `${clamp((value / max) * 100, 0, 100)}%`;
}

function updateHud() {
  setBar(moveFill, state.meters.move, C.MAX_MOVE);
  setBar(gunFill, state.meters.shoot_primary, C.MAX_SHOOT_PRIMARY);
  setBar(shotgunFill, state.meters.shoot_secondary, C.MAX_SHOOT_SECONDARY);
  setBar(energyFill, state.energy, C.ENERGY_BAR_MAX);
  energyValue.textContent = String(Math.floor(state.energy));
  scoreEl.textContent = `Score: ${state.score}`;

  btnMove.disabled = state.energy < C.ALLOC_COST || state.meters.move >= C.MAX_MOVE;
  btnGun.disabled = state.energy < C.ALLOC_COST || state.meters.shoot_primary >= C.MAX_SHOOT_PRIMARY;
  btnShotgun.disabled = state.energy < C.ALLOC_COST || state.meters.shoot_secondary >= C.MAX_SHOOT_SECONDARY;
}

function drawBlob(x, y, radius, stops) {
  const gradient = ctx.createRadialGradient(x, y, 0, x, y, radius);
  for (const [offset, color] of stops) gradient.addColorStop(offset, color);
  ctx.fillStyle = gradient;
  ctx.beginPath();
  ctx.arc(x, y, radius, 0, Math.PI * 2);
  ctx.fill();
}

function render() {
  const { w, h } = worldSize();
  ctx.fillStyle = '#d9c08a';
  ctx.fillRect(0, 0, w, h);

  drawParticles(ctx, particles);
  for (const pickup of pickups) drawBlob(pickup.x, pickup.y, C.PICKUP_RADIUS, PICKUP_STOPS);
  for (const enemy of enemies) drawBlob(enemy.x, enemy.y, C.ENEMY_RADIUS, ENEMY_STOPS);
  drawBlob(player.x, player.y, C.PLAYER_RADIUS, PLAYER_STOPS);

  ctx.strokeStyle = 'rgba(204, 110, 182, 0.65)';
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(player.x, player.y);
  ctx.lineTo(player.x + Math.cos(player.angle) * C.AIM_LINE_LENGTH, player.y + Math.sin(player.angle) * C.AIM_LINE_LENGTH);
  ctx.stroke();
}

function update(dt) {
  const { w, h } = worldSize();
  player.angle = Math.atan2(input.mouseY - player.y, input.mouseX - player.x);

  tickPassiveDrain(state, dt);
  const moving = updatePlayerMovement(player, input, state, dt);
  player.x = clamp(player.x, C.PLAYER_RADIUS, w - C.PLAYER_RADIUS);
  player.y = clamp(player.y, C.PLAYER_RADIUS, h - C.PLAYER_RADIUS);

  if (player.primaryCooldown > 0) player.primaryCooldown = Math.max(0, player.primaryCooldown - dt);
  if (player.secondaryCooldown > 0) player.secondaryCooldown = Math.max(0, player.secondaryCooldown - dt);

  if (moving) {
    dropTrailTimer += dt;
    if (dropTrailTimer >= 0.1) {
      dropTrailTimer = 0;
      spawnBurst(particles, player.x, player.y, 1, {
        angle: player.angle + Math.PI,
        spread: 1.2,
        speedMin: 10,
        speedMax: 40,
        life: 0.6,
        size: 3,
        color: '#5ab0ff',
      });
    }
  }

  for (const enemy of enemies) updateEnemy(enemy, player, dt);
  for (const pickup of pickups) updatePickup(pickup, dt);
  updateParticles(particles, dt);

  for (const enemy of enemies) {
    if (Math.hypot(enemy.x - player.x, enemy.y - player.y) <= C.HURT_CONTACT_DIST) {
      triggerGameOver();
      break;
    }
  }

  for (let i = pickups.length - 1; i >= 0; i--) {
    const pickup = pickups[i];
    if (Math.hypot(pickup.x - player.x, pickup.y - player.y) <= C.PICKUP_COLLECT_DIST) {
      addEnergy(state, C.PICKUP_VALUE);
      pickups.splice(i, 1);
    }
  }

  spawnTimer += dt;
  const interval = Math.max(C.MIN_SPAWN_INTERVAL, C.SPAWN_INTERVAL - state.score * C.SPAWN_DECREASE_PER_KILL);
  if (spawnTimer >= interval) {
    spawnTimer = 0;
    spawnEnemy();
  }

  updateHud();
}

let lastTime = null;
function loop(now) {
  if (lastTime === null) lastTime = now;
  const dt = Math.min((now - lastTime) / 1000, 0.05);
  lastTime = now;

  if (!state.gameOver) update(dt);
  render();
  requestAnimationFrame(loop);
}

resizeCanvas();
player = createPlayer(canvas.clientWidth / 2, canvas.clientHeight / 2);
updateHud();
requestAnimationFrame(loop);

})();
