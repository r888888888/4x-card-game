---
id: 317
title: Run the test suite and the balance sim in a Claude Code cloud session
type: feature
status: done
branch: feat/317-cloud-sim
---

## Goal
A developer can run `scripts/test.sh`, `scripts/test.sh --balance` and `scripts/sim.sh` (including `--compare`) in a
Claude Code cloud session (claude.ai/code, or a scheduled cloud agent) instead of on the Mac, so long sims can run
unattended or on a schedule without holding the desktop's cores. Today the cloud container has no Godot, and nothing
documents how to set one up.

## Acceptance criteria
- [ ] AC1: Given a Linux container (x86_64 or arm64) with no `godot` on `PATH`, when `scripts/cloud-setup.sh` runs,
  then it exits 0 and `godot --version` afterwards prints `4.7.2.stable.official` (the version the Mac uses).
- [ ] AC2: Given Godot 4.7.2 already installed by an earlier run, when `scripts/cloud-setup.sh` runs again, then it
  downloads nothing and exits 0 within 5 s.
- [x] AC3: Given the downloaded archive's checksum doesn't match the one pinned in the script, when
  `scripts/cloud-setup.sh` runs, then it exits non-zero, installs nothing, and its error names the file and both
  checksums.
- [ ] AC4: Given a cloud session on `main` after `scripts/cloud-setup.sh`, when `scripts/test.sh` runs, then it exits
  0. When `scripts/sim.sh 5` runs, it exits 0 and prints a block per strategy.
- [ ] AC5: Given a cloud session as in AC4, when `scripts/test.sh --balance` runs, then it exits 0.
- [ ] AC6: Given a cloud session as in AC4 with a second checkout of `main` made with `git worktree add`, when
  `scripts/sim.sh --compare <that checkout> 5` runs, then it exits 0 and prints the per-cell comparison.
- [x] AC7: `docs/cloud.md` (linked from `CLAUDE.md`'s Commands) says how to: hook `scripts/cloud-setup.sh` into the
  cloud environment's setup script, allow its download host in the environment's network settings, push `main` first
  (the cloud clones from GitHub), make the `--compare` checkout, and expect a cold cache (every game is played from
  scratch in a new container).
- [x] AC8: Given Linux with 64 CPUs online, 8 in the process's affinity mask (`nproc` = 8) and a cgroup v2 quota of
  `400000 100000` in `cpu.max` (4 CPUs), when `scripts/sim.sh` starts, then it runs 4 workers. With `cpu.max` =
  `max 100000` it runs 8, and with no `cpu.max` file it also runs 8. `scripts/test.sh` uses the same count for its shards.
  Linux gets every allowed CPU, not every one but one, because a container has no desktop to keep responsive. On macOS
  the counts are unchanged (performance cores but one for the sim, `hw.ncpu` for the tests).
- [x] AC9: Given `SIM_PROCS=2` (or `TEST_JOBS=2`), when either script runs on Linux under any quota, then it uses 2.

## Out of scope
- Creating a scheduled cloud agent (routine) that runs sims on a timer: the developer sets one up with `/schedule`
  once this works.
- Making the sim cache survive between containers (for example committing or uploading it).
- Changing `engine/`, `sim/` rules or the bot. This is tooling and docs only.
- Pushing `main`. That's the user's call (local `main` was 116 commits ahead of `origin/main` when this was written).

## Design notes
- `scripts/cloud-setup.sh`: pins the version (4.7.2-stable) and the SHA-512 of each Linux archive
  (`Godot_v4.7.2-stable_linux.x86_64.zip`, `..._linux.arm64.zip`) from Godot's GitHub release; picks the archive by
  `uname -m`; installs to `~/.local/bin/godot` (or `$GODOT_HOME` if set) and exits 0 early when that binary already
  reports the pinned version. `GODOT_URL` overrides the download base, so AC3 can be checked locally with a
  deliberately bad file.
- CPU count (AC8): Godot's `OS.get_processor_count()` reports the CPUs configured on the machine. It ignores the
  container's affinity mask and CPU quota, so on a big shared host it can start far more workers than the container
  may run, which is slower and can run out of memory. A shared `scripts/cpus.sh` prints the usable count:
  - On Linux, `nproc` capped by `ceil(quota / period)` from cgroup v2 `cpu.max`. The path can be overridden with
    `CGROUP_CPU_MAX`, so AC8 can be checked locally with fake files.
  - On macOS, what each script uses today.

  `sim.sh` passes the Linux count as `SIM_PERF_CORES` plus one, so the existing "minus one" in `procs_from_env` leaves
  exactly that many workers and the sim's GDScript doesn't change. `test.sh` uses the count directly for its shards.
- `scripts/sim.sh` and `scripts/test.sh` otherwise already run on Linux: `sysctl` fails quietly, `test.sh` uses `nproc`,
  and the sim lock (`OS.get_temp_dir()`), `kill -0` liveness check and `user://` cache are portable. AC4 and AC6
  confirm this. If they don't, fix it in this item.
- Verification: AC1, AC2, AC4, AC5 and AC6 run in a cloud session, and the results go in the Log. AC3 also runs
  locally with `GODOT_URL` pointed at a bad file. AC8 and AC9 run locally too, with fake `cpu.max` files and a
  stubbed `nproc`, each script printing its count. Nothing changes in `engine/`, `autoload/` or the loader, so the
  GDScript suite gets no new tests.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
Shell tooling only (nothing in `engine/`, `autoload/` or the loader), so no GDScript tests, per the Design notes.
Each AC is a scripted check, run locally where it can be and in the first cloud session otherwise.

| AC | Check | Where | Result |
|---|---|---|---|
| AC1 | `scripts/cloud-setup.sh; godot --version` | cloud | pending (needs `main` pushed) |
| AC2 | run `scripts/cloud-setup.sh` again, timed | cloud; locally with a stub binary reporting 4.7.2 | local: 0.4 s, no download |
| AC3 | `GODOT_URL=file://<dir with a junk zip> GODOT_HOME=<tmp>` | local | exit 1, names file, expected and actual SHA-512, `<tmp>` not created |
| AC4 | `scripts/test.sh`, `scripts/sim.sh 5` | cloud | pending |
| AC5 | `scripts/test.sh --balance` | cloud | pending |
| AC6 | `git worktree add --detach ../main-checkout main; scripts/sim.sh --compare ../main-checkout 5` | cloud | pending |
| AC7 | `docs/cloud.md`, linked from `CLAUDE.md` Commands | review | written |
| AC8 | stub `uname` (Linux) and `nproc` (8) on PATH, fake `CGROUP_CPU_MAX`, stub `GODOT` printing `SIM_PERF_CORES` and each shard | local | `400000 100000`: 4 workers (SIM_PERF_CORES=5), 4 shards; `max 100000`: 8/8; no file: 8/8; macOS unchanged (perf cores 8, 12 shards) |
| AC9 | as AC8 with `SIM_PROCS=2` / `TEST_JOBS=2` | local | SIM_PROCS passes through (procs_from_env, tested), 2 shards |

## Manual check
- [ ] From a scheduled cloud agent (not just an interactive cloud session), `scripts/sim.sh 5` finishes and its output
  reaches the agent's report.
- [ ] In the first cloud session, record `nproc`, the contents of `/sys/fs/cgroup/cpu.max`, Godot's processor count, the
  container's memory limit and one sim worker's peak memory. If workers times peak memory comes near the limit, spec
  a follow-up that caps workers by memory.
- [ ] Compare wall time for `scripts/sim.sh 20` in the cloud against the Mac with a cold cache (`SIM_CACHE=0`), and
  note it in the Log so we know when the cloud is worth using.

## Log
- 2026-10-05: Specced from a question about running the sim bot remotely.
- 2026-10-05: Built `scripts/cloud-setup.sh`, `scripts/cpus.sh`, `docs/cloud.md`; `sim.sh` and `test.sh` take the
  Linux count from `cpus.sh`. Pinned SHA-512s come from the release's SHA512-SUMS.txt; the arm64 and x86_64 downloads
  were hashed and match.
- 2026-10-05: Deviation from the Design notes: the cloud docs say the GitHub proxy refuses release assets of
  repositories not attached to the session (403), which `godotengine/godot` would be. So the script tries GitHub, then
  Godot's own release storage (`godot-releases.nbg1.your-objectstorage.com`, where `downloads.godotengine.org`
  redirects; its x86_64 archive hashes the same). `docs/cloud.md` says to allow that host (Custom access). It also
  checks the installed binary reports the pinned version and exits 1 otherwise.
- 2026-10-05: The cloud docs give the VM as Ubuntu 24.04 x86_64 with about 4 vCPUs and 16 GB, so `cpus.sh` matters
  less there than on a big shared host, but the quota check is cheap.
- Open: AC1, AC2 (cloud), AC4–AC6 need a cloud session on a pushed `main`. The setup script's working directory isn't
  documented, so `docs/cloud.md`'s setup script finds `scripts/cloud-setup.sh` with `find`; confirm in the first
  session. Pitfall seen locally: running either script with a stub `GODOT` stamps `.godot/.test-import-stamp`
  without importing; delete the stamp afterwards.
- 2026-10-05: Follow-up (not caused by 317; on macOS its code is a no-op): a cold `scripts/sim.sh 1` on the Mac ran its
  7 workers, 17 of 18 games finished within 4 minutes, but worker 3 was still on job 10 (seed 1, wide, Phoenicia) 19
  minutes later, with the parent waiting on it. That game alone (`SIM_PROCS=1 SIM_CACHE=0 scripts/sim.sh 1 wide --civ
  phoenicia`) takes 2 minutes. A worker that stalls (or dies) hangs the whole run, which an unattended cloud run can't
  recover from.
