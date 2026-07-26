# Audio

Every sound is an `AudioStreamPlayer` in `sound_bank.tscn`, under `Sfx` or
`Music`. The node's name is the id the game asks for; its stream, `volume_db`,
`pitch_scale` and bus are set on it in the Inspector. `Audio.sfx("jump")` looks
up `Sfx/jump` and plays that player as it stands — the code passes no volume and
no pitch, so mixing is done entirely by ear in the editor.

To add a sound: drop the file in `sfx/` or `music/`, open `sound_bank.tscn`, add
an `AudioStreamPlayer` named after the id, assign the stream and the bus.

A name with no player behind it warns once in the console and plays silence —
which is what lets the call sites be wired before the audio exists, and the audio
to arrive in any order.

Repeated one-shots do not cut each other off: a sound asked for while it is still
ringing is duplicated for that one voice, and the copy frees itself when it ends.
Music is the exception — the bank player is only read for its stream and volume,
because a single owned player is what makes the crossfade possible.

## Names the game already asks for

These calls are live. Each one is silent until the bank has a player for it.

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
(no decode cost on a one-shot). `Audio` turns looping on for the `.ogg` and
`.mp3` it plays as music; a `.wav` track needs its loop set in the import dock.

## Volume

Three buses — Master, Music, SFX — defined in `default_bus_layout.tres`. The
sliders in the menu are generated from `Audio.BUSES`, so adding a fourth bus
gives it a slider with no UI to write. Player volume is saved to
`user://settings.cfg` and survives a restart.
