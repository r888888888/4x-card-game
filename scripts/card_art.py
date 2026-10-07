#!/usr/bin/env python3
"""Generate card art with the OpenAI API, in two steps you run separately.

  revise    An OpenAI text model reviews each card's subject for historical accuracy and writes
            the result to assets/card-art-revised.jsonl, for you to read before spending on images.
  generate  Sends each revised prompt to an OpenAI image model and saves assets/cards/<id>.png.
            An upgrade (a row with "reference") is drawn from its base's picture, so a base comes first.
  critique  Shows each generated picture to the text model, which lists visual errors (anatomy, objects,
            history, text, style). If it finds any, the image model edits the picture to fix them; the
            old picture moves to assets/card-art-history/. Results go to assets/card-art-critique.jsonl.
            One pass per card, so it never loops.

Only the "Subject:" part of a prompt is revised; the style, inks and composition are put back
around it unchanged, with the generic period swapped for the card's culture_hint and date_hint.

Both steps skip cards already done (--force redoes them) and take --only id,id,... to pick cards.
Needs OPENAI_API_KEY. Standard library only.

  python3 scripts/card_art.py revise --only egypt,farm,irrigation_canals
  python3 scripts/card_art.py generate --only egypt,farm,irrigation_canals
  python3 scripts/card_art.py critique --only egypt,farm,irrigation_canals
"""

import argparse
import base64
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROMPTS = ROOT / "assets" / "card-art-prompts.jsonl"
REVISED = ROOT / "assets" / "card-art-revised.jsonl"
ART_DIR = ROOT / "assets" / "cards"
CRITIQUES = ROOT / "assets" / "card-art-critique.jsonl"
HISTORY_DIR = ROOT / "assets" / "card-art-history"
API = "https://api.openai.com/v1"

# Model names change; check OpenAI's model list and override with flags or these variables.
TEXT_MODEL = os.environ.get("CARD_ART_TEXT_MODEL", "gpt-5")
IMAGE_MODEL = os.environ.get("CARD_ART_IMAGE_MODEL", "gpt-image-2.5-flare")
SIZE = "1536x1024"

PERIOD = "The ancient Near East and Mediterranean, 3000–300 BCE. "
PROMPT_PARTS = re.compile(
	r"^(?P<style>.*?)" + re.escape(PERIOD) + r"Subject: (?P<subject>.*?)"
	r"(?P<reference> Redraw the attached .*?\.)? (?P<inks>Printed in .*)$", re.S)

CONSULTANT = """You are the historical consultant for a strategy game's illustration system.

Review the supplied image-generation prompt for historical plausibility.

The visual art direction, composition language, palette, print technique,
aspect ratio, and negative-space requirements are intentional and should
normally remain unchanged.

Concentrate on:
- material culture
- weapons and armor
- architecture
- transport
- clothing
- agriculture
- religious imagery
- settlement scale
- chronology
- geography
- culturally incompatible combinations

Prefer historically characteristic details over merely possible ones.

Do not make the prompt substantially more complex.
Do not add extra figures or objects merely to demonstrate historical knowledge.
Preserve the prompt's visual simplicity.

Make exactly ONE revision pass.

If the prompt is already plausible, make only minor improvements.
If the period/culture is ambiguous, choose the most natural historical
interpretation suggested by the subject and say what interpretation you chose.

The final revised prompt should remain ready to send directly to an
image-generation model.

How to answer for this system:
- The setting given is the default interpretation. Keep it unless the subject plainly belongs
  elsewhere; if you change it, give the new one in "culture" and "date".
- Revise ONLY the subject description. The style, inks and composition text around it are fixed
  and will be put back unchanged, so don't repeat them.
- Keep the subject about as long as it is now, as one or two plain sentences.
- Never add writing, inscriptions, signs or legible script: the picture must contain no text.
- Reply with JSON only: {"subject": "...", "culture": "...", "date": "...",
  "interpretation": "the interpretation you chose, one sentence",
  "changes": "what you changed and why, or 'none'"}"""

CRITIC = """You are the art reviewer for a strategy game's card illustrations. You are shown one
generated illustration and the prompt it was made from.

The style is deliberate and is NOT an error: a flat, stylised mid-century print with simplified
figures, cut-paper shapes, few inks and lots of empty space. Don't ask for photorealism, depth,
shading or more detail. "Realism" here means the picture makes physical and historical sense.

Look for obvious errors a viewer would notice:
- anatomy: extra or missing limbs, fingers, heads; impossible poses; malformed animals
- objects: broken or impossible structures, wheels, boats, tools, weapons; things floating or merged
- physics and scale: wrong shadows or reflections that draw the eye, absurd relative sizes
- history: anything clearly outside the stated culture and period (anachronisms)
- the prompt's rules: any text, letters or numbers; a border or frame; colours far outside the
  listed inks; the main subject outside the middle 60 % of the height
- the subject: something the prompt asks for that is missing or wrong

Report only clear problems, not taste. If there are none, say so.

Reply with JSON only: {"verdict": "ok" or "fix",
  "problems": ["one short line per problem"],
  "fix": "instructions for an image editor to fix exactly these problems and change nothing else,
          or '' when the verdict is ok"}"""


def read_jsonl(path: Path) -> list[dict]:
	if not path.exists():
		return []
	return [json.loads(line) for line in path.read_text().splitlines() if line.strip()]


def write_jsonl(path: Path, rows: list[dict]) -> None:
	path.write_text("".join(json.dumps(r, ensure_ascii=False, separators=(",", ":")) + "\n" for r in rows))


def split_prompt(card: dict) -> dict:
	found = PROMPT_PARTS.match(card["prompt"])
	if found is None:
		sys.exit(f"{PROMPTS.name}: {card['id']}'s prompt doesn't match the template (no period or Subject:)")
	return found.groupdict()


def assemble(parts: dict, subject: str, culture: str, date: str) -> str:
	return (f"{parts['style']}{culture}, {date}. Subject: {subject.strip().rstrip('.')}."
		f"{parts['reference'] or ''} {parts['inks']}")


def request(path: str, body: bytes, content_type: str) -> dict:
	key = os.environ.get("OPENAI_API_KEY")
	if not key:
		sys.exit("Set OPENAI_API_KEY first.")
	for attempt in range(4):
		req = urllib.request.Request(f"{API}/{path}", data=body, method="POST",
			headers={"Authorization": f"Bearer {key}", "Content-Type": content_type})
		try:
			with urllib.request.urlopen(req, timeout=300) as resp:
				return json.load(resp)
		except urllib.error.HTTPError as err:
			detail = err.read().decode(errors="replace")
			if err.code in (429, 500, 502, 503) and attempt < 3:
				time.sleep(10 * 2 ** attempt)
				continue
			raise RuntimeError(f"{path}: HTTP {err.code}: {detail}") from None
	raise RuntimeError(f"{path}: gave up after retries")


def post_json(path: str, payload: dict) -> dict:
	return request(path, json.dumps(payload).encode(), "application/json")


def post_multipart(path: str, fields: dict, files: dict) -> dict:
	boundary = uuid.uuid4().hex
	body = b""
	for name, value in fields.items():
		body += (f"--{boundary}\r\nContent-Disposition: form-data; name=\"{name}\"\r\n\r\n{value}\r\n").encode()
	for name, file in files.items():
		body += (f"--{boundary}\r\nContent-Disposition: form-data; name=\"{name}\"; filename=\"{file.name}\"\r\n"
			"Content-Type: image/png\r\n\r\n").encode() + file.read_bytes() + b"\r\n"
	body += f"--{boundary}--\r\n".encode()
	return request(path, body, f"multipart/form-data; boundary={boundary}")


def revise_card(card: dict, model: str) -> dict:
	parts = split_prompt(card)
	ask = (f"Card: {card['id']}\nSetting: {card['culture_hint']}, {card['date_hint']}\n"
		f"Subject to review: {parts['subject']}\n\nFull prompt, for context only:\n{card['prompt']}")
	reply = post_json("chat/completions", {
		"model": model,
		"response_format": {"type": "json_object"},
		"messages": [{"role": "system", "content": CONSULTANT}, {"role": "user", "content": ask}],
	})
	answer = json.loads(reply["choices"][0]["message"]["content"])
	culture = answer.get("culture") or card["culture_hint"]
	date = answer.get("date") or card["date_hint"]
	return {
		"id": card["id"],
		"prompt": assemble(parts, answer["subject"], culture, date),
		"culture": culture,
		"date": date,
		"interpretation": answer.get("interpretation", ""),
		"changes": answer.get("changes", ""),
		"original_subject": parts["subject"],
		**({"reference": card["reference"]} if "reference" in card else {}),
	}


def generate_card(row: dict, model: str, quality: str) -> bytes:
	if "reference" in row:
		base = ART_DIR / f"{row['reference']}.png"
		if not base.exists():
			raise RuntimeError(f"needs {base.name} first (it's this upgrade's reference)")
		reply = post_multipart("images/edits",
			{"model": model, "prompt": row["prompt"], "size": SIZE, "quality": quality}, {"image": base})
	else:
		reply = post_json("images/generations",
			{"model": model, "prompt": row["prompt"], "size": SIZE, "quality": quality, "n": 1})
	return base64.b64decode(reply["data"][0]["b64_json"])


def critique_card(row: dict, image: Path, model: str) -> dict:
	picture = base64.b64encode(image.read_bytes()).decode()
	reply = post_json("chat/completions", {
		"model": model,
		"response_format": {"type": "json_object"},
		"messages": [{"role": "system", "content": CRITIC}, {"role": "user", "content": [
			{"type": "text", "text": f"Card: {row['id']}\nPrompt it was made from:\n{row['prompt']}"},
			{"type": "image_url", "image_url": {"url": f"data:image/png;base64,{picture}"}},
		]}],
	})
	answer = json.loads(reply["choices"][0]["message"]["content"])
	return {"verdict": answer.get("verdict", "ok"), "problems": answer.get("problems", []), "fix": answer.get("fix", "")}


def fix_card(row: dict, image: Path, fix: str, model: str, quality: str) -> bytes:
	prompt = (f"Edit this illustration. {fix.strip()} Keep everything else exactly as it is: the composition, "
		f"colours, print style and subject. The illustration was made from this prompt: {row['prompt']}")
	reply = post_multipart("images/edits",
		{"model": model, "prompt": prompt, "size": SIZE, "quality": quality}, {"image": image})
	return base64.b64decode(reply["data"][0]["b64_json"])


def keep_old(image: Path) -> Path:
	HISTORY_DIR.mkdir(parents=True, exist_ok=True)
	(HISTORY_DIR / ".gdignore").touch()
	old = HISTORY_DIR / f"{image.stem}-{time.strftime('%Y%m%d-%H%M%S')}.png"
	image.rename(old)
	return old


def chosen(cards: list[dict], only: str | None) -> list[dict]:
	if not only:
		return cards
	wanted = [i.strip() for i in only.split(",") if i.strip()]
	known = {c["id"] for c in cards}
	unknown = [i for i in wanted if i not in known]
	if unknown:
		sys.exit(f"Unknown card ids: {', '.join(unknown)}")
	return [c for c in cards if c["id"] in wanted]


def cmd_revise(args) -> int:
	revised = {r["id"]: r for r in read_jsonl(REVISED)}
	failures = 0
	for card in chosen(read_jsonl(PROMPTS), args.only):
		if card["id"] in revised and not args.force:
			print(f"skip {card['id']}: already in {REVISED.name}")
			continue
		try:
			row = revise_card(card, args.text_model)
		except (RuntimeError, KeyError, json.JSONDecodeError) as err:
			print(f"FAIL {card['id']}: {err}")
			failures += 1
			continue
		revised[row["id"]] = row
		order = [c["id"] for c in read_jsonl(PROMPTS)]
		write_jsonl(REVISED, sorted(revised.values(), key=lambda r: order.index(r["id"])))
		print(f"revised {row['id']}: {row['changes']}")
	return 1 if failures else 0


def cmd_generate(args) -> int:
	revised = {r["id"]: r for r in read_jsonl(REVISED)}
	ART_DIR.mkdir(parents=True, exist_ok=True)
	failures = 0
	for card in chosen(read_jsonl(PROMPTS), args.only):
		target = ART_DIR / f"{card['id']}.png"
		if target.exists() and not args.force:
			print(f"skip {card['id']}: {target.name} exists")
			continue
		row = revised.get(card["id"])
		if row is None:
			if not args.unrevised:
				print(f"skip {card['id']}: not revised yet (run revise, or pass --unrevised)")
				continue
			row = card
		try:
			target.write_bytes(generate_card(row, args.image_model, args.quality))
		except RuntimeError as err:
			print(f"FAIL {card['id']}: {err}")
			failures += 1
			continue
		print(f"saved {target.relative_to(ROOT)}")
	return 1 if failures else 0


def cmd_critique(args) -> int:
	revised = {r["id"]: r for r in read_jsonl(REVISED)}
	critiques = {r["id"]: r for r in read_jsonl(CRITIQUES)}
	order = [c["id"] for c in read_jsonl(PROMPTS)]
	failures = 0
	for card in chosen(read_jsonl(PROMPTS), args.only):
		image = ART_DIR / f"{card['id']}.png"
		if not image.exists():
			print(f"skip {card['id']}: no {image.name} yet (run generate)")
			continue
		if card["id"] in critiques and not args.force:
			print(f"skip {card['id']}: already in {CRITIQUES.name}")
			continue
		row = revised.get(card["id"], card)
		try:
			review = critique_card(row, image, args.text_model)
			entry = {"id": card["id"], **review, "fixed": False}
			if review["verdict"] == "fix" and review["fix"]:
				fixed = fix_card(row, image, review["fix"], args.image_model, args.quality)
				old = keep_old(image)
				image.write_bytes(fixed)
				entry.update(fixed=True, previous=f"{HISTORY_DIR.name}/{old.name}")
		except (RuntimeError, KeyError, json.JSONDecodeError) as err:
			print(f"FAIL {card['id']}: {err}")
			failures += 1
			continue
		critiques[card["id"]] = entry
		write_jsonl(CRITIQUES, sorted(critiques.values(), key=lambda r: order.index(r["id"])))
		problems = "; ".join(entry["problems"]) or "no problems"
		print(f"{'fixed' if entry['fixed'] else 'ok'} {card['id']}: {problems}")
	return 1 if failures else 0


def main() -> int:
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	steps = parser.add_subparsers(dest="step", required=True)
	revise = steps.add_parser("revise", help="review subjects for historical accuracy")
	revise.add_argument("--text-model", default=TEXT_MODEL)
	generate = steps.add_parser("generate", help="generate images from revised prompts")
	generate.add_argument("--unrevised", action="store_true", help="use the original prompt when a card has no revision")
	critique = steps.add_parser("critique", help="review generated pictures and fix visual errors")
	critique.add_argument("--text-model", default=TEXT_MODEL)
	for step in (generate, critique):
		step.add_argument("--image-model", default=IMAGE_MODEL)
		step.add_argument("--quality", default="high", choices=["low", "medium", "high", "xhigh", "max", "auto"])
	for step in (revise, generate, critique):
		step.add_argument("--only", help="comma-separated card ids")
		step.add_argument("--force", action="store_true", help="redo cards already done")
	args = parser.parse_args()
	return {"revise": cmd_revise, "generate": cmd_generate, "critique": cmd_critique}[args.step](args)


if __name__ == "__main__":
	sys.exit(main())
