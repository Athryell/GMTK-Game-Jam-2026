import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';

// Concatenates the ES modules into one classic script: browsers block
// type="module" from file://, but a plain <script src="..."> works fine.
const SOURCES = ['src/house.mjs', 'src/run.mjs', 'src/game.mjs'];
const OUTPUT = 'dist/game.bundle.js';

function stripModuleSyntax(source) {
  return source
    .split('\n')
    .filter((line) => !line.startsWith('import '))
    .map((line) => line.replace(/^export (const|function)/, '$1'))
    .join('\n');
}

const bundle = SOURCES.map((path) => stripModuleSyntax(readFileSync(path, 'utf8'))).join('\n');

mkdirSync('dist', { recursive: true });
writeFileSync(OUTPUT, `(() => {\n'use strict';\n${bundle}\n})();\n`);
console.log(`Built ${OUTPUT} from ${SOURCES.join(', ')}`);
