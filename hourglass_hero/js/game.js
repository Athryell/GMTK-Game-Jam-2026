/*
 * game.js — I/O layer: input, requestAnimationFrame loop, camera, rendering.
 * All physics lives in engine.js (HH); this file only reads world state.
 */
(() => {
  'use strict';

  const { C, createWorld, updateWorld } = window.HH;
  const LEVELS = window.LEVELS;
  const COL = window.CONFIG.colors;

  const canvas = document.getElementById('game');
  canvas.width = C.WORLD_W;
  canvas.height = C.WORLD_H;
  const ctx = canvas.getContext('2d');

  // ----- Game / meta state --------------------------------------------------
  let levelIndex = 0;
  let world = createWorld(LEVELS[levelIndex]);
  let mode = 'play'; // 'play' | 'dead' | 'levelclear' | 'victory'
  let clearTimer = 0;
  let camX = 0; // camera scroll (world px)
  let planeFlash = 0; // short white flash when the plane swaps
  let lastPlane = world.player.plane;

  // Sweat droplets that bead off the hourglass when it's stressed (low sand).
  let drops = [];
  let sweatTimer = 0;

  // How close to death we are, 0 (safe) → 1 (about to empty).
  function danger() {
    if (world.sand > C.SAND_WARN) return 0;
    return Math.min(1, 1 - world.sand / C.SAND_WARN);
  }

  // ----- Input --------------------------------------------------------------
  const input = { left: false, right: false, jumpPressed: false, jumpHeld: false };
  const held = {};

  const LEFT_KEYS = ['ArrowLeft', 'KeyA'];
  const RIGHT_KEYS = ['ArrowRight', 'KeyD'];
  const JUMP_KEYS = ['Space', 'ArrowUp', 'KeyW'];

  window.addEventListener('keydown', (e) => {
    if ([...LEFT_KEYS, ...RIGHT_KEYS, ...JUMP_KEYS].includes(e.code)) e.preventDefault();
    if (e.code === 'KeyR') {
      restart();
      return;
    }
    if (JUMP_KEYS.includes(e.code) && !held[e.code]) input.jumpPressed = true;
    held[e.code] = true;
    syncInput();
  });

  window.addEventListener('keyup', (e) => {
    held[e.code] = false;
    syncInput();
  });

  function syncInput() {
    input.left = LEFT_KEYS.some((k) => held[k]);
    input.right = RIGHT_KEYS.some((k) => held[k]);
    input.jumpHeld = JUMP_KEYS.some((k) => held[k]);
  }

  function restart() {
    if (mode === 'victory') levelIndex = 0;
    loadLevel(levelIndex);
  }

  function loadLevel(i) {
    world = createWorld(LEVELS[i]);
    mode = 'play';
    clearTimer = 0;
    drops = [];
    planeFlash = 0;
    lastPlane = world.player.plane;
    camX = clampCam(world.player.x + world.player.w / 2 - C.WORLD_W / 2);
  }

  function nextLevel() {
    if (levelIndex + 1 < LEVELS.length) {
      levelIndex += 1;
      loadLevel(levelIndex);
    } else {
      mode = 'victory';
    }
  }

  function clampCam(x) {
    return Math.max(0, Math.min(x, world.width - C.WORLD_W));
  }

  // ----- Loop ---------------------------------------------------------------
  let last = null;
  function frame(now) {
    if (last === null) last = now;
    let dt = (now - last) / 1000;
    last = now;
    if (dt > 0.1) dt = 0.1;

    if (mode === 'play') {
      updateWorld(world, input, dt);
      if (world.player.plane !== lastPlane) {
        planeFlash = 0.22;
        lastPlane = world.player.plane;
      }
      if (world.status === 'dead') mode = 'dead';
      else if (world.status === 'win') {
        mode = 'levelclear';
        clearTimer = 0.9;
      }
    } else if (mode === 'levelclear') {
      clearTimer -= dt;
      if (clearTimer <= 0) nextLevel();
    }

    if (planeFlash > 0) planeFlash = Math.max(0, planeFlash - dt);
    updateSweat(dt);
    updateCamera(dt);

    input.jumpPressed = false;
    render();
    requestAnimationFrame(frame);
  }

  // Camera eases toward keeping the player centred, clamped to the level.
  function updateCamera(dt) {
    const target = clampCam(world.player.x + world.player.w / 2 - C.WORLD_W / 2);
    const k = 1 - Math.pow(0.001, dt); // frame-rate independent smoothing
    camX += (target - camX) * k;
  }

  function updateSweat(dt) {
    const d = mode === 'play' ? danger() : 0;
    if (d > 0.25) {
      sweatTimer -= dt;
      if (sweatTimer <= 0) {
        sweatTimer = 0.34 - 0.24 * d;
        const p = world.player;
        const side = Math.random() < 0.5 ? -1 : 1;
        drops.push({
          x: p.x + p.w / 2 + side * (p.w / 2 + 1),
          y: p.y + p.h * 0.28,
          vy: 20 + Math.random() * 30,
          life: 0,
          max: 0.7 + Math.random() * 0.3,
        });
      }
    }
    for (const s of drops) {
      s.vy += 900 * dt;
      s.y += s.vy * dt;
      s.life += dt;
    }
    drops = drops.filter((s) => s.life < s.max && s.y < C.WORLD_H + 20);
  }

  // ----- Rendering ----------------------------------------------------------
  function render() {
    const p = world.player;
    const plane = p.plane;
    const other = plane === 'front' ? 'back' : 'front';

    const bg = plane === 'front' ? COL.frontBg : COL.backBg;
    const grad = ctx.createLinearGradient(0, 0, 0, C.WORLD_H);
    grad.addColorStop(0, bg[0]);
    grad.addColorStop(1, bg[1]);
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, C.WORLD_W, C.WORLD_H);

    // World-space drawing, offset by the camera.
    ctx.save();
    ctx.translate(-Math.round(camX), 0);

    // Ghost layer: what the OTHER plane holds, so you can plan your next jump.
    for (const s of world.solids) if (s.plane === other) drawGhost(s);
    for (const m of world.monsters) if (m.plane === other) drawRect(m, COL.monsterGhost);

    drawLandingMarker();

    // Active layer.
    const solidCol = plane === 'front' ? COL.frontSolid : COL.backSolid;
    for (const s of world.solids) {
      if (s.plane === 'both' || s.plane === plane) drawSolid(s, solidCol);
    }
    drawDoor(world.door);
    for (const m of world.monsters) {
      if (m.plane === 'both' || m.plane === plane) drawMonster(m);
    }

    drawHourglass(p);
    drawSweat();
    ctx.restore();

    // Screen-space overlays.
    drawVignette();
    if (planeFlash > 0) {
      ctx.fillStyle = `rgba(255,255,255,${0.22 * (planeFlash / 0.22)})`;
      ctx.fillRect(0, 0, C.WORLD_W, C.WORLD_H);
    }
    drawHUD();
    drawOverlays();
  }

  // Where would we land if we jumped right now? Highlight that platform in the
  // other plane — the plane a jump would put us in.
  function drawLandingMarker() {
    if (mode !== 'play') return;
    const p = world.player;
    const other = p.plane === 'front' ? 'back' : 'front';
    const cx = p.x + p.w / 2;
    let best = null;
    for (const s of world.solids) {
      if (!(s.plane === 'both' || s.plane === other)) continue;
      if (cx < s.x || cx > s.x + s.w) continue;
      if (s.y < p.y + p.h - 4) continue; // must be below our feet
      if (!best || s.y < best.y) best = s;
    }
    if (!best) return;
    const pulse = 0.35 + 0.25 * Math.sin(world.time * 6);
    ctx.strokeStyle = `rgba(255,255,255,${pulse})`;
    ctx.lineWidth = 2;
    ctx.setLineDash([6, 5]);
    ctx.strokeRect(best.x + 1, best.y + 1, best.w - 2, Math.min(best.h, 14));
    ctx.setLineDash([]);
  }

  function drawRect(r, color) {
    ctx.fillStyle = color;
    ctx.fillRect(r.x, r.y, r.w, r.h);
  }

  function drawGhost(s) {
    drawRect(s, COL.ghost);
    if (s.kind === 'spring' || s.kind === 'flip') {
      ctx.strokeStyle = 'rgba(200,215,245,0.22)';
      ctx.lineWidth = 1.5;
      ctx.strokeRect(s.x + 1, s.y + 1, s.w - 2, s.h - 2);
    }
  }

  function drawSolid(s, color) {
    if (s.kind === 'spring') return drawSpring(s);
    if (s.kind === 'flip') return drawFlipPad(s);
    ctx.fillStyle = color;
    ctx.fillRect(s.x, s.y, s.w, s.h);
    ctx.fillStyle = 'rgba(255,255,255,0.18)';
    ctx.fillRect(s.x, s.y, s.w, 3);
  }

  // Spring: a coil you bounce off without flipping.
  function drawSpring(s) {
    ctx.fillStyle = COL.spring;
    ctx.fillRect(s.x, s.y, s.w, s.h);
    ctx.strokeStyle = 'rgba(10,20,15,0.55)';
    ctx.lineWidth = 2;
    ctx.beginPath();
    const coils = 4;
    for (let i = 0; i <= coils; i++) {
      const y = s.y + 4 + (i * (s.h - 8)) / coils;
      ctx.moveTo(s.x + 5, y);
      ctx.lineTo(s.x + s.w - 5, y + 3);
    }
    ctx.stroke();
    ctx.fillStyle = 'rgba(255,255,255,0.35)';
    ctx.fillRect(s.x, s.y, s.w, 3);
  }

  // Flip-pad: refuels the hourglass on contact, without changing plane.
  function drawFlipPad(s) {
    const flash = world.padFlash > 0 ? world.padFlash / 0.4 : 0;
    ctx.fillStyle = COL.pad;
    ctx.fillRect(s.x, s.y, s.w, s.h);
    if (flash > 0) {
      ctx.fillStyle = `rgba(255,255,255,${0.5 * flash})`;
      ctx.fillRect(s.x, s.y, s.w, s.h);
    }
    // Little hourglass glyphs along the pad.
    ctx.strokeStyle = 'rgba(30,20,10,0.6)';
    ctx.lineWidth = 2;
    const n = Math.max(1, Math.floor(s.w / 40));
    for (let i = 0; i < n; i++) {
      const gx = s.x + (s.w / n) * (i + 0.5);
      const gy = s.y + 9;
      ctx.beginPath();
      ctx.moveTo(gx - 6, gy - 6);
      ctx.lineTo(gx + 6, gy - 6);
      ctx.lineTo(gx, gy);
      ctx.lineTo(gx + 6, gy + 6);
      ctx.lineTo(gx - 6, gy + 6);
      ctx.lineTo(gx, gy);
      ctx.closePath();
      ctx.stroke();
    }
    ctx.fillStyle = 'rgba(255,255,255,0.3)';
    ctx.fillRect(s.x, s.y, s.w, 3);
  }

  function drawMonster(m) {
    ctx.fillStyle = COL.monster;
    ctx.fillRect(m.x, m.y, m.w, m.h);
    ctx.fillStyle = '#1a1020';
    ctx.fillRect(m.x + m.w * 0.22, m.y + m.h * 0.3, 5, 5);
    ctx.fillRect(m.x + m.w * 0.62, m.y + m.h * 0.3, 5, 5);
  }

  function drawDoor(d) {
    ctx.save();
    ctx.shadowColor = COL.doorGlow;
    ctx.shadowBlur = 22;
    ctx.fillStyle = COL.door;
    ctx.fillRect(d.x, d.y, d.w, d.h);
    ctx.restore();
    ctx.fillStyle = 'rgba(0,0,0,0.35)';
    ctx.fillRect(d.x + d.w - 9, d.y + d.h * 0.5 - 3, 5, 6);
  }

  function drawHourglass(p) {
    const ratio = world.sand / world.sandMax;
    const d = mode === 'play' ? danger() : 0;
    const t = world.time;

    const shake = d * 3.2;
    const shakeX = shake * (Math.sin(t * 47) * 0.6 + Math.sin(t * 91) * 0.4);
    const shakeY = shake * 0.5 * (Math.sin(t * 63) * 0.6 + Math.sin(t * 113) * 0.4);

    const cx = p.x + p.w / 2 + shakeX;
    const top = p.y + shakeY;
    const bot = p.y + p.h + shakeY;
    const midY = p.y + p.h / 2 + shakeY;
    const halfW = p.w / 2;

    ctx.save();
    if (d > 0) {
      const pulse = 0.6 + 0.4 * Math.sin(t * 12);
      ctx.shadowColor = `rgba(255, 60, 60, ${0.85 * d * pulse})`;
      ctx.shadowBlur = 8 + 26 * d;
    }

    // The visible 180° flip: starts upside-down (showing the OLD distribution)
    // and rotates upright, tumbling in the direction of travel.
    if (world.justFlipped > 0) {
      const raw = world.justFlipped / C.FLIP_DUR;
      const eased = raw * raw * (3 - 2 * raw);
      const angle = Math.PI * eased * world.flipDir;
      const pop = 1 + 0.18 * Math.sin(Math.PI * (1 - raw));
      ctx.translate(cx, midY);
      ctx.rotate(angle);
      ctx.scale(pop, pop);
      ctx.translate(-cx, -midY);
    }

    const sandCol = world.sand <= C.SAND_WARN ? COL.sandLow : COL.sandFull;

    ctx.fillStyle = sandCol;
    const topFillH = (p.h / 2) * ratio;
    triangle(cx, midY, cx - halfW * ratio, midY - topFillH, cx + halfW * ratio, midY - topFillH);
    const botFillH = (p.h / 2) * (1 - ratio);
    triangle(cx - halfW, bot, cx + halfW, bot, cx, bot - botFillH);

    ctx.strokeStyle = COL.glass;
    ctx.lineWidth = 2.5;
    ctx.lineJoin = 'round';
    ctx.beginPath();
    ctx.moveTo(cx - halfW, top);
    ctx.lineTo(cx + halfW, top);
    ctx.lineTo(cx, midY);
    ctx.lineTo(cx + halfW, bot);
    ctx.lineTo(cx - halfW, bot);
    ctx.lineTo(cx, midY);
    ctx.closePath();
    ctx.stroke();

    ctx.fillStyle = COL.glass;
    ctx.fillRect(cx - halfW - 2, top - 3, p.w + 4, 3);
    ctx.fillRect(cx - halfW - 2, bot, p.w + 4, 3);
    ctx.restore();
  }

  function triangle(x1, y1, x2, y2, x3, y3) {
    ctx.beginPath();
    ctx.moveTo(x1, y1);
    ctx.lineTo(x2, y2);
    ctx.lineTo(x3, y3);
    ctx.closePath();
    ctx.fill();
  }

  function drawSweat() {
    for (const s of drops) {
      const a = 1 - s.life / s.max;
      ctx.fillStyle = `rgba(150, 205, 255, ${0.75 * a})`;
      ctx.beginPath();
      ctx.moveTo(s.x, s.y - 5);
      ctx.quadraticCurveTo(s.x + 3, s.y, s.x, s.y + 3);
      ctx.quadraticCurveTo(s.x - 3, s.y, s.x, s.y - 5);
      ctx.fill();
    }
  }

  // Screen edges darken as the sand runs out.
  function drawVignette() {
    const d = mode === 'play' ? danger() : 0;
    if (d <= 0) return;
    const g = ctx.createRadialGradient(
      C.WORLD_W / 2, C.WORLD_H / 2, C.WORLD_H * 0.32,
      C.WORLD_W / 2, C.WORLD_H / 2, C.WORLD_H * 0.85
    );
    g.addColorStop(0, 'rgba(0,0,0,0)');
    g.addColorStop(1, `rgba(90,0,0,${0.55 * d})`);
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, C.WORLD_W, C.WORLD_H);
  }

  function drawHUD() {
    const barX = 16;
    const barY = 16;
    const barW = 280;
    const barH = 16;
    const ratio = world.sand / world.sandMax;

    ctx.fillStyle = 'rgba(255,255,255,0.12)';
    roundRect(barX, barY, barW, barH, 8);
    ctx.fill();

    // The bar drains toward whichever side the hourglass currently pours to:
    // it fills from the left in the front plane, from the right in the back
    // plane, so a flip visibly reverses its direction.
    const fillW = Math.max(0, barW * ratio);
    const fromLeft = world.player.plane === 'front';
    ctx.fillStyle = world.sand <= C.SAND_WARN ? COL.sandLow : COL.sandFull;
    roundRect(fromLeft ? barX : barX + barW - fillW, barY, fillW, barH, 8);
    ctx.fill();

    // Small arrow showing which way the sand is running.
    ctx.fillStyle = COL.textDim;
    ctx.font = '700 12px system-ui, sans-serif';
    ctx.textBaseline = 'middle';
    ctx.fillText(fromLeft ? '▶' : '◀', barX + barW + 10, barY + barH / 2 + 1);
    ctx.fillStyle = COL.text;
    ctx.font = '600 13px system-ui, sans-serif';
    ctx.fillText('SABLE', barX + barW + 26, barY + barH / 2 + 1);

    ctx.textBaseline = 'alphabetic';
    ctx.fillStyle = COL.text;
    ctx.font = '700 16px system-ui, sans-serif';
    ctx.fillText(`Niveau ${levelIndex + 1}/${LEVELS.length} · ${world.name}`, 16, 58);

    const label = world.player.plane === 'front' ? 'PLAN AVANT' : 'PLAN ARRIÈRE';
    const col = world.player.plane === 'front' ? COL.frontSolid : COL.backSolid;
    ctx.font = '700 14px system-ui, sans-serif';
    ctx.textAlign = 'right';
    ctx.fillStyle = col;
    ctx.fillText(label, C.WORLD_W - 16, 26);
    ctx.textAlign = 'left';
  }

  function drawOverlays() {
    if (mode === 'play') return;
    ctx.fillStyle = COL.overlay;
    ctx.fillRect(0, 0, C.WORLD_W, C.WORLD_H);
    ctx.textAlign = 'center';

    if (mode === 'dead') {
      big(world.sand <= 0 ? "Le sable s'est écoulé…" : 'Tu es mort.', 44);
      small('R pour recommencer le niveau', 96);
    } else if (mode === 'levelclear') {
      big('Niveau terminé !', 44);
    } else if (mode === 'victory') {
      big('Tu as survécu à la nuit ✦', 40);
      small('R pour rejouer', 96);
    }
    ctx.textAlign = 'left';
  }

  function big(text, dy) {
    ctx.font = '800 40px system-ui, sans-serif';
    ctx.fillStyle = COL.text;
    ctx.fillText(text, C.WORLD_W / 2, C.WORLD_H / 2 - 60 + dy);
  }

  function small(text, dy) {
    ctx.font = '500 18px system-ui, sans-serif';
    ctx.fillStyle = COL.textDim;
    ctx.fillText(text, C.WORLD_W / 2, C.WORLD_H / 2 - 60 + dy);
  }

  function roundRect(x, y, w, h, r) {
    r = Math.min(r, w / 2, h / 2);
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r);
    ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r);
    ctx.arcTo(x, y, x + w, y, r);
    ctx.closePath();
  }

  requestAnimationFrame(frame);
})();
