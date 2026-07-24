# Midnight Cookie

## Concept
It's night. You're a kid who sneaks out of bed to grab a cookie from
another room and get back before Mom notices. The jam theme is **Count
Down**: a bed-check timer is the heart of the game. When it hits zero Mom
checks on you — be in cover or you're caught — and every survived check
makes the next window shorter. Meanwhile she roams the house, so you also
have to avoid her vision cone.

## Objectives
1. Find and grab the cookie (in a room far from the bedroom).
2. Survive each bed check along the way.
3. Return to bed with the cookie.

You win the moment you're back at the bed holding the cookie.

## Mechanics

### Movement & view
- Fully continuous top-down movement, collided against walls.
- Your field of view is an analytic (vector) visibility polygon: you see
  a disc around you, cut by walls and furniture. Everything outside your
  line of sight is dark. A toggle can reveal the rest of the house dimly.

### The house
- Randomly generated each run on a tile grid (rooms + corridors), so the
  layout, cookie location, and hiding spots change every time. Tiles are
  only used to build the level; movement and vision are continuous.
- **Tables** are walkable hiding spots. They block line of sight — so they
  cast shadows — and hide you when you stand on one. The tile you stand on
  is excluded from your own occluders, so hiding never blacks out your view.

### The bed check (the countdown)
- A window counts down on screen. During it you roam freely toward the
  cookie. The last 3 seconds flash a red **GET TO COVER** warning.
- At zero Mom does a check: you survive only in **cover** — in bed, under a
  table, or with a wall between you and her. Exposed and it's game over.
- Each survived check shortens the next window (down to a floor), so you
  can venture a little less far each round.

### Mom
- She is home from the start and wanders the house at random, pathfinding
  room to room (slower than you, so she is escapable).
- She sees through a **vision cone** blocked by walls and tables. Caught in
  it with a clear line of sight and not hiding = game over, even between
  checks.
- **Hearing:** while you move within earshot she homes in on you; hold your
  breath (stop, or hide) and she loses the trail and wanders off again.
- **Breath:** a bar drains while you hold your breath and refills only by
  moving in the open. Empty and you gasp audibly — she hears you even while
  still, so you cannot camp a hiding spot forever.
- She makes **noise**: expanding rings mark her position, and an edge arrow
  points toward her when she is off-screen.

## Losing / winning
- **Lose:** caught in Mom's cone, or exposed at a bed check.
- **Win:** back at the bed with the cookie.
- **R** restarts with a new house.
