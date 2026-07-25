## Every gameplay variable, in one place.
##
## Two ways to edit it:
##   1. In the Inspector, by opening `resources/game_config.tres`.
##   2. In game, with F1: the tuning panel generates one slider per
##      `@export_range` below.
##
## ADDING A VARIABLE = adding one `@export_range(...)` line here. The slider
## shows up on its own, no UI code to touch. The `@export_group` becomes the
## section heading in the panel.
class_name GameConfig
extends Resource

@export_group("Movement")

## Vertical acceleration, in px/s².
@export_range(0.0, 6000.0, 10.0) var gravity: float = 2200.0
## Horizontal run speed, in px/s.
@export_range(0.0, 800.0, 5.0) var move_speed: float = 260.0
## Jump impulse, in px/s (positive value = upwards).
@export_range(0.0, 2000.0, 5.0) var jump_velocity: float = 760.0
## Releasing jump while rising caps the climb to this — a short hop.
@export_range(0.0, 1000.0, 5.0) var jump_cut_velocity: float = 280.0
## Grace window to still jump just after leaving a ledge, in s.
@export_range(0.0, 0.5, 0.01) var coyote_time: float = 0.09
## A jump pressed just before landing still fires, in s.
@export_range(0.0, 0.5, 0.01) var jump_buffer: float = 0.12
## Terminal fall speed, in px/s.
@export_range(0.0, 4000.0, 10.0) var max_fall_speed: float = 1800.0

@export_group("Hourglass")

## Total sand held by one bulb, in ms.
@export_range(500.0, 20000.0, 100.0) var sand_max: float = 6000.0
## Sand at level start, in ms. Half of `sand_max` stabilises the loop: any
## flip made below half lands you back above half.
@export_range(0.0, 20000.0, 100.0) var sand_start: float = 3000.0
## Threshold below which the sand turns red, in ms.
@export_range(0.0, 10000.0, 100.0) var sand_warn: float = 2000.0
## How fast the sand runs out, in ms per second. At 1000 the gauge is a real
## clock: `sand_max` ms of sand lasts exactly that many milliseconds. Raise it
## and the whole game gets more frantic without touching a single level.
@export_range(0.0, 5000.0, 10.0) var sand_drain_rate: float = 1000.0
## Floor added to every flip. 0 = pure hourglass.
@export_range(0.0, 6000.0, 100.0) var sand_flip_base: float = 0.0
## Length of the flip animation, in s.
@export_range(0.05, 2.0, 0.05) var flip_duration: float = 0.5

@export_group("World")

## Falling this far below the level bottom kills, in px.
@export_range(0.0, 600.0, 10.0) var fall_death_margin: float = 60.0
## Default spring impulse, in px/s (each spring can override it).
@export_range(0.0, 3000.0, 10.0) var spring_power: float = 1400.0
## Opacity of entities in the opposite plane — the "ghosts". Raised when the
## world was darkened for the lights: 0.16 read fine on a flat backdrop and
## vanished entirely once `world_light` started multiplying it.
@export_range(0.0, 1.0, 0.01) var ghost_alpha: float = 0.26
## How long the "level clear" screen stays up, in s.
@export_range(0.1, 3.0, 0.1) var level_clear_delay: float = 0.9

@export_group("Camera")

## How close the camera sits. 1.0 shows the 960×540 design view; above that it
## moves in and the level scrolls.
##
## This is the single biggest visual lever in the game and it is not really a
## look setting. Levels are 540 px tall and the camera used to show exactly 540,
## so two thirds of every screen was empty sky. Moving in fills the frame with
## the level — and it is why `CameraRig` divides the viewport by the zoom
## everywhere instead of trusting `get_viewport_rect()`.
##
## Above 1.0 because most levels are 540 px tall with every platform in the
## bottom 240. The camera clamps to the level, so the slack all ends up as empty
## sky above the player; the only way to spend it is to move in. 1.55 keeps
## enough of the level ahead to read a gap before you commit to it.
@export_range(0.6, 2.5, 0.05) var camera_zoom: float = 1.55
## Camera follow smoothing. 0 = locked to the player.
@export_range(0.0, 20.0, 0.5) var camera_smoothing: float = 7.0
## How far the view leads the player in the direction they are running, in px.
@export_range(0.0, 300.0, 5.0) var camera_lead: float = 78.0
## How fast the lead swings across when you turn around.
@export_range(0.5, 12.0, 0.5) var camera_lead_speed: float = 2.6
## How far the view may drift from the last ground the player stood on, in px.
## Below the jump's 125 px rise, so a jump nudges the frame instead of chasing it.
@export_range(0.0, 400.0, 5.0) var camera_vertical_slack: float = 84.0
## Shake amplitude at full trauma, in px.
@export_range(0.0, 60.0, 1.0) var camera_shake_strength: float = 16.0
## Seconds for a full-strength shake to die away.
@export_range(0.05, 3.0, 0.05) var camera_shake_decay: float = 0.55

@export_group("Light")

## How dark the world sits before the lights are added. 1.0 disables the whole
## lighting pass — handy for checking that a level still reads unlit.
@export_range(0.1, 1.0, 0.01) var world_light: float = 0.58
## Reach of the light the player carries, in px.
@export_range(40.0, 700.0, 10.0) var player_light_radius: float = 270.0
## Brightness of the player's light with a full glass. It scales down with the
## sand, so the room closes in as you run out of time — the clock is readable
## without looking at the gauge.
@export_range(0.0, 4.0, 0.05) var player_light_energy: float = 1.35
## Brightness of the lights on doors, springs, pads and hazards.
@export_range(0.0, 4.0, 0.05) var entity_light_energy: float = 1.1

@export_group("Feedback")

## Length of the orange burst when a flip-pad refuels you, in s.
@export_range(0.05, 2.0, 0.05) var pad_flash_duration: float = 0.4
## How fast a spring un-squashes after a bounce. Higher = snappier.
@export_range(0.5, 12.0, 0.5) var spring_recovery_speed: float = 4.0
