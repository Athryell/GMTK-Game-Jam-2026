# Audio

Drop a file in, and it plays. There is no list to register it in.

`Audio.sfx("jump")` looks for `audio/sfx/jump.ogg`, then `.wav`, then `.mp3`, and
plays the first one it finds. `Audio.play_music("level")` does the same in
`audio/music/`. A name with no file behind it warns once in the console and
plays silence — which is what lets the call sites be wired before the audio
exists, and the audio to arrive in any order.

## Names the game already asks for

These calls are live. Each one is silent until you add the matching file.

### `sfx/`

| Name | Fires when |
|---|---|
| `jump` | Any jump — the flip, the plane swap, the refuel, all at once |
| `land` | Touching down, loud in proportion to the fall |
| `spring` | Launched by a spring: height, no flip |
| `flip_pad` | A flip-pad: refuel without changing plane |
| `death` | The glass comes apart |
| `win` | The door |

### `music/`

| Name | Plays on |
|---|---|
| `menu` | Title screen and level select |
| `level` | Any level. One track for the whole run — it is not restarted between levels |

## Formats

`.ogg` for music (it streams, and loops seamlessly). `.wav` for short effects
(no decode cost on a one-shot). Looping is turned on for music by `Audio`
itself, so there is no per-file import setting to remember.

## Volume

Three buses — Master, Music, SFX — defined in `default_bus_layout.tres`. The
sliders in the menu are generated from `Audio.BUSES`, so adding a fourth bus
gives it a slider with no UI to write. Player volume is saved to
`user://settings.cfg` and survives a restart.
