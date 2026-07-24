import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';

// Concatenates the ES modules into one classic script: browsers block
// type="module" from file://, but a plain <script src="..."> works fine.
const SOURCES = [
  'src/constants.mjs',
  'src/game_state.mjs',
  'src/entities.mjs',
  'src/particles.mjs',
  'src/game.mjs',
];
const OUTPUT = 'dist/game.bundle.js';

const EXPORT_NAME_RE = /^export (?:const|function)\s+([A-Za-z0-9_]+)/;
const NAMESPACE_IMPORT_RE = /^import \* as (\w+) from '\.\/(.+)';$/;

function exportedNames(source) {
  return source
    .split('\n')
    .map((line) => line.match(EXPORT_NAME_RE))
    .filter(Boolean)
    .map((match) => match[1]);
}

const exportsByFile = Object.fromEntries(SOURCES.map((path) => [path, exportedNames(readFileSync(path, 'utf8'))]));

function findSourceByBasename(basename) {
  const found = SOURCES.find((path) => path.endsWith(`/${basename}`));
  if (!found) throw new Error(`Cannot resolve import for ${basename}`);
  return found;
}

// `import * as X from './foo.mjs'` has no single name to delete like a named
// import does, so expand it into an object aliasing foo.mjs's own top-level
// bindings (which are already in scope by concatenation order) instead.
// Multiple files may import the same namespace alias, so only the first
// occurrence actually declares it; later ones collapse to nothing.
const emittedNamespaces = new Set();
function expandNamespaceImport(line) {
  const match = line.match(NAMESPACE_IMPORT_RE);
  if (!match) return line;
  const [, alias, basename] = match;
  if (emittedNamespaces.has(alias)) return '';
  emittedNamespaces.add(alias);
  const names = exportsByFile[findSourceByBasename(basename)];
  return `const ${alias} = { ${names.join(', ')} };`;
}

function stripModuleSyntax(source) {
  return source
    .split('\n')
    .map(expandNamespaceImport)
    .filter((line) => !line.startsWith('import '))
    .map((line) => line.replace(/^export (const|function)/, '$1'))
    .join('\n');
}

const bundle = SOURCES.map((path) => stripModuleSyntax(readFileSync(path, 'utf8'))).join('\n');

mkdirSync('dist', { recursive: true });
writeFileSync(OUTPUT, `(() => {\n'use strict';\n${bundle}\n})();\n`);
console.log(`Built ${OUTPUT} from ${SOURCES.join(', ')}`);
