// Lightweight stand-in for the GPUParticles2D bursts on player.gd
// (DropTrailParticles, BulletParticles, ShotgunArea/GPUParticles2D).
export function createParticleSystem() {
  return { list: [] };
}

export function spawnBurst(system, x, y, count, opts) {
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

export function updateParticles(system, dt) {
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

export function drawParticles(ctx, system) {
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
