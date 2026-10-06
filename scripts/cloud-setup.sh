#!/usr/bin/env bash
# Installs the pinned Godot on a Linux container (x86_64 or arm64) so scripts/test.sh and scripts/sim.sh run in a
# Claude Code cloud session (317; docs/cloud.md). Usage: scripts/cloud-setup.sh
# Installs to $GODOT_HOME/godot (default ~/.local/bin) and does nothing when that binary already reports the pinned
# version. The archive must match the SHA-512 pinned here (from the release's SHA512-SUMS.txt); otherwise nothing is
# installed and it exits 1. Downloads from the GitHub release, else (a cloud session's GitHub proxy refuses release
# assets of repositories not attached to the session) from Godot's own release storage, the host
# downloads.godotengine.org redirects to; GODOT_URL sets one download base instead.
set -euo pipefail

VERSION="4.7.2-stable"
VERSION_OUTPUT="4.7.2.stable.official"
case "$(uname -m)" in
	x86_64 | amd64)
		archive="Godot_v${VERSION}_linux.x86_64.zip"
		sha512="9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65"
		;;
	aarch64 | arm64)
		archive="Godot_v${VERSION}_linux.arm64.zip"
		sha512="dd59918da086bd49bde2f5450b5e567ff8650cbde9abbd7b8f4ca1197ff8c609baa38834666d032deafb47099078d7822279e2a0e06e5665745468f26533e7e2"
		;;
	*) echo "cloud-setup.sh: no Godot build for $(uname -m)" >&2; exit 1 ;;
esac

home="${GODOT_HOME:-$HOME/.local/bin}"
bin="$home/godot"
if [[ -x "$bin" ]] && [[ "$("$bin" --headless --version 2>/dev/null)" == "$VERSION_OUTPUT"* ]]; then
	echo "Godot $VERSION already installed at $bin"
	exit 0
fi

if [[ -n "${GODOT_URL:-}" ]]; then
	bases=("$GODOT_URL")
else
	bases=("https://github.com/godotengine/godot/releases/download/$VERSION"
		"https://godot-releases.nbg1.your-objectstorage.com/$VERSION")
fi
work="$(mktemp -d "${TMPDIR:-/tmp}/godot-setup.XXXXXX")"
trap 'rm -rf "$work"' EXIT

base=""
for candidate in "${bases[@]}"; do
	echo "Downloading $candidate/$archive"
	if curl -fsSL --retry 3 -o "$work/$archive" "$candidate/$archive"; then
		base="$candidate"
		break
	fi
done
[[ -n "$base" ]] || { echo "cloud-setup.sh: could not download $archive from ${bases[*]}" >&2; exit 1; }
actual="$(sha512sum "$work/$archive" 2>/dev/null || shasum -a 512 "$work/$archive")"
actual="${actual%% *}"
if [[ "$actual" != "$sha512" ]]; then
	echo "cloud-setup.sh: checksum mismatch for $archive from $base" >&2
	echo "  expected SHA-512 $sha512" >&2
	echo "  got      SHA-512 $actual" >&2
	exit 1
fi

if command -v unzip >/dev/null; then
	unzip -q -o "$work/$archive" -d "$work/x"
else
	python3 -c 'import sys, zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' "$work/$archive" "$work/x"
fi
mkdir -p "$home"
install -m 755 "$work/x/${archive%.zip}" "$bin"
reported="$("$bin" --headless --version 2>&1 || true)"
if [[ "$reported" != "$VERSION_OUTPUT"* ]]; then
	echo "cloud-setup.sh: $bin reports '$reported', not $VERSION_OUTPUT" >&2
	exit 1
fi
echo "Installed Godot $reported at $bin"
case ":$PATH:" in
	*":$home:"*) ;;
	*) echo "Add $home to PATH (export PATH=\"$home:\$PATH\") so scripts/test.sh finds godot." ;;
esac
