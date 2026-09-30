# 4X Card Game — prototype

Single-player, Civilization-inspired card game prototype in Godot 4.7 (GDScript).
Design decisions and roadmap: [PLAN.md](PLAN.md).

## Run
Open the folder in Godot and press F5 (Play), or from a terminal:

```bash
godot --path .
```

Drag a card from your hand into the tableau (or double-click it) to play it; press E or "End turn" to
end the turn. Click a territory in the Realm to see it on its own: the territory large on the left with its slots, pop and Grow,
its city and buildings on the right, and an outline for each free slot.
While it is open, a building dropped anywhere on it (or double-clicked) goes there; "Back" or Esc returns.

Keyboard: ←/→ move through your hand, Enter or Space plays the focused card. With several possible
targets, ←/→ pick one, Enter plays it, and Esc cancels. During an explore choice, ←/→ and Enter pick a
territory. ↑ from the hand moves to the Realm's territories (↓ goes back) and Enter opens one; in it, ←/→ move
through its cards. Tab moves through the buttons.
The game ends after 100 turns; your score is the VP on your tableau plus VP from effects.

The top bar shows food and wealth with the change the next upkeep brings in brackets ("Food: 2 (+1)"),
net of what your pop eats; food turns red when pop would starve.

The game opens on a title screen with "New game", "Settings" and "Exit". New game opens a screen where you click
a civilization card to play as it (your last choice is remembered) and "Start" starts a game with the seed in the
seed box, or a random one if it is empty (Enter works too). Settings holds "Reduce motion". "Back" or Esc returns
to the title screen.

"Menu (Esc)" in the top bar opens the menu: "Restart" replays the seed in the seed box (same shuffle),
"New game" leaves the game for the new game screen, and "Reduce motion" turns off decorative animation, and "Exit" quits the game. Esc first cancels
targeting or drops the card focus, then opens the menu; Esc again closes it.

## Edit cards
All content is in `data/cards.json` and `data/config.json`. Card text is generated
from the effects, so it always matches the numbers: a short form on the card, the
full wording on hover. If the data has a mistake, the
game shows every error (file, card, field) instead of starting.

To see what an edit does to balance, run the headless simulator (a scripted bot plays one game per seed):
```bash
scripts/sim.sh 20          # mean / min / max of score, cities, pop, techs, supply buys, era over seeds 1-20
```
In Claude Code, `/balance` runs it on `main` and on your changes and compares them.

## Tests
```bash
scripts/test.sh            # all tests
scripts/test.sh rules      # only tests whose file::name contains "rules"
```
See [docs/testing.md](docs/testing.md).

## Development process
Features and bugs go through a spec → test-first → review flow built for Claude Code:
[docs/development-process.md](docs/development-process.md). Backlog: [docs/backlog/](docs/backlog/).
