# 4X Card Game — prototype

Single-player, Civilization-inspired card game prototype in Godot 4.7 (GDScript).
Design decisions and roadmap: [PLAN.md](PLAN.md).

## Run
Open the folder in Godot and press F5 (Play), or from a terminal:

```bash
godot --path .
```

Drag a card from your hand into the tableau (or double-click it) to play it; press E or "End turn" to
end the turn.

Keyboard: ←/→ move through your hand, Enter or Space plays the focused card. With several possible
targets, ←/→ pick one, Enter plays it, and Esc cancels. During an explore choice, ←/→ and Enter pick a
territory. Tab moves through the buttons. "Reduce motion" in the top bar turns off decorative animation.
The game ends after 20 turns; your score is the VP on your tableau plus VP from effects.
"Restart" replays the seed in the seed box (same shuffle), "New game" picks a random seed.

## Edit cards
All content is in `data/cards.json` and `data/config.json`. Card text is generated
from the effects, so it always matches the numbers. If the data has a mistake, the
game shows every error (file, card, field) instead of starting.

## Tests
```bash
scripts/test.sh            # all tests
scripts/test.sh rules      # only tests whose file::name contains "rules"
```
See [docs/testing.md](docs/testing.md).

## Development process
Features and bugs go through a spec → test-first → review flow built for Claude Code:
[docs/development-process.md](docs/development-process.md). Backlog: [docs/backlog/](docs/backlog/).
