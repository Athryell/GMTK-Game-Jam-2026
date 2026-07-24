import {
  TILE,
  GRID_W,
  GRID_H,
  WORLD_W,
  WORLD_H,
  VIEW_W,
  VIEW_H,
  PLAYER_RADIUS,
  PLAYER_VIEW_RADIUS,
  MOTHER_RADIUS,
  MOTHER_CONE_HALF_ANGLE,
  MOTHER_CONE_RANGE,
  MOTHER_NOISE_INTERVAL_MS,
  MOTHER_NOISE_MAX_RADIUS,
  CHECK_TELEGRAPH_MS,
  BREATH_MAX_MS,
  COLORS,
} from './config.mjs';
import { T } from './tiles.mjs';
import { computeVisibility, computeCone, pointInPolygon } from './geometry.mjs';

export const renderOptions = { revealExplored: false };

function cameraOffset(player) {
  let cx = player.x - VIEW_W / 2;
  let cy = player.y - VIEW_H / 2;
  cx = Math.max(0, Math.min(WORLD_W - VIEW_W, cx));
  cy = Math.max(0, Math.min(WORLD_H - VIEW_H, cy));
  return { cx, cy };
}

function tileColor(kind, lit) {
  if (kind === T.WALL) return lit ? COLORS.wallLit : COLORS.wall;
  if (kind === T.TABLE) return lit ? COLORS.tableLit : COLORS.table;
  return lit ? COLORS.floorLit : COLORS.floor;
}

function drawTiles(ctx, grid, px0, py0, px1, py1, lit) {
  const x0 = Math.max(0, Math.floor(px0 / TILE));
  const y0 = Math.max(0, Math.floor(py0 / TILE));
  const x1 = Math.min(GRID_W, Math.ceil(px1 / TILE));
  const y1 = Math.min(GRID_H, Math.ceil(py1 / TILE));
  for (let ty = y0; ty < y1; ty++) {
    for (let tx = x0; tx < x1; tx++) {
      ctx.fillStyle = tileColor(grid[ty][tx], lit);
      ctx.fillRect(tx * TILE, ty * TILE, TILE, TILE);
    }
  }
}

// Tables occlude, so the clipped floor pass leaves them dark. Redraw the
// ones the player can see (a point just in front of the tile lies inside
// the visibility polygon) so they read as solid hiding spots, not black
// holes. Walls stay black: the lit-floor edge already traces them.
function drawSeenTables(ctx, grid, player, vis) {
  const x0 = Math.max(0, Math.floor((player.x - PLAYER_VIEW_RADIUS) / TILE));
  const y0 = Math.max(0, Math.floor((player.y - PLAYER_VIEW_RADIUS) / TILE));
  const x1 = Math.min(GRID_W, Math.ceil((player.x + PLAYER_VIEW_RADIUS) / TILE));
  const y1 = Math.min(GRID_H, Math.ceil((player.y + PLAYER_VIEW_RADIUS) / TILE));
  for (let ty = y0; ty < y1; ty++) {
    for (let tx = x0; tx < x1; tx++) {
      if (grid[ty][tx] !== T.TABLE) continue;
      let nx = Math.max(tx * TILE, Math.min(player.x, (tx + 1) * TILE));
      let ny = Math.max(ty * TILE, Math.min(player.y, (ty + 1) * TILE));
      const ddx = player.x - nx;
      const ddy = player.y - ny;
      const d = Math.hypot(ddx, ddy);
      if (d > PLAYER_VIEW_RADIUS) continue;
      if (d > 0.001) {
        nx += (ddx / d) * 4;
        ny += (ddy / d) * 4;
      }
      if (!pointInPolygon(nx, ny, vis)) continue;
      ctx.fillStyle = tileColor(T.TABLE, true);
      ctx.fillRect(tx * TILE, ty * TILE, TILE, TILE);
    }
  }
}

function polygonPath(poly) {
  const path = new Path2D();
  if (poly.length) {
    path.moveTo(poly[0].x, poly[0].y);
    for (let i = 1; i < poly.length; i++) path.lineTo(poly[i].x, poly[i].y);
    path.closePath();
  }
  return path;
}

function drawBed(ctx, spawn, lit) {
  const s = TILE * 0.8;
  ctx.fillStyle = lit ? COLORS.bedLit : COLORS.bed;
  ctx.fillRect(spawn.x - s / 2, spawn.y - s / 2, s, s);
  ctx.fillStyle = lit ? '#dce8ff' : '#8fb0dd';
  ctx.fillRect(spawn.x - s / 2, spawn.y - s / 2, s, s * 0.32);
}

function drawCookie(ctx, cookie, t) {
  const pulse = 1 + 0.12 * Math.sin(t / 260);
  ctx.fillStyle = COLORS.cookie;
  ctx.beginPath();
  ctx.arc(cookie.x, cookie.y, 9 * pulse, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#5a3210';
  for (const [ox, oy] of [[-3, -2], [3, -1], [0, 3], [-2, 3]]) {
    ctx.beginPath();
    ctx.arc(cookie.x + ox, cookie.y + oy, 1.3, 0, Math.PI * 2);
    ctx.fill();
  }
}

function drawPlayer(ctx, player) {
  ctx.fillStyle = COLORS.player;
  ctx.beginPath();
  ctx.arc(player.x, player.y, PLAYER_RADIUS, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#8a6d1f';
  ctx.beginPath();
  ctx.arc(
    player.x + Math.cos(player.facing) * PLAYER_RADIUS * 0.6,
    player.y + Math.sin(player.facing) * PLAYER_RADIUS * 0.6,
    3.5,
    0,
    Math.PI * 2,
  );
  ctx.fill();
}

function drawMother(ctx, mother, segments) {
  const cone = computeCone(
    mother.x,
    mother.y,
    mother.facing,
    MOTHER_CONE_HALF_ANGLE,
    MOTHER_CONE_RANGE,
    segments,
  );
  ctx.fillStyle = mother.mode === 'hunt' ? COLORS.coneHunt : COLORS.cone;
  ctx.fill(polygonPath(cone));

  ctx.fillStyle = COLORS.mother;
  ctx.beginPath();
  ctx.arc(mother.x, mother.y, MOTHER_RADIUS, 0, Math.PI * 2);
  ctx.fill();
}

// Noise rings are drawn WITHOUT the visibility clip: the player senses
// Mom's position through walls by the sound she makes.
function drawNoise(ctx, mother) {
  for (const p of mother.pings) {
    const frac = p.age / MOTHER_NOISE_INTERVAL_MS;
    const r = 12 + frac * MOTHER_NOISE_MAX_RADIUS;
    ctx.strokeStyle = `rgba(255, 220, 120, ${0.8 * (1 - frac)})`;
    ctx.lineWidth = 2.5;
    ctx.beginPath();
    ctx.arc(p.x, p.y, r, 0, Math.PI * 2);
    ctx.stroke();
  }
}

// When Mom is off-screen, clamp a pulsing arrow to the screen edge that
// points toward her, so the player always has a rough sense of her position.
function drawOffscreenMother(ctx, mother, cam, timeMs) {
  const mx = mother.x - cam.cx;
  const my = mother.y - cam.cy;
  if (mx >= 0 && mx <= VIEW_W && my >= 0 && my <= VIEW_H) return;

  const cx = VIEW_W / 2;
  const cy = VIEW_H / 2;
  const margin = 30;
  const ang = Math.atan2(my - cy, mx - cx);
  const dx = Math.cos(ang);
  const dy = Math.sin(ang);
  const scale = Math.min(
    (VIEW_W / 2 - margin) / Math.abs(dx || 1e-6),
    (VIEW_H / 2 - margin) / Math.abs(dy || 1e-6),
  );
  const px = cx + dx * scale;
  const py = cy + dy * scale;

  const pulse = 0.55 + 0.35 * Math.sin(timeMs / 180);
  ctx.save();
  ctx.translate(px, py);
  ctx.rotate(ang);
  ctx.globalAlpha = pulse;
  ctx.fillStyle = COLORS.mother;
  ctx.beginPath();
  ctx.arc(-16, 0, 11, 0, Math.PI * 2);
  ctx.fill();
  ctx.beginPath();
  ctx.moveTo(14, 0);
  ctx.lineTo(-4, -9);
  ctx.lineTo(-4, 9);
  ctx.closePath();
  ctx.fill();
  ctx.globalAlpha = 1;
  ctx.restore();
}

export function drawGame(ctx, state, timeMs) {
  const { house, segments, viewSegments, player, mother } = state;
  const cam = cameraOffset(player);

  ctx.clearRect(0, 0, VIEW_W, VIEW_H);
  ctx.fillStyle = '#07050c';
  ctx.fillRect(0, 0, VIEW_W, VIEW_H);

  ctx.save();
  ctx.translate(-cam.cx, -cam.cy);

  if (renderOptions.revealExplored) {
    ctx.globalAlpha = 0.28;
    drawTiles(ctx, house.grid, cam.cx, cam.cy, cam.cx + VIEW_W, cam.cy + VIEW_H, false);
    ctx.globalAlpha = 1;
    drawBed(ctx, house.spawn, false);
  }

  // Bright pass, clipped to the analytic visibility polygon. Only tiles
  // within view radius can show, so the loop stays tight around the player.
  const vis = computeVisibility(player.x, player.y, PLAYER_VIEW_RADIUS, viewSegments);
  const visPath = polygonPath(vis);
  ctx.save();
  ctx.clip(visPath);
  drawTiles(
    ctx,
    house.grid,
    player.x - PLAYER_VIEW_RADIUS,
    player.y - PLAYER_VIEW_RADIUS,
    player.x + PLAYER_VIEW_RADIUS,
    player.y + PLAYER_VIEW_RADIUS,
    true,
  );
  drawBed(ctx, house.spawn, true);
  if (!player.hasCookie) drawCookie(ctx, house.cookie, timeMs);
  ctx.restore();

  drawSeenTables(ctx, house.grid, player, vis);

  // Mother + cone, only the parts inside the player's sight.
  ctx.save();
  ctx.clip(visPath);
  drawMother(ctx, mother, segments);
  ctx.restore();
  drawNoise(ctx, mother);

  drawPlayer(ctx, player);

  ctx.restore();

  drawOffscreenMother(ctx, mother, cam, timeMs);
  drawHud(ctx, state, timeMs);
}

function drawHud(ctx, state, timeMs) {
  ctx.fillStyle = 'rgba(0,0,0,0.55)';
  ctx.fillRect(0, 0, VIEW_W, 46);
  ctx.textBaseline = 'middle';

  ctx.font = '600 18px system-ui, sans-serif';
  ctx.textAlign = 'left';
  ctx.fillStyle = state.player.hasCookie ? COLORS.cookie : '#8a8397';
  ctx.fillText(state.player.hasCookie ? '🍪 Cookie grabbed' : '🍪 Find the cookie', 16, 23);

  ctx.textAlign = 'right';
  ctx.fillStyle = '#b8b0c8';
  ctx.fillText(`Round ${state.round}`, VIEW_W - 16, 23);

  // Bed-check countdown, centered and escalating.
  const telegraph = state.checkMs <= CHECK_TELEGRAPH_MS;
  const secs = Math.max(0, Math.ceil(state.checkMs / 1000));
  ctx.textAlign = 'center';
  ctx.fillStyle = telegraph ? '#ff7a7a' : '#e6e0f0';
  ctx.font = '700 24px system-ui, sans-serif';
  ctx.fillText(`Bed check in ${secs}s`, VIEW_W / 2, 23);

  if (telegraph) {
    const pulse = 0.6 + 0.4 * Math.sin(timeMs / 120);
    ctx.globalAlpha = pulse;
    ctx.fillStyle = '#ff7a7a';
    ctx.font = '800 30px system-ui, sans-serif';
    ctx.fillText('GET TO COVER', VIEW_W / 2, 78);
    ctx.globalAlpha = 1;
  }

  // Breath meter: a bar that drains while holding your breath.
  const bw = 220;
  const bh = 10;
  const bx = VIEW_W / 2 - bw / 2;
  const by = VIEW_H - 40;
  const frac = Math.max(0, Math.min(1, state.breathMs / BREATH_MAX_MS));
  const empty = state.breathMs <= 0;
  ctx.fillStyle = 'rgba(255,255,255,0.12)';
  ctx.fillRect(bx, by, bw, bh);
  ctx.fillStyle = empty ? '#ff7a7a' : frac < 0.3 ? '#e0a24a' : '#9be08a';
  ctx.fillRect(bx, by, bw * frac, bh);

  ctx.font = '600 13px system-ui, sans-serif';
  ctx.textAlign = 'center';
  if (empty) {
    ctx.fillStyle = '#ff7a7a';
    ctx.fillText('Out of breath — she can hear you!', VIEW_W / 2, VIEW_H - 16);
  } else if (state.audible) {
    ctx.fillStyle = '#e0a24a';
    ctx.fillText('Moving — she can hear you', VIEW_W / 2, VIEW_H - 16);
  } else {
    ctx.fillStyle = '#8a8397';
    ctx.fillText('Holding your breath', VIEW_W / 2, VIEW_H - 16);
  }

  // "Safe!" pulse after a passed check.
  if (state.flashMs > 0 && state.phase === 'playing') {
    ctx.globalAlpha = Math.min(1, state.flashMs / 900);
    ctx.fillStyle = '#9be08a';
    ctx.font = '800 34px system-ui, sans-serif';
    ctx.fillText('Safe!', VIEW_W / 2, VIEW_H / 2 - 60);
    ctx.globalAlpha = 1;
  }

  if (state.phase === 'won' || state.phase === 'lost') {
    ctx.fillStyle = 'rgba(0,0,0,0.72)';
    ctx.fillRect(0, 0, VIEW_W, VIEW_H);
    ctx.fillStyle = state.phase === 'won' ? '#9be08a' : '#ff7a7a';
    ctx.font = '700 40px system-ui, sans-serif';
    ctx.fillText(
      state.phase === 'won' ? 'Mission complete 🍪' : 'Caught! 😱',
      VIEW_W / 2,
      VIEW_H / 2 - 24,
    );
    ctx.fillStyle = '#e6e0f0';
    ctx.font = '500 20px system-ui, sans-serif';
    ctx.fillText(loseSubtitle(state), VIEW_W / 2, VIEW_H / 2 + 14);
    ctx.fillStyle = '#b8b0c8';
    ctx.font = '500 16px system-ui, sans-serif';
    ctx.fillText('Press R to play again', VIEW_W / 2, VIEW_H / 2 + 48);
  }
}

function loseSubtitle(state) {
  if (state.phase === 'won') return 'Back in bed, no one the wiser.';
  return state.lostReason === 'check'
    ? 'Mom checked your bed and you were gone.'
    : 'Mom spotted you out of bed.';
}
