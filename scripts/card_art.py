#!/usr/bin/env python3
"""Generate card art with the OpenAI API, in steps you run separately.

  generate  Sends each card's prompt in assets/card-art-prompts.jsonl to an OpenAI image model and saves
            assets/cards/<id>.png. The prompts there are already revised for history and style.
  critique  Shows each generated picture to the text model, which lists visual errors (anatomy, objects,
            history, text, style). If it finds any, the image model edits the picture to fix them; the
            old picture moves to assets/card-art-history/. Results go to assets/card-art-critique.jsonl.
            One pass per card, so it never loops.
  apply     Applies the fixes already written in assets/card-art-critique.jsonl (by hand or by an earlier
            critique) without asking the text model again. Skips entries marked fixed (--force redoes them).

Every step skips cards already done (--force redoes them) and takes --only id,id,... to pick cards.
Needs OPENAI_API_KEY. Standard library only.

  python3 scripts/card_art.py generate --only egypt,farm,irrigation_canals
  python3 scripts/card_art.py critique --only egypt,farm,irrigation_canals
  python3 scripts/card_art.py apply --only persia
"""

import argparse
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROMPTS = ROOT / "assets" / "card-art-prompts.jsonl"
ART_DIR = ROOT / "assets" / "cards"
CRITIQUES = ROOT / "assets" / "card-art-critique.jsonl"
HISTORY_DIR = ROOT / "assets" / "card-art-history"
API = "https://api.openai.com/v1"

# Model names change; check OpenAI's model list and override with flags or these variables.
TEXT_MODEL = os.environ.get("CARD_ART_TEXT_MODEL", "gpt-5")
IMAGE_MODEL = os.environ.get("CARD_ART_IMAGE_MODEL", "gpt-image-2.5-sunburst")
# Fixes are few and must change only what's wrong, so critique and apply also run at more effort.
SIZE = "1536x1024"

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


def save_critique(entry: dict, order: list[str]) -> None:
	"""Writes one card's entry into the critique file as it is now, so runs side by side don't undo each other."""
	critiques = {r["id"]: r for r in read_jsonl(CRITIQUES)}
	critiques[entry["id"]] = entry
	write_jsonl(CRITIQUES, sorted(critiques.values(), key=lambda r: order.index(r["id"])))


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


def generate_card(row: dict, model: str, quality: str) -> bytes:
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


def cmd_generate(args) -> int:
	ART_DIR.mkdir(parents=True, exist_ok=True)
	failures = 0
	for card in chosen(read_jsonl(PROMPTS), args.only):
		target = ART_DIR / f"{card['id']}.png"
		if target.exists() and not args.force:
			print(f"skip {card['id']}: {target.name} exists")
			continue
		try:
			target.write_bytes(generate_card(card, args.image_model, args.quality))
		except RuntimeError as err:
			print(f"FAIL {card['id']}: {err}")
			failures += 1
			continue
		print(f"saved {target.relative_to(ROOT)}")
	return 1 if failures else 0


def cmd_critique(args) -> int:
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
		try:
			review = critique_card(card, image, args.text_model)
			entry = {"id": card["id"], **review, "fixed": False}
			if review["verdict"] == "fix" and review["fix"]:
				fixed = fix_card(card, image, review["fix"], args.image_model, args.quality)
				old = keep_old(image)
				image.write_bytes(fixed)
				entry.update(fixed=True, previous=f"{HISTORY_DIR.name}/{old.name}")
		except (RuntimeError, KeyError, json.JSONDecodeError) as err:
			print(f"FAIL {card['id']}: {err}")
			failures += 1
			continue
		critiques[card["id"]] = entry
		save_critique(entry, order)
		problems = "; ".join(entry["problems"]) or "no problems"
		print(f"{'fixed' if entry['fixed'] else 'ok'} {card['id']}: {problems}")
	return 1 if failures else 0


def cmd_apply(args) -> int:
	order = [c["id"] for c in read_jsonl(PROMPTS)]
	failures = 0
	for card in chosen(read_jsonl(PROMPTS), args.only):
		entry = {r["id"]: r for r in read_jsonl(CRITIQUES)}.get(card["id"])  # as it is now, not when the run began
		image = ART_DIR / f"{card['id']}.png"
		if entry is None or entry.get("verdict") != "fix" or not entry.get("fix"):
			print(f"skip {card['id']}: no fix in {CRITIQUES.name}")
			continue
		if entry.get("fixed") and not args.force:
			print(f"skip {card['id']}: already fixed")
			continue
		if not image.exists():
			print(f"skip {card['id']}: no {image.name} yet (run generate)")
			continue
		try:
			fixed = fix_card(card, image, entry["fix"], args.image_model, args.quality)
		except RuntimeError as err:
			print(f"FAIL {card['id']}: {err}")
			failures += 1
			continue
		old = keep_old(image)
		image.write_bytes(fixed)
		entry.update(fixed=True, previous=f"{HISTORY_DIR.name}/{old.name}")
		entry.pop("fixed_by", None)
		entry.pop("fix_notes", None)
		save_critique(entry, order)
		print(f"fixed {card['id']}: {'; '.join(entry['problems'])}")
	return 1 if failures else 0


def main() -> int:
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	steps = parser.add_subparsers(dest="step", required=True)
	generate = steps.add_parser("generate", help="generate pictures from the prompt list")
	critique = steps.add_parser("critique", help="review generated pictures and fix visual errors")
	critique.add_argument("--text-model", default=TEXT_MODEL)
	qualities = ["low", "medium", "high", "xhigh", "max", "auto"]
	generate.add_argument("--image-model", default=IMAGE_MODEL)
	generate.add_argument("--quality", default="high", choices=qualities)
	critique.add_argument("--image-model", default=IMAGE_MODEL)
	critique.add_argument("--quality", default="xhigh", choices=qualities)
	apply = steps.add_parser("apply", help="apply the fixes already in the critique file")
	apply.add_argument("--image-model", default=IMAGE_MODEL)
	apply.add_argument("--quality", default="xhigh", choices=qualities)
	for step in (generate, critique, apply):
		step.add_argument("--only", help="comma-separated card ids")
		step.add_argument("--force", action="store_true", help="redo cards already done")
	args = parser.parse_args()
	steps_run = {"generate": cmd_generate, "critique": cmd_critique, "apply": cmd_apply}
	return steps_run[args.step](args)


if __name__ == "__main__":
	sys.exit(main())
