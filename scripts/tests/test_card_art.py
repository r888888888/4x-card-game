"""Tests for scripts/card_art.py (397): which cards need drawing, reviewing or fixing, and the generate and fix runs.

Each test builds a temporary art folder (the prompt list, assets/cards/ and the review file) and replaces the HTTP call
with a fake that returns a PNG and records its requests, so nothing reaches the network and no key is needed.
"""

import base64
import contextlib
import hashlib
import io
import json
import os
import re
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import card_art  # noqa: E402

PNG = b"\x89PNG\r\n\x1a\n"


def sha(data: bytes | str) -> str:
	return hashlib.sha256(data.encode() if isinstance(data, str) else data).hexdigest()


class FakeApi:
	"""Stands in for card_art.request: records each call and answers with a new PNG."""

	def __init__(self, error: Exception | None = None):
		self.calls: list[tuple[str, bytes]] = []
		self.error = error

	def __call__(self, path: str, body: bytes, content_type: str) -> dict:
		self.calls.append((path, body))
		if self.error:
			raise self.error
		picture = PNG + f"drawn {len(self.calls)}".encode()
		return {"data": [{"b64_json": base64.b64encode(picture).decode()}]}

	def prompts(self) -> list[str]:
		return [json.loads(body)["prompt"] for path, body in self.calls if path == "images/generations"]


class CardArtCase(unittest.TestCase):
	def setUp(self):
		self.tmp = tempfile.TemporaryDirectory()
		self.root = Path(self.tmp.name)
		(self.root / "assets" / "cards").mkdir(parents=True)
		self.api = FakeApi()
		self.env = mock.patch.dict(os.environ, {"OPENAI_API_KEY": "test-key"})
		self.env.start()

	def tearDown(self):
		self.env.stop()
		self.tmp.cleanup()

	# Fixture helpers

	@property
	def assets(self) -> Path:
		return self.root / "assets"

	@property
	def history(self) -> Path:
		return self.assets / "card-art-history"

	@property
	def lock(self) -> Path:
		return self.assets / ".card-art.lock"

	def picture(self, card: str) -> Path:
		return self.assets / "cards" / f"{card}.png"

	def prompt(self, card: str) -> str:
		return f"A print of {card}."

	def write_prompts(self, cards: list[str]) -> None:
		rows = [{"id": c, "prompt": self.prompt(c)} for c in cards]
		(self.assets / "card-art-prompts.jsonl").write_text("".join(json.dumps(r) + "\n" for r in rows))

	def draw(self, card: str) -> bytes:
		data = PNG + f"old {card}".encode()
		self.picture(card).write_bytes(data)
		return data

	def write_review(self, rows: list[dict]) -> None:
		(self.assets / "card-art-review.jsonl").write_text("".join(json.dumps(r) + "\n" for r in rows))

	def review(self) -> dict[str, dict]:
		path = self.assets / "card-art-review.jsonl"
		return {r["id"]: r for r in map(json.loads, path.read_text().splitlines()) if r}

	def five_cards(self) -> None:
		"""AC1's cards: a needs drawing, b is approved, c needs review, d's prompt changed, e has a fix to make."""
		self.write_prompts(["a", "b", "c", "d", "e"])
		rows = []
		for card in ["b", "c", "d", "e"]:
			image = sha(self.draw(card))
			rows.append({"id": card, "prompt_hash": sha(self.prompt(card)), "image_hash": image,
				"approved_hash": image, "edit_rounds": 0, "findings": []})
		rows[1]["approved_hash"] = sha(b"an earlier picture")
		rows[2]["prompt_hash"] = sha("the prompt before it changed")
		rows[3]["approved_hash"] = ""
		rows[3]["findings"] = [{"problem": "the spear has two heads", "action": "edit",
			"fix": "On the spear at left, remove the upper head. Change nothing else.",
			"for_hash": rows[3]["image_hash"], "done": False}]
		self.write_review(rows)

	def run_script(self, *argv: str) -> tuple[int, str]:
		out = io.StringIO()
		code = 0
		with mock.patch.object(card_art, "request", self.api), \
				contextlib.redirect_stdout(out), contextlib.redirect_stderr(out):
			try:
				code = card_art.main(list(argv), root=self.root)
			except SystemExit as stop:
				if isinstance(stop.code, str):
					out.write(stop.code)
					code = 1
				else:
					code = stop.code or 0
		return code, out.getvalue()

	def status(self) -> dict[str, list[str]]:
		"""Runs status and reads its "<group>: id, id" lines; a group with no line is empty."""
		code, out = self.run_script("status")
		self.assertEqual(code, 0, out)
		groups = {"generate": [], "review": [], "fix": []}
		for group, ids in re.findall(r"^(generate|review|fix): (.*)$", out, re.MULTILINE):
			groups[group] = [i.strip() for i in ids.split(",") if i.strip()]
		return groups

	def history_files(self) -> list[str]:
		return sorted(p.name for p in self.history.glob("*.png")) if self.history.exists() else []


class StatusTest(CardArtCase):
	def test_status_lists_what_each_card_needs(self):
		self.five_cards()
		self.assertEqual(self.status(), {"generate": ["a", "d"], "review": ["c"], "fix": ["e"]})
		self.assertEqual(self.api.calls, [])


class GenerateTest(CardArtCase):
	def test_generate_draws_only_new_and_changed_prompts_and_keeps_the_old_picture(self):
		self.five_cards()
		code, out = self.run_script("generate")
		self.assertEqual(code, 0, out)
		self.assertEqual(sorted(self.api.prompts()), [self.prompt("a"), self.prompt("d")])
		self.assertEqual(len(self.history_files()), 1)
		self.assertRegex(self.history_files()[0], r"^d-\d{8}-\d{6}\.png$")
		review = self.review()
		for card in ["a", "d"]:
			self.assertEqual(review[card]["prompt_hash"], sha(self.prompt(card)))
			self.assertEqual(review[card]["image_hash"], sha(self.picture(card).read_bytes()))
		self.api.calls.clear()
		code, out = self.run_script("generate")
		self.assertEqual(code, 0, out)
		self.assertEqual(self.api.calls, [])

	def test_generate_force_redraws_and_keeps_the_old_picture(self):
		self.five_cards()
		old = self.picture("b").read_bytes()
		code, out = self.run_script("generate", "--force", "--only", "b")
		self.assertEqual(code, 0, out)
		self.assertEqual(self.api.prompts(), [self.prompt("b")])
		self.assertNotEqual(self.picture("b").read_bytes(), old)
		[kept] = self.history_files()
		self.assertTrue(kept.startswith("b-"))
		self.assertEqual((self.history / kept).read_bytes(), old)


class FixTest(CardArtCase):
	def test_fix_edits_the_picture_and_sends_it_back_to_review(self):
		self.five_cards()
		old = self.picture("e").read_bytes()
		code, out = self.run_script("fix")
		self.assertEqual(code, 0, out)
		[(path, body)] = self.api.calls
		self.assertEqual(path, "images/edits")
		self.assertIn(old, body)
		self.assertIn(b"On the spear at left, remove the upper head. Change nothing else.", body)
		[kept] = self.history_files()
		self.assertEqual((self.history / kept).read_bytes(), old)
		row = self.review()["e"]
		self.assertTrue(row["findings"][0]["done"])
		self.assertEqual(row["edit_rounds"], 1)
		self.assertEqual(row["image_hash"], sha(self.picture("e").read_bytes()))
		self.assertIn("e", self.status()["review"])

	def test_fix_skips_a_finding_written_for_an_older_picture(self):
		self.five_cards()
		review = self.review()
		review["e"]["findings"][0]["for_hash"] = sha(b"an earlier picture")
		self.write_review(list(review.values()))
		old = self.picture("e").read_bytes()
		code, out = self.run_script("fix")
		self.assertEqual(code, 0, out)
		self.assertRegex(out, r"(?m)^.*\be\b.*stale.*$")
		self.assertEqual(self.picture("e").read_bytes(), old)
		self.assertEqual(self.api.calls, [])


class LockTest(CardArtCase):
	def test_a_second_run_stops_while_the_lock_is_held(self):
		self.five_cards()
		self.lock.write_text("12345\n")
		before = (self.assets / "card-art-review.jsonl").read_text()
		for step in ["generate", "fix"]:
			code, out = self.run_script(step)
			self.assertNotEqual(code, 0, step)
			self.assertIn(".card-art.lock", out)
		self.assertEqual(self.api.calls, [])
		self.assertFalse(self.picture("a").exists())
		self.assertEqual((self.assets / "card-art-review.jsonl").read_text(), before)
		self.assertTrue(self.lock.exists(), "the other run's lock is left alone")

	def test_the_lock_is_released_when_a_run_ends(self):
		self.five_cards()
		code, out = self.run_script("generate")
		self.assertEqual(code, 0, out)
		self.assertFalse(self.lock.exists())
		self.api.error = RuntimeError("images/edits: HTTP 500")
		code, out = self.run_script("fix")
		self.assertNotEqual(code, 0, out)
		self.assertFalse(self.lock.exists())

	def test_the_lock_is_released_when_a_run_crashes(self):
		self.five_cards()
		self.api.error = ValueError("unexpected reply")
		with self.assertRaises(ValueError):
			with mock.patch.object(card_art, "request", self.api), contextlib.redirect_stdout(io.StringIO()):
				card_art.main(["generate"], root=self.root)
		self.assertFalse(self.lock.exists())


class KeyTest(CardArtCase):
	def test_status_needs_no_key_but_generate_and_fix_do(self):
		self.five_cards()
		del os.environ["OPENAI_API_KEY"]
		before = (self.assets / "card-art-review.jsonl").read_text()
		self.assertEqual(self.status()["generate"], ["a", "d"])
		for step in ["generate", "fix"]:
			code, out = self.run_script(step)
			self.assertNotEqual(code, 0, step)
			self.assertIn("Set OPENAI_API_KEY", out)
		self.assertFalse(self.picture("a").exists())
		self.assertEqual(self.history_files(), [])
		self.assertEqual((self.assets / "card-art-review.jsonl").read_text(), before)
		self.assertFalse(self.lock.exists())

	def test_generate_with_nothing_to_draw_needs_no_key(self):
		self.write_prompts([])
		del os.environ["OPENAI_API_KEY"]
		code, out = self.run_script("generate")
		self.assertEqual(code, 0, out)


class GptStepsGoneTest(CardArtCase):
	def test_revise_and_critique_are_not_commands(self):
		self.five_cards()
		for step in ["revise", "critique"]:
			code, _ = self.run_script(step)
			self.assertEqual(code, 2, step)

	def test_the_script_makes_no_text_model_call(self):
		source = Path(card_art.__file__).read_text()
		for text_model_use in ["chat/completions", "TEXT_MODEL"]:
			self.assertFalse(text_model_use in source, f"card_art.py still has {text_model_use}")


if __name__ == "__main__":
	unittest.main()
