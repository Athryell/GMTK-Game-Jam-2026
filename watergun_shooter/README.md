# Watergun Shooter

## Run the game

Open `index.html` directly in a browser (double-click it, or
`file://` path) — no server needed.

This is a standalone HTML/JS port of the original Godot project,
kept for reference under `old/` (see `docs/GAME.md` for the design).
The Godot project itself is untouched and still opens normally in
Godot 4.7 — open `old/project.godot`.

## Development

After editing anything in `src/`, rebuild the bundle so
`index.html` picks up the change:

```
node scripts/build.mjs
```

## Tests

```
node tests/game_state.test.mjs
node tests/entities.test.mjs
```
