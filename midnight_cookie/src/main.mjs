import { VIEW_W, VIEW_H } from './config.mjs';
import { createGame, updateGame, gameOptions } from './game.mjs';
import { drawGame, renderOptions } from './render.mjs';

const canvas = document.getElementById('game');
canvas.width = VIEW_W;
canvas.height = VIEW_H;
const ctx = canvas.getContext('2d');

const revealToggle = document.getElementById('reveal-toggle');
if (revealToggle) {
  renderOptions.revealExplored = revealToggle.checked;
  revealToggle.addEventListener('change', () => {
    renderOptions.revealExplored = revealToggle.checked;
  });
}

const input = { up: false, down: false, left: false, right: false };

const KEY_MAP = {
  ArrowUp: 'up',
  ArrowDown: 'down',
  ArrowLeft: 'left',
  ArrowRight: 'right',
  KeyW: 'up',
  KeyS: 'down',
  KeyA: 'left',
  KeyD: 'right',
};

// Slider: length of the first bed-check window. Set before the first game
// so it honors the slider's restored value on reload; live label while
// dragging, restart with the new time on release.
const countdownSlider = document.getElementById('countdown-slider');
const countdownValue = document.getElementById('countdown-value');
if (countdownSlider) {
  const syncLabel = () => {
    if (countdownValue) countdownValue.textContent = `${countdownSlider.value}s`;
  };
  gameOptions.startMs = Number(countdownSlider.value) * 1000;
  syncLabel();
  countdownSlider.addEventListener('input', syncLabel);
  countdownSlider.addEventListener('change', () => {
    gameOptions.startMs = Number(countdownSlider.value) * 1000;
    game = createGame();
  });
}

let game = createGame();

window.addEventListener('keydown', (e) => {
  if (e.code === 'KeyR') {
    game = createGame();
    return;
  }
  const dir = KEY_MAP[e.code];
  if (dir) {
    input[dir] = true;
    e.preventDefault();
  }
});

window.addEventListener('keyup', (e) => {
  const dir = KEY_MAP[e.code];
  if (dir) {
    input[dir] = false;
    e.preventDefault();
  }
});

let last = performance.now();

function frame(now) {
  // Clamp dt so tab-switch pauses don't teleport entities through walls.
  const dt = Math.min(0.05, (now - last) / 1000);
  last = now;

  updateGame(game, input, dt);
  drawGame(ctx, game, now);

  requestAnimationFrame(frame);
}

requestAnimationFrame(frame);
