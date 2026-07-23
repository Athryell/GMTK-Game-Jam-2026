// Ported from scenes/arena.gd + scenes/UI/hud.gd + scenes/UI/refill_button.gd,
// wired to the DOM/canvas instead of Godot nodes.
import * as C from './constants.mjs';
import { createGameState, resetState, tickPassiveDrain, spend, addEnergy, allocate, addScore } from './game_state.mjs';
import { clamp, createPlayer, createEnemy, createPickup, updatePickup, updateEnemy, updatePlayerMovement, findPrimaryTarget, findShotgunTargets } from './entities.mjs';
import { createParticleSystem, spawnBurst, updateParticles, drawParticles } from './particles.mjs';

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
