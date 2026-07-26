## Every gameplay variable, in one place. Edit via `resources/game_config.tres`
## or in game with F1: the tuning panel generates one slider per `@export_range`
## below, grouped by `@export_group`.
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
## Sand at level start, in ms. Half of `sand_max` stabilises the flip loop.
@export_range(0.0, 20000.0, 100.0) var sand_start: float = 3000.0
## Threshold below which the sand turns red, in ms.
@export_range(0.0, 10000.0, 100.0) var sand_warn: float = 2000.0
## How fast the sand runs out, in ms per second. 1000 = a real clock.
@export_range(0.0, 5000.0, 10.0) var sand_drain_rate: float = 1000.0
## How fast the sand runs the WRONG way inside an inversion zone, in ms per
## second. Matching `sand_drain_rate` keeps both directions equally deadly.
@export_range(0.0, 5000.0, 10.0) var sand_reverse_rate: float = 1000.0
## How long the sand takes to stop and start running the other way, in s. Matches
## `flip_duration` so a zone reads at the pace the player already knows.
@export_range(0.05, 2.0, 0.05) var flow_turn_duration: float = 0.5
## Floor added to every flip. 0 = pure hourglass.
@export_range(0.0, 6000.0, 100.0) var sand_flip_base: float = 0.0
## Length of the flip animation, in s.
@export_range(0.05, 2.0, 0.05) var flip_duration: float = 0.5

@export_group("World")

## Falling this far below the level bottom kills, in px.
@export_range(0.0, 600.0, 10.0) var fall_death_margin: float = 60.0
## Default spring impulse, in px/s (each spring can override it).
@export_range(0.0, 3000.0, 10.0) var spring_power: float = 1400.0
## Opacity of entities in the opposite plane (the "ghosts"). `world_light`
## multiplies it, so low values vanish.
@export_range(0.0, 1.0, 0.01) var ghost_alpha: float = 0.22
## How far the plane a jump would land in is lifted out of `ghost_alpha` towards
## solid. 0 hides which way you are going; 1 makes it look walkable.
@export_range(0.0, 1.0, 0.01) var ghost_next_lift: float = 0.45
## How far a solid's dashed "the next jump brings this in" marker sits outside
## its silhouette, in px, past the outline itself. 0 puts it against the ink.
@export_range(0.0, 12.0, 1.0) var next_outline_gap: float = 2.0
## How long the "level clear" screen stays up, in s.
@export_range(0.1, 3.0, 0.1) var level_clear_delay: float = 0.9
## How long the curtain takes to close on the exit, and to open on the level
## that follows, in s. Held under `level_clear_delay`, which is the cover the
## swap happens behind.
@export_range(0.0, 2.0, 0.05) var level_fade: float = 0.45
## How long the death screen stays up before the level restarts itself, in s.
##
## Doubles as the lifetime of everything the death throws — see [method
## Burst.shatter] — so it is what you get to WATCH the glass come apart in, not
## just a pause. At 0.6 the sand was on the floor before the eye had found it, and
## the sand now drifts down at a seventh of the glass's weight, so it needs the
## room to get there.
@export_range(0.1, 3.0, 0.1) var death_delay: float = 1.6

@export_group("Camera")

## How close the camera sits. 1.0 shows the 960×540 design view; above that it
## moves in and the level scrolls. `CameraRig` must divide the viewport by this
## zoom rather than trust `get_viewport_rect()`.
##
## Not free to taste: every texture is drawn one art px to one world px, so at
## 1.0 the 960×540 canvas scales to a 1920×1080 window by exactly 2 and every art
## pixel lands on a 2×2 block. Any other zoom makes that fractional, and
## `TEXTURE_FILTER_NEAREST` shows it rather than blurring over it.
@export_range(0.6, 2.5, 0.05) var camera_zoom: float = 1.0
## Camera follow smoothing. 0 = locked to the player.
@export_range(0.0, 20.0, 0.5) var camera_smoothing: float = 7.0
## How far the view leads the player in the direction they are running, in px.
@export_range(0.0, 300.0, 5.0) var camera_lead: float = 78.0
## How fast the lead swings across when you turn around.
@export_range(0.5, 12.0, 0.5) var camera_lead_speed: float = 2.6
## How far the view may drift from the last ground the player stood on, in px.
## Below the jump's 131 px rise, so a jump nudges the frame instead of chasing it.
@export_range(0.0, 400.0, 5.0) var camera_vertical_slack: float = 84.0
## How much of the frame's edge stays clear of the player, in px. `CameraRig`
## hard-clamps to this whatever the smoothing is doing.
@export_range(0.0, 200.0, 4.0) var camera_edge_margin: float = 56.0
## Shake amplitude at full trauma, in px.
@export_range(0.0, 60.0, 1.0) var camera_shake_strength: float = 16.0
## Seconds for a full-strength shake to die away.
@export_range(0.05, 3.0, 0.05) var camera_shake_decay: float = 0.55
## Shake amplitude with an all but empty glass, in px. Held for as long as the
## danger lasts, so it belongs well under `camera_shake_strength`.
@export_range(0.0, 20.0, 0.5) var camera_danger_shake: float = 3.5

@export_group("Light")

## How dark the world sits before the lights are added. 1.0 disables lighting.
@export_range(0.1, 1.0, 0.01) var world_light: float = 0.58
## Reach of the light the player carries, in px.
@export_range(40.0, 700.0, 10.0) var player_light_radius: float = 270.0
## Brightness of the player's light with a full glass; scales down with the sand.
## Kept well under 1 now the glass is painted rather than drawn: a bright lamp
## sitting inside the art washes the wood and the highlights out of it.
@export_range(0.0, 4.0, 0.05) var player_light_energy: float = 0.6
## Brightness of the lights on doors, springs, pads and hazards.
@export_range(0.0, 4.0, 0.05) var entity_light_energy: float = 1.1
## How much of the lamp a solid cuts out. 1 is a true shadow: behind a wall the
## light simply is not there, and only `world_light` is left.
@export_range(0.0, 1.0, 0.01) var shadow_strength: float = 1.0

@export_group("Feedback")

## Length of the orange burst when a flip-pad refuels you, in s.
@export_range(0.05, 2.0, 0.05) var pad_flash_duration: float = 0.4
## How fast a spring un-squashes after a bounce. Higher = snappier.
@export_range(0.5, 12.0, 0.5) var spring_recovery_speed: float = 4.0
## How far the red danger border reaches in from the screen edge, in px.
@export_range(0.0, 200.0, 5.0) var danger_edge_depth: float = 72.0
## The border's alpha at its brightest.
@export_range(0.0, 1.0, 0.05) var danger_edge_alpha: float = 0.7
## Beats per second the border breathes at, before the danger quickens it.
@export_range(0.0, 6.0, 0.1) var danger_edge_pulse: float = 1.6
