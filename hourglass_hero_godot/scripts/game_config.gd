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
## Opacity of entities in the opposite plane — the "ghosts".
@export_range(0.0, 1.0, 0.01) var ghost_alpha: float = 0.16
## Camera follow smoothing. 0 = locked to the player.
@export_range(0.0, 20.0, 0.5) var camera_smoothing: float = 6.0
## How long the "level clear" screen stays up, in s.
@export_range(0.1, 3.0, 0.1) var level_clear_delay: float = 0.9

@export_group("Feedback")

## Length of the orange burst when a flip-pad refuels you, in s.
@export_range(0.05, 2.0, 0.05) var pad_flash_duration: float = 0.4
## How fast a spring un-squashes after a bounce. Higher = snappier.
@export_range(0.5, 12.0, 0.5) var spring_recovery_speed: float = 4.0
