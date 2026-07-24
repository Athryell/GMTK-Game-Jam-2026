/*
 * config.js — rendering config (colours) used by game.js.
 * Gameplay constants live in engine.js (C); these are purely visual.
 */
const CONFIG = {
  colors: {
    // Per-plane background gradients (top → bottom).
    frontBg: ['#0c1a2b', '#12314a'],
    backBg: ['#1a0f28', '#301a4a'],

    // Solids: bright in the active plane, faint ghost in the other.
    frontSolid: '#48cae4',
    backSolid: '#c77dff',
    ghost: 'rgba(150, 165, 200, 0.16)',

    monster: '#ff5d6c',
    monsterGhost: 'rgba(255, 93, 108, 0.18)',

    spring: '#7ae582', // bounce pad: launches without flipping
    pad: '#ffc971', // flip-pad: refuels the sand without changing plane

    door: '#ffd166',
    doorGlow: 'rgba(255, 209, 102, 0.35)',

    glass: '#e7ecff', // hourglass frame
    sandFull: '#ffb03a',
    sandLow: '#ff3b3b',

    text: '#eaf0fb',
    textDim: '#9aa6c4',
    overlay: 'rgba(6, 8, 16, 0.72)',
  },
};

if (typeof module !== 'undefined' && module.exports) module.exports = { CONFIG };
if (typeof window !== 'undefined') window.CONFIG = CONFIG;
