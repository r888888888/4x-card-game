# Running the tests and the sim in a Claude Code cloud session

A cloud session (claude.ai/code, or a scheduled cloud agent made with `/schedule`) can run `scripts/test.sh`,
`scripts/test.sh --balance` and `scripts/sim.sh`, so a long sim runs unattended without holding the Mac's cores (317).
The cloud VM is Ubuntu on x86_64 with no Godot, so the environment installs it once with `scripts/cloud-setup.sh`.

## 1. Push `main` first

A cloud session starts from a fresh clone from GitHub: it sees only what's pushed. Push `main` (and any branch you
want simmed) before starting the session; local-only commits aren't there.

## 2. Configure the cloud environment

At claude.ai/code, open the environment selector, hover over the environment and select its settings icon.

**Setup script.** It runs as root before Claude Code launches, and its result is cached (about a week, or until you
change the script or the network settings), so later sessions start with Godot already installed:

```bash
#!/bin/bash
# Install the pinned Godot (scripts/cloud-setup.sh) on PATH for every session.
script="$(find / -path /proc -prune -o -path '*/4x-card-game/scripts/cloud-setup.sh' -print -quit 2>/dev/null)"
GODOT_HOME=/usr/local/bin bash "$script"
```

The script checks the archive against the SHA-512 pinned in it and exits non-zero (failing the session start) when
the download or the check fails, so a broken setup is loud rather than a session with no Godot. Run again, it sees
the installed version and downloads nothing.

**Network access.** The script downloads the Godot release from GitHub first. The cloud's GitHub proxy refuses release
assets of repositories not attached to the session (`godotengine/godot` isn't), so it then falls back to Godot's own
release storage, `godot-releases.nbg1.your-objectstorage.com` (where `downloads.godotengine.org` redirects). That
host isn't on the default **Trusted** list: set the access level to **Custom**, keep the default domains, and add
`godot-releases.nbg1.your-objectstorage.com`.

**Timeouts.** A cold `scripts/sim.sh 20` can outlast the default command timeout. Add environment variables such as
`BASH_DEFAULT_TIMEOUT_MS=600000` and `BASH_MAX_TIMEOUT_MS=3600000`, or ask Claude to run the sim in the background.
A parallel sim never waits forever on a worker: one that finishes no turn for 10 minutes (`SIM_STALL_SEC` sets it) is
stopped and the run exits 1 naming its game and turn, and while it waits the run prints a progress line to stderr each
minute (318), so the log shows which game is the long one.

## 3. Run

In the session, ask Claude to run the usual commands:

```bash
scripts/test.sh
```

```bash
scripts/sim.sh 20
```

On Linux both scripts size their workers with `scripts/cpus.sh`: every CPU the container may use (its affinity mask
capped by the cgroup `cpu.max` quota), since there is no desktop to keep responsive. Godot itself sees the host's
CPUs, which can be far more. `SIM_PROCS` and `TEST_JOBS` still override.

### Comparing with `main`

`--compare` needs a second checkout of `main`. Make one with a worktree (`--detach` works even when the session is on
`main`), then compare from the branch under test:

```bash
git worktree add --detach ../main-checkout main
```

```bash
scripts/sim.sh --compare ../main-checkout 20
```

## Expect a cold cache

Every cloud session is a new container, and the sim's game cache lives in Godot's `user://` (292), which isn't in
the environment snapshot. Every game is played from scratch, both sides of a `--compare` included, so a cloud run
takes as long as a local run with `SIM_CACHE=0`.
