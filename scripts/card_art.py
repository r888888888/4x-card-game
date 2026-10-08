#!/usr/bin/env python3
"""Draw and fix card art with the OpenAI image API, tracking what each card needs (397).

  status    Lists the cards that need drawing, reviewing or fixing. Makes no API call and needs no key.
  generate  Draws every card whose prompt in assets/card-art-prompts.jsonl is new or changed since its picture
            was drawn, and saves assets/cards/<id>.png.
  fix       Sends each picture with a pending `edit` finding to the image editor with the finding's instruction.
            A finding written for an older picture is stale and skipped.

Claude reviews the pictures and writes the results (approved_hash, findings) into assets/card-art-review.jsonl; this
script writes the hashes (SHA-256 of the prompt and of the PNG) and edit_rounds. A card needs:
  generate  no picture, or its prompt's hash isn't the one its picture was drawn from;
  fix       an `edit` finding, not done, written for its current picture;
  review    otherwise, while its picture's hash isn't the approved one.
Every replaced picture moves to assets/card-art-history/ (ignored by git). One run at a time: generate and fix hold
assets/.card-art.lock. Each step takes --only id,id,... to pick cards; generate --force redraws them, fix --force
applies stale findings too. Needs OPENAI_API_KEY when there is work to do. Standard library only.

  python3 scripts/card_art.py status
  python3 scripts/card_art.py generate --only egypt,farm
  python3 scripts/card_art.py fix
"""

import argparse
import base64
import contextlib
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

API = "https://api.openai.com/v1"

# Model names change; check OpenAI's model list and override with flags or this variable.
IMAGE_MODEL = os.environ.get("CARD_ART_IMAGE_MODEL", "gpt-image-2.5-sunburst")
SIZE = "1536x1024"
QUALITIES = ["low", "medium", "high", "xhigh", "max", "auto"]


class Paths:
	"""Where the art lives under one project root (a temporary one in the tests)."""

	def __init__(self, root: Path):
		assets = root / "assets"
		self.root = root
		self.prompts = assets / "card-art-prompts.jsonl"
		self.art = assets / "cards"
		self.review = assets / "card-art-review.jsonl"
		self.history = assets / "card-art-history"
		self.lock = assets / ".card-art.lock"

	def picture(self, card: str) -> Path:
		return self.art / f"{card}.png"


def read_jsonl(path: Path) -> list[dict]:
	if not path.exists():
		return []
	return [json.loads(line) for line in path.read_text().splitlines() if line.strip()]


def write_jsonl(path: Path, rows: list[dict]) -> None:
	path.write_text("".join(json.dumps(r, ensure_ascii=False, separators=(",", ":")) + "\n" for r in rows))


def sha(data: bytes | str) -> str:
	return hashlib.sha256(data.encode() if isinstance(data, str) else data).hexdigest()


def review_rows(paths: Paths) -> dict[str, dict]:
	return {r["id"]: r for r in read_jsonl(paths.review)}


def save_row(paths: Paths, row: dict, order: list[str]) -> None:
	"""Writes one card's row into the review file as it is now, so Claude's edits made during a run aren't undone."""
	rows = review_rows(paths)
	rows[row["id"]] = row
	rank = {card: i for i, card in enumerate(order)}
	write_jsonl(paths.review, sorted(rows.values(), key=lambda r: rank.get(r["id"], len(rank))))


def new_row(card: str) -> dict:
	return {"id": card, "prompt_hash": "", "image_hash": "", "approved_hash": "", "edit_rounds": 0, "findings": []}


def pending_edits(row: dict | None) -> list[dict]:
	return [f for f in (row or {}).get("findings", []) if f.get("action") == "edit" and not f.get("done")]


def need(paths: Paths, card: dict, row: dict | None) -> str:
	"""What the card needs next: "generate", "fix", "review" or "" (approved)."""
	picture = paths.picture(card["id"])
	if not picture.exists() or row is None or row.get("prompt_hash") != sha(card["prompt"]):
		return "generate"
	image = sha(picture.read_bytes())
	if any(f.get("for_hash") == image for f in pending_edits(row)):
		return "fix"
	return "review" if row.get("approved_hash") != image else ""


def api_key() -> str:
	key = os.environ.get("OPENAI_API_KEY")
	if not key:
		sys.exit("Set OPENAI_API_KEY first.")
	return key


def request(path: str, body: bytes, content_type: str) -> dict:
	key = api_key()
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


def generate_card(card: dict, model: str, quality: str) -> bytes:
	reply = post_json("images/generations",
		{"model": model, "prompt": card["prompt"], "size": SIZE, "quality": quality, "n": 1})
	return base64.b64decode(reply["data"][0]["b64_json"])


def fix_card(card: dict, image: Path, fixes: list[str], model: str, quality: str) -> bytes:
	prompt = (f"Edit this illustration. {' '.join(f.strip() for f in fixes)} Keep everything else exactly as it is: "
		f"the composition, colours, print style and subject. The illustration was made from this prompt: {card['prompt']}")
	reply = post_multipart("images/edits",
		{"model": model, "prompt": prompt, "size": SIZE, "quality": quality}, {"image": image})
	return base64.b64decode(reply["data"][0]["b64_json"])


def replace_picture(paths: Paths, card: str, data: bytes) -> None:
	"""Saves the card's new picture, moving any old one to the history folder first."""
	picture = paths.picture(card)
	if picture.exists():
		paths.history.mkdir(parents=True, exist_ok=True)
		(paths.history / ".gdignore").touch()
		picture.rename(paths.history / f"{card}-{time.strftime('%Y%m%d-%H%M%S')}.png")
	paths.art.mkdir(parents=True, exist_ok=True)
	picture.write_bytes(data)


@contextlib.contextmanager
def locked(paths: Paths):
	"""Holds the lock file for one run; a second run stops instead of undoing the first one's records."""
	try:
		fd = os.open(paths.lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
	except FileExistsError:
		sys.exit(f"Another card_art.py run holds {paths.lock}; wait for it, or delete the file if no run is going.")
	try:
		os.write(fd, f"{os.getpid()}\n".encode())
		os.close(fd)
		yield
	finally:
		paths.lock.unlink(missing_ok=True)


def chosen(cards: list[dict], only: str | None) -> list[dict]:
	if not only:
		return cards
	wanted = [i.strip() for i in only.split(",") if i.strip()]
	known = {c["id"] for c in cards}
	unknown = [i for i in wanted if i not in known]
	if unknown:
		sys.exit(f"Unknown card ids: {', '.join(unknown)}")
	return [c for c in cards if c["id"] in wanted]


def cmd_status(paths: Paths, args) -> int:
	rows = review_rows(paths)
	groups: dict[str, list[str]] = {"generate": [], "review": [], "fix": []}
	for card in chosen(read_jsonl(paths.prompts), args.only):
		state = need(paths, card, rows.get(card["id"]))
		if state:
			groups[state].append(card["id"])
	for group, cards in groups.items():
		if cards:
			print(f"{group}: {', '.join(cards)}")
	if not any(groups.values()):
		print("nothing to do")
	return 0


def cmd_generate(paths: Paths, args) -> int:
	cards = read_jsonl(paths.prompts)
	order = [c["id"] for c in cards]
	rows = review_rows(paths)
	work = [c for c in chosen(cards, args.only) if args.force or need(paths, c, rows.get(c["id"])) == "generate"]
	if not work:
		print("nothing to draw")
		return 0
	api_key()
	failures = 0
	with locked(paths):
		for card in work:
			try:
				picture = generate_card(card, args.image_model, args.quality)
			except RuntimeError as err:
				print(f"FAIL {card['id']}: {err}")
				failures += 1
				continue
			replace_picture(paths, card["id"], picture)
			row = review_rows(paths).get(card["id"]) or new_row(card["id"])
			row.update(prompt_hash=sha(card["prompt"]), image_hash=sha(picture))
			save_row(paths, row, order)
			print(f"drew {card['id']}")
	return 1 if failures else 0


def cmd_fix(paths: Paths, args) -> int:
	cards = read_jsonl(paths.prompts)
	order = [c["id"] for c in cards]
	rows = review_rows(paths)
	work = []
	for card in chosen(cards, args.only):
		edits = pending_edits(rows.get(card["id"]))
		picture = paths.picture(card["id"])
		if not edits or not picture.exists():
			continue
		image = sha(picture.read_bytes())
		if not args.force and any(f.get("for_hash") != image for f in edits):
			print(f"skip {card['id']}: stale finding, written for an older picture (review it again)")
			continue
		work.append(card)
	if not work:
		print("nothing to fix")
		return 0
	api_key()
	failures = 0
	with locked(paths):
		for card in work:
			row = review_rows(paths)[card["id"]]  # as it is now, not when the run began
			edits = pending_edits(row)
			try:
				picture = fix_card(card, paths.picture(card["id"]), [f["fix"] for f in edits],
					args.image_model, args.quality)
			except RuntimeError as err:
				print(f"FAIL {card['id']}: {err}")
				failures += 1
				continue
			replace_picture(paths, card["id"], picture)
			for finding in edits:
				finding["done"] = True
			row.update(image_hash=sha(picture), edit_rounds=row.get("edit_rounds", 0) + 1)
			save_row(paths, row, order)
			print(f"fixed {card['id']}: {'; '.join(f['problem'] for f in edits)}")
	return 1 if failures else 0


def main(argv: list[str] | None = None, root: Path | None = None) -> int:
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	steps = parser.add_subparsers(dest="step", required=True)
	status = steps.add_parser("status", help="list the cards that need drawing, reviewing or fixing")
	generate = steps.add_parser("generate", help="draw cards whose prompt is new or changed")
	fix = steps.add_parser("fix", help="apply the pending edit findings in the review file")
	for step, quality in ((generate, "high"), (fix, "xhigh")):
		step.add_argument("--image-model", default=IMAGE_MODEL)
		step.add_argument("--quality", default=quality, choices=QUALITIES)
	generate.add_argument("--force", action="store_true", help="redraw the chosen cards even if nothing changed")
	fix.add_argument("--force", action="store_true", help="apply findings written for an older picture too")
	for step in (status, generate, fix):
		step.add_argument("--only", help="comma-separated card ids")
	args = parser.parse_args(argv)
	paths = Paths(root or Path(__file__).resolve().parent.parent)
	return {"status": cmd_status, "generate": cmd_generate, "fix": cmd_fix}[args.step](paths, args)


if __name__ == "__main__":
	sys.exit(main())
