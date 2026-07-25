import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';

// Concatenates the ES modules into one classic script: browsers block
// type="module" from file://, but a plain <script src="..."> works fine.
// Sources are listed dependency-first (each file may use names defined by
// earlier ones, since the bundle shares a single IIFE scope).
const SOURCES = [
  'src/config.mjs',
  'src/tiles.mjs',
  'src/geometry.mjs',
  'src/house.mjs',
  'src/player.mjs',
  'src/mother.mjs',
  'src/render.mjs',
  'src/game.mjs',
  'src/main.mjs',
];
const OUTPUT = 'dist/game.bundle.js';

function stripModuleSyntax(source) {
  return (
    source
      // Drop import statements, single- or multi-line.
      .replace(/^\s*import[\s\S]*?from\s+['"][^'"]+['"];?[ \t]*$/gm, '')
      // Drop the `export ` keyword; the declaration stays a top-level binding.
      .replace(/^export\s+(const|function|class)/gm, '$1')
  );
}

const bundle = SOURCES.map((path) => stripModuleSyntax(readFileSync(path, 'utf8'))).join('\n');

mkdirSync('dist', { recursive: true });
writeFileSync(OUTPUT, `(() => {\n'use strict';\n${bundle}\n})();\n`);
console.log(`Built ${OUTPUT} from ${SOURCES.length} modules`);
