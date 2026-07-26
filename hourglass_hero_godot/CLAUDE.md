# Working on Sandbound

## Language

Everything written down — code, comments, commit messages, docs, in-game text —
is in English.

## The feature loop

Every feature follows the same five steps. Do not skip a step, and do not run
two features in the same worktree.

### 1. Branch off an up-to-date main

Always start from the main checkout at `/Users/justinchapon/GMTK-Game-Jam-2026`,
never from another worktree:

```bash
cd /Users/justinchapon/GMTK-Game-Jam-2026 && git fetch origin && git checkout main && git pull --ff-only
```

The fetch is not optional and neither is doing it *now*: a `main` that was
current an hour ago is not current, and a worktree branched off a stale one
lands as a merge commit that drags old work back with it. Never create the
worktree before this command has actually run and printed its result.

If `main` has uncommitted changes, stop and ask the user what to do with them.

Then create the worktree. Name the branch and the worktree folder after the
feature, in kebab-case:

```bash
git worktree add .claude/worktrees/<feature> -b <feature> main
```

`.claude/` is gitignored, so the worktrees never show up in a diff. Note that
the git root is the jam repo, not this folder: the Godot project lives at
`<worktree>/hourglass_hero_godot`.

Then import the fresh worktree, once:

```bash
godot --headless --import --path .claude/worktrees/<feature>/hourglass_hero_godot
```

`.godot/` is generated and gitignored, so a new worktree does not have one, and
`project.godot` names the main scene by UID — with no UID table Godot aborts with
"Main scene's path could not be resolved from UID" before the game even starts.
This is the agent's job: never hand the user a run command for a worktree that
has not been imported. It takes a minute and is the only time the agent runs
Godot itself.

### 2. Build the feature in the worktree

Work only inside `.claude/worktrees/<feature>/hourglass_hero_godot`. Commit as
you go, in small commits with imperative one-line subjects that say what the
change does for the game ("Open the exit as a portal instead of a panel"), not
which files moved. No `feat:`/`fix:` prefixes.

Never commit `.godot/` — it is generated and already ignored.

### 3. Hand the user a run command

When the feature is done, do not merge. Give the user the exact command to play
it from the worktree, and say in one or two sentences what to look for:

```bash
godot --path /Users/justinchapon/GMTK-Game-Jam-2026/.claude/worktrees/<feature>/hourglass_hero_godot
```

Then wait. The user validating is the only thing that unlocks step 4. If they
report a problem, fix it in the same worktree and hand them the command again.

### 4. Trim the comments

Once validated, and before merging, re-read the diff and cut the comments back
to the strict minimum. Delete anything that restates the code, narrates the
change, or repeats a name. Keep only what the code cannot say itself: a
non-obvious reason, a tuning value's origin, a gotcha. Commit that pass on its
own ("Trim the portal comments to what is not in the code").

### 5. Merge, push, clean up

```bash
cd /Users/justinchapon/GMTK-Game-Jam-2026 && git checkout main && git pull --ff-only && git merge <feature> && git push
```

If the merge conflicts, resolve it yourself in the main checkout — keep both
intents rather than picking a side blindly — and tell the user what you decided.
If the resolution is a real design choice, ask before committing it.

Then remove the worktree and the branch so nothing lingers:

```bash
cd /Users/justinchapon/GMTK-Game-Jam-2026 && git worktree remove .claude/worktrees/<feature> && git branch -d <feature>
```

`git branch -d` refusing to delete means the merge did not land — investigate,
do not force it with `-D`.

## Tests

Only write tests for the maths: sand arithmetic, geometry, plane swaps, layout
numbers, anything that is a pure function of its inputs. They run headless, with
no game and nothing rendered, following the pattern already in `tests/`:

```bash
godot --headless --path <path-to>/hourglass_hero_godot tests/sand_test.tscn
```

Do not write tests that play a level, script inputs, walk a player through a
scene, or compare screenshots — no automated level runs of any kind. Verifying
that the game *feels* right is the user's job, in step 3. When a change is not
expressible as a number, say so and hand over the run command instead of
inventing a test around it.

## Running the game

From any checkout:

```bash
godot --path <path-to>/hourglass_hero_godot
```

It launches fullscreen at a 960×540 design resolution, letterboxed. `Esc`
returns to the menu, `R` restarts, `F1` opens the tuning panel, `Alt+Enter`
leaves fullscreen. See [README.md](README.md) for the game's rules and layout.
