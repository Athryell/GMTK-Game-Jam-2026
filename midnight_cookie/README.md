# Midnight Cookie

Top-down stealth game built around a countdown. Sneak out of bed for the
cookie, but a **bed check** fires every time the timer hits zero — be back
in cover or you're caught, and each round the timer gets shorter.

## Run the game

Open `index.html` in a browser. It loads `dist/game.bundle.js`, so if you
opened it straight from `file://` and see nothing, serve the folder over
HTTP instead (some browsers restrict `file://` module bundles):

```
python3 -m http.server
```

Then open http://localhost:8000/midnight_cookie/index.html.

## Controls

- **WASD / arrow keys** — move (free, continuous)
- **Stop moving** — hold your breath: Mom loses your trail and wanders off,
  but the breath bar drains and running out makes you gasp audibly
- **R** — restart with a fresh house
- **First bed check after** slider sets the round-1 timer length
- Toggle **Reveal explored terrain outside your view** to see the whole
  house dimly instead of only your field of view.

## Development

Edit anything in `src/`, then rebuild the bundle:

```
node scripts/build.mjs
```

## Tests

```
node tests/geometry.test.mjs
node tests/house.test.mjs
node tests/mother.test.mjs
```
