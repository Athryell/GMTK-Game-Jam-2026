/*
 * levels.js — level data only, no logic.
 *
 * Every entity has a `plane`: 'front', 'back', or 'both'. The player alternates
 * front/back on every jump, so a 'back' platform can only be landed on right
 * after a jump that lands you in the back plane.
 *
 * Core truths the levels teach:
 *  - A jump refills the sand (if low), flips your plane, and hops — all at once.
 *  - Flipping twice is identity, so you can only REFUEL by NET-changing plane.
 *  - SPRING (kind:'spring', power): launches you without flipping — height/gap
 *    without spending a plane change (but no refuel).
 *  - FLIP-PAD (kind:'flip'): swaps the sand on contact, no jump, no plane change
 *    — the ONLY way to refuel while staying in one plane.
 *
 * `move` (optional) = { axis:'x'|'y', min, max, speed, dir }.
 * `width` (optional) = level width in px for the scrolling camera (default 960).
 */

const LEVELS = [
  // --- 1. Réveil — the sand starts half-full, so you MUST jump to refill it.
  // Each jump also flips front/back (watch the colour). No monsters yet. ------
  {
    name: 'Réveil',
    width: 960,
    spawn: { x: 40, y: 460 },
    door: { x: 902, y: 438, w: 34, h: 64 },
    solids: [
      { x: 0, y: 502, w: 960, h: 38, plane: 'both' },
      { x: 420, y: 402, w: 150, h: 18, plane: 'back' }, // harmless: shows the plane swap
    ],
    monsters: [],
  },

  // --- 2. Le Vide — cross a pit by alternating planes each jump. -------------
  {
    name: 'Le Vide',
    width: 960,
    spawn: { x: 36, y: 460 },
    door: { x: 902, y: 438, w: 34, h: 64 },
    solids: [
      { x: 0, y: 502, w: 300, h: 38, plane: 'both' },
      { x: 700, y: 502, w: 260, h: 38, plane: 'both' },
      { x: 320, y: 470, w: 84, h: 16, plane: 'back' }, // 1st jump lands back
      { x: 452, y: 452, w: 84, h: 16, plane: 'front', move: { axis: 'y', min: 420, max: 470, speed: 55, dir: 1 } },
      { x: 584, y: 470, w: 84, h: 16, plane: 'back' },
    ],
    monsters: [],
  },

  // --- 3. Le Ressort — a pit too wide to jump, in BOTH planes (flipping won't
  // save you). A spring launches you across without spending a flip. ----------
  {
    name: 'Le Ressort',
    width: 1100,
    spawn: { x: 40, y: 460 },
    door: { x: 1040, y: 438, w: 34, h: 64 },
    solids: [
      { x: 0, y: 502, w: 430, h: 38, plane: 'both' },
      { x: 640, y: 502, w: 460, h: 38, plane: 'both' },
      { x: 336, y: 486, w: 84, h: 22, plane: 'both', kind: 'spring', power: 1400 },
    ],
    monsters: [],
  },

  // --- 4. La Fontaine — the floor is FRONT-only for a long stretch (back is a
  // pit), so you can't jump to refuel (a jump would drop you into the back
  // plane's void). FLIP-PADS are your only refuel: swap the sand without
  // leaving the plane. Reach each pad before the sand runs out. --------------
  {
    name: 'La Fontaine',
    width: 1320,
    spawn: { x: 40, y: 460 },
    door: { x: 1260, y: 438, w: 34, h: 64 },
    solids: [
      { x: 0, y: 502, w: 1160, h: 38, plane: 'front' }, // front-only floor
      { x: 1160, y: 502, w: 160, h: 38, plane: 'both' }, // safe both-plane end
      { x: 360, y: 502, w: 120, h: 38, plane: 'front', kind: 'flip' }, // refuel 1
      { x: 760, y: 502, w: 120, h: 38, plane: 'front', kind: 'flip' }, // refuel 2
    ],
    monsters: [],
  },

  // --- 5. Parité — the exit only exists in the BACK plane, so you must ARRIVE
  // there in back. Your plane is set by how many times you've jumped: the
  // natural route lands you on platform A in back, one short of parity. Add a
  // straight-up "parity fix" jump on A to arrive at the ledge in back. -------
  {
    name: 'Parité',
    width: 960,
    spawn: { x: 40, y: 460 },
    door: { x: 858, y: 440, w: 34, h: 62, plane: 'back' },
    solids: [
      { x: 0, y: 502, w: 340, h: 38, plane: 'both' },
      { x: 470, y: 502, w: 150, h: 38, plane: 'both' }, // platform A
      { x: 740, y: 502, w: 210, h: 38, plane: 'back' }, // back-only exit ledge
    ],
    monsters: [],
  },

  // --- 6. Minuit — everything at once: weave the planes across moving ground,
  // past a monster that only bites in the front plane. -----------------------
  {
    name: 'Minuit',
    width: 1400,
    spawn: { x: 28, y: 460 },
    door: { x: 1350, y: 438, w: 34, h: 64 },
    solids: [
      { x: 0, y: 502, w: 220, h: 38, plane: 'both' },
      { x: 1000, y: 502, w: 400, h: 38, plane: 'both' },
      { x: 296, y: 468, w: 92, h: 16, plane: 'back' },
      { x: 430, y: 450, w: 92, h: 16, plane: 'front', move: { axis: 'x', min: 418, max: 512, speed: 80, dir: 1 } },
      { x: 620, y: 468, w: 92, h: 16, plane: 'back' },
      { x: 820, y: 452, w: 92, h: 16, plane: 'front' },
    ],
    monsters: [
      { x: 470, y: 414, w: 30, h: 34, plane: 'front', move: { axis: 'x', min: 470, max: 560, speed: 115, dir: 1 } },
    ],
  },
];

if (typeof module !== 'undefined' && module.exports) module.exports = { LEVELS };
if (typeof window !== 'undefined') window.LEVELS = LEVELS;
