# Cookie time-traveler

## Concept
It's night and a kid it's in his bedroom and must sleep.
But the kid really craves a cookie.
He must reach the kitchen from the bedroom, eat the cookie and
then go back to his room as nothing happened.

To avoid waking up the mum, the kid has a candle/flashlight that
lets him see the path and not travel in darkness.

The problem: the kids movements in the house still disturb the 
sleeping mum. She knocks on the kitchen door as soon as the kid
grabs the cookie, how can he avoid getting caught?

He's a special power: he can travel back in time to go back to the
room with the cookie, as nothing happened. The problem is that this
only works if he does the exact same steps he did to ge to the 
kitchen in reverse.

# Core mechanic
The whole game is one mechanic: perform a sequence of actions forward,
then recall and invert it under time pressure.

# Gameplay
## 1. Forward phase
Explore a randomized house, starting from the kid's room, to find the kitchen,
choosing a door per room; some rooms have multiple doors, some 
don't and are dead ends. The gameplay is easy you don't move in the room, you just
decide in which door to go:
- <- (left arrow) - left room
- -> (right arrow) - right room
- ^ (up arrow) - up room
- v (down arrow) - down room

The user doesn't have to make a random decision as he will see some hints from the
door (e.g. the floor color, the floor texture etc.) that will allow him to 
under stand which room the doors lead to. This is allowed by the light that, however
goes slowly off with time passing, up to the point where the light goes off and you
can't see in the rooms anymore.

## 2. Entering the kitchen
As soon as you enter the kitchen, you automatically grab the cookie and the reverse
phase starts. 

## 3. Reverse phase
Another timer starts, which lasts the exact amount of time it took you
to get to the kitchen in the forward phase. You don't have any light in this phase,
you only have to remember the sequence of actions you did and reverse them
(if you made a mistake in the forward phase and went to a dead end, this counts
anyway as an action!).

E.g.:
forward phase:  ROOM -> left, right, up, up, right -> KITCHEN
backward phase: KITCHEN <- left, down, down, left, right -> ROOM

## 4. Failing
Forward phase: you fail by missing the clock (mom wakes up).
Backward phase: you fail by missing the clock or failing the sequence 
(to decide if failing the sequence is a game-over or a time cut on the timer).

## 5. Succeeding
Completing forward+backward successfully in time.

# Game progress design
Infinite game: from level 0 to INF (or to 100+), each level being randomly generated.
(Seed is always the same so each level design is the same for every run game).
The higher the level, the higher the difficulty.

## Difficulty increase
Ideas:
- increase number of rooms
- increase variety of rooms (more dead end options, new unseen rooms)
- increase house floors
- lights wears out faster

By playing, the user will learn that some rooms are dead ends and some are not,
so he will start to learn how to explore in the forward phase, thanks to the light
and the hints.

Increasing the difficulty could also mean that the more you go on, the more this
"hints" change (e.g. the room changes color but not floor texture, or rooms that 
were dead ends start to have some extra doors). 

# Scoring
The user gets points when he completes the level. The faster, the higher the points.
The slower, the lower the points. Repeating levels due to mistakes causes less
points at next try. User cannot choose which levels to replay, but
can choose to replay the whole sequence of levels to achieve higher scores 
(bronze, gold, platinum trophies).

# Tutorial
Very easy tutorial level to understand game logic.

# Additional ideas

## Time-saving rooms
At higher level of difficulties, it becomes very hard to remember the backward path;
the game can spawn rooms in which the user can enter that will make the clock go slower
(not stop), so the user can reason a bit.

This means though that due to the forward-backward replay logic, the user needs to program
and decide in the forward phase when to stop in the time-saving room.

## Different objects/rooms 
To vary the target a bit, it could be possible to decide different rooms to reach/objects
to catch.

## Multiple objects to catch
The user must be asked to reach many rooms in sequence (e.g. cookie in the kitchen, football
ball in the garage etc.) and then go backward. This increase difficulty.

## More...