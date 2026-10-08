---
name: card-art
description: Take the card art list (docs/design/card-art.md) to reviewed pictures in assets/cards/. Claude writes the prompt for every new or changed brief, draws with scripts/card_art.py after the developer approves the spend, reviews each picture, fixes or redraws what fails, re-reviews, and ends with a report and one commit. Use when the user asks for card art ("card art", "generate the art", "draw the new cards", "review the card art", "/card-art"), or after the art list changes. Not for the game's art plate code (ui/card_art.gd).
---

# Card art: from brief to approved picture

The files (397):
- `docs/design/card-art.md`: the developer's list, one row per card: file, brief, inks. Claude never edits it.
- `assets/card-art-prompts.jsonl`: one row per card, written by Claude: `id`, `prompt` (what is sent), `culture`,
  `date`, `notes` (what the revision changed and why), and `brief` and `inks` as they were in the list when the prompt
  was written, so a changed brief shows.
- `assets/card-art-review.jsonl`: one row per card. The script writes `prompt_hash`, `image_hash` and `edit_rounds`;
  Claude writes `approved_hash` and `findings`.
- `scripts/card_art.py status | generate | fix` (each takes `--only id,id`). `status` lists the cards under
  `generate`, `review` and `fix`, and costs nothing. Every replaced picture moves to `assets/card-art-history/`
  (ignored by git).

Before anything else: if `OPENAI_API_KEY` is empty in the environment (`[ -n "$OPENAI_API_KEY" ]`), stop and say so.
Don't hand the developer commands to run instead. Work on the current branch; note each card's `edit_rounds` and
number of `prompt` findings now, since the limits in step 5 count from the start of this run.

## 1. Prompts for new and changed briefs

Find the cards whose brief or inks in the list differ from their prompt row's, and the cards with no row:

```bash
python3 - <<'EOF'
import json, re
rows = {r["id"]: r for r in map(json.loads, open("assets/card-art-prompts.jsonl"))}
listed = {}
for line in open("docs/design/card-art.md"):
	m = re.match(r"^\| `(\w+)\.png` \| (.*?) \| (.*) \| ([a-z, ]+) \|\s*$", line)
	if m: listed[m[1]] = (m[3], m[4])
print("new:", [c for c in listed if c not in rows])
print("changed:", [c for c, (b, i) in listed.items() if c in rows and (rows[c].get("brief"), rows[c].get("inks")) != (b, i)])
print("not in the list:", [c for c in rows if c not in listed])
EOF
```

A card "not in the list" was removed or renamed: ask the developer before deleting its row or picture.

For each new or changed card, write its row (new rows in the list's order):
- **Prompt**: the template in the style guide's §19.8 (`docs/design/mcm-style-guide.md`, `### 19.8`) word for word,
  except the era sentence ("The ancient Near East and Mediterranean, 3000–300 BCE.") becomes the card's own culture
  and date ("Achaemenid Persia, 550–330 BCE."), and the inks are the row's: the first is dominant, the rest support,
  with the hex values from the list's **Inks** paragraph. Revise only the subject, from the brief:
  - for history: the culture and date the card belongs to (its civilization, or where and when the thing it shows
    began), with buildings, dress, tools and ships of that place and time. Put them in `culture` and `date`;
  - for the style guide's §19 (read §19.1–19.6): one scene, the subject inside the middle 60 % of the height, the
    type's treatment (§19.6);
  - for the generator's **weak spots**, which it gets wrong often enough to cost a redraw:
    - an exact count above four of the same figure (columns, soldiers, sheaves): ask for "a row of" or "several", or
      for four or fewer;
    - light and shadow: one light source, or no cast shadows; never a sun on one side and shadows falling toward it;
    - moon phases: name the shape ("a thin crescent, horns pointing up-right"), and no sun in the same sky unless the
      brief needs it;
    - reflections: leave them out, or say exactly what is mirrored;
    - figures sitting on or holding things: say what sits on what and which hand holds what; keep it to one simple
      contact per figure.
- `notes`: what the revision changed from the brief and why, in a sentence or two.
- `brief` and `inks`: copied exactly from the list's row.

An **upgrade** redraws its base card's picture grown: describe the same viewpoint and layout as the base's prompt.

A card whose prompt changed now shows under `generate` in `status`.

## 2. Ask before spending

Before every `generate` or `fix` run, show the developer `status`'s list for that step and the number of pictures it
will make, and run it only after they say yes in the chat. A yes covers that run only.

Run in batches of at most 8 cards (`--only id,...,id`), the same batches you'll review. Each picture takes up to a
minute or two, so run each batch with `run_in_background` and wait for it to finish. A `FAIL` line is an API error:
rerun that card once, then report it.

```bash
python3 scripts/card_art.py status
python3 scripts/card_art.py generate --only egypt,sumer
python3 scripts/card_art.py fix --only persia
```

## 3. Review

Review every card `status` lists under `review`, at most 8 pictures per batch:
- Read the picture next to its prompt row. Then zoom into the places errors hide: hands, counts, joins (where a
  roof meets a wall, a wheel meets an axle, an oar meets a hull), shadows and reflections. Crop with `sips` into the
  scratchpad (`sips -c <height> <width> --cropOffset <y> <x> assets/cards/<id>.png --out <scratchpad>/<id>-zoom.png`;
  the picture is 1536 × 1024) and Read the crop.
- Check the prompt's rules too: no text, letters or numbers; no border; the inks; the subject inside the middle 60 %.
- **Not errors** (house style; don't report them): a cream sky at night; stars or a moon in a day scene; vignette or
  soft edges; flattened perspective and simplified, cut-paper figures; overprinted colours.

Write each card's result as soon as it's judged, not at the end of the batch, so a stopped run loses nothing:

```bash
python3 - <<'EOF'
import sys; sys.path.insert(0, "scripts")
from pathlib import Path
import card_art as c
paths = c.Paths(Path("."))
card = "persia"
row = c.review_rows(paths)[card]
image = c.sha(paths.picture(card).read_bytes())  # the picture you looked at
row["approved_hash"] = image  # when it passes; otherwise add findings instead:
# row["findings"].append({"problem": "...", "action": "edit", "fix": "...", "for_hash": image, "done": False})
c.save_row(paths, row, [r["id"] for r in c.read_jsonl(paths.prompts)])
EOF
```

A picture either passes (approve its hash) or gets findings, one per problem, each with an action:
- `edit`: a local fix the image editor can make. `fix` names where ("the spear held by the second soldier from the
  left"), describes the result ("a single bronze head"), and ends "Change nothing else." `done: false`.
- `prompt`: the editor can't fix it, so the prompt is rewritten and the card redrawn. Rewrite the prompt row now
  (step 1's rules, with the weak spot that caused it) and set `done: true`. Use this for what the editor fails at:
  flipping or mirroring anything, changing a count, turning figures round, rebuilding a structure, and any error
  across most of the picture.
- `accept`: a real flaw not worth a redraw; `fix` holds the reason. `done: true`. A picture whose findings are all
  `accept` is approved too.

## 4. Fix and redraw

`status` now lists `edit` cards under `fix` and rewritten prompts under `generate`. Ask (step 2), run `fix` and
`generate`, and the fixed and redrawn pictures show under `review`: review them (step 3) like new ones. A fix is never
trusted unchecked; edits often break something else.

## 5. Loop and stop

Repeat steps 2–4 until `status` lists nothing, or only cards out of tries:
- A card gets at most **2 edit rounds** (its `edit_rounds` grew by 2 this run); after that its next finding must be
  `prompt`.
- After those, at most **1 redraw** (one more `prompt` finding). A card still failing after it is left unapproved,
  with its findings recorded, and named in the report.

## 6. Finish

Report to the developer: the cards approved, the findings accepted (card and reason), and the cards left unresolved
with what is still wrong. Then commit on the current branch, never the history folder:

```bash
git add assets/cards assets/card-art-prompts.jsonl assets/card-art-review.jsonl
git commit -m "card art: <what was drawn, fixed and approved>"
```
