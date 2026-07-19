---
description: "DEPRECATED — folded into /mega-sdd; alias resolves through 5.x"
argument-hint: <unit-id> [--vault=<path>] [--capture-only] [--diff-against=<replay-id>] [--format=table|json]
---

> ⚠️ **DEPRECATED (5.x alias)** — cetak dulu SATU baris keterangan ini ke user sebelum melakukan apa pun: "Perintah `/mega-sdd:replay` sudah dilebur ke `/mega-sdd` — alias ini tetap berfungsi selama siklus 5.x; ke depannya cukup pakai `/mega-sdd`." Setelah itu jalankan persis seperti sebelumnya — flags diteruskan tanpa perubahan.

Replay + divergence detection for `execute-bolts` outcomes. Grounded in IBM DFAH (2026) + LangGraph time-travel, which validate replay as a missing primitive for agentic-dev debugging.

User arguments: $ARGUMENTS

The whole deterministic loop — capture a snapshot, select the latest prior, diff, classify by the fixed severity table, render — is a single script: `plugins/mega-sdd/scripts/replay.sh`. This command runs it and turns the verdict into the hand-off recommendation.

## Procedure

### Step 1 — Run replay

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/replay.sh" $ARGUMENTS --cwd="$(pwd)"
```

`<unit-id>` is the required positional (e.g. `U-001`). The script resolves the vault (`--vault=<path>`, else auto-probe `.mega-sdd/vaults/` then legacy), validates the unit, captures the snapshot, and (unless `--capture-only`) diffs against the latest prior. Relay its output.

### Step 2 — What the snapshot actually records (grounding — moat invariant #5)

The script sources snapshot fields **only** from artifacts `execute-bolts` actually writes — it never fabricates:

- `<vault>/bolts/<unit>/bolt-report.md` frontmatter → `status:` + `target_hashes:` (the recorded per-file sha256).
- the **live** sha256 of each `target_hashes` path, recomputed every run (this is the primary regression signal).
- `<vault>/bolts/<unit>/postflight.json` → `status` + `rules[].{type,path,verdict,evidence}`.
- `<vault>/bolts/<unit>/preflight.json` → `rules[]`.
- `halt` (populated iff the bolt-report shows a `halted_*` status).

Fields a richer execute-bolts *could* record but **no current artifact does** — `test_exit_code`, `test_duration_ms`, `git_sha_before/after`, `lines_changed` — are **not** invented. They are captured **if present** and compared **only when present on both** snapshots. Cosmetic keys (`captured_at` timestamps) are excluded from the diff entirely.

Each run persists one snapshot to `<vault>/.internal/replays/<unit>-<timestamp>Z-<pid>.json` — a **per-run file** (the timestamp+PID stem makes concurrent runs collision-free). It is **not** a JSON-Lines append log; "latest prior" is the newest such snapshot file, excluding the `<unit>-divergence.json` diff artifact.

### Step 3 — Severity table (what the script classifies on)

The classification is deterministic — a fixed table, no LLM judgment. The signals are the fields that **exist**:

| Divergence | Severity | Exit |
|---|---|---|
| A `target_files.<path>` live sha differs on the same path (or the target set changes) | 🔴 HIGH | 1 — regression: code differs |
| `postflight_status` changed (e.g. `pass -> fail`) | 🔴 HIGH | 1 — rail outcome changed |
| A `hard_rule[<path>].verdict` changed (e.g. `pass -> fail`) | 🔴 HIGH | 1 — rail change |
| `halt` flips null ↔ populated | 🔴 HIGH | 1 — pipeline behavior changed |
| Prior snapshot unreadable/corrupt | 🔴 HIGH | 1 — cannot confirm reproducibility |
| `test_exit_code` / `test_duration_ms` change **(only when present on both)** | 🔴 HIGH / 🟡 MED | 1 / 0 |
| Cosmetic (timestamps only) | 🟢 LOW | 0 — ignored |

Any HIGH → exit **1** (serves the CI use-case). Otherwise exit **0**.

### Step 4 — Render (what the script prints)

`--format=table` (default), e.g. a clean re-run:

```
Replay analysis: U-001
  [no divergence]
     - target_files.src/Thing.php (sha unchanged)
     - postflight_status (pass)
     - hard_rules_validated (1 rule(s) unchanged)
  [HIGH] none.

Verdict: REPRODUCIBLE
```

…and a regression cites the exact fields under `[HIGH]` and prints `Verdict: REGRESSION`. `--format=json` emits the same as a structured object.

### Step 5 — Hand-off

| Outcome | Suggested action |
|---|---|
| Baseline (no prior) | "Snapshot captured — re-run after the next bolt to compare." |
| REPRODUCIBLE (no/low divergence) | "Bolt reproducible — no action needed." |
| HIGH (REGRESSION) | "Regression detected — inspect `<vault>/.internal/replays/<unit>-divergence.json` (the always-written diff record; a `<unit>-divergence.patch` is also written when `jd` is installed), then revert OR re-investigate the unit." |

## Common pitfalls

- **No prior snapshot** — first run is a baseline (exit 0); re-run after the next bolt to diff.
- **`--capture-only`** — snapshot only, diff skipped (exit 0). Useful to establish a baseline before a refactor.
- **`--diff-against=<stem>`** — diff against a specific historical snapshot basename stem (not just the latest prior).
- **Halted bolt** — if `bolt-report.md` shows `status: halted_*`, the snapshot still captures (with `halt` populated); diffing against a prior successful run still pinpoints what changed.

## Anti-halu rails

- Replay is **READ-ONLY** — it never modifies code, vault, or memory (it only writes snapshot/divergence artifacts under `<vault>/.internal/replays/`).
- Diff classification is **DETERMINISTIC** (the fixed table above; no LLM judgment).
- Snapshots are **per-run JSON files** (timestamp+PID stem), not a JSON-Lines append log.
- Snapshot fields come **only** from real artifacts; aspirational fields are compared only when present on both runs — never fabricated (moat invariant #5).
- Cosmetic-only divergence (timestamps) is excluded from classification; every HIGH cites the specific field(s) + values that differ.

## References

- `plugins/mega-sdd/scripts/replay.sh` — the deterministic capture+diff core (covered by `tests/replay/test-replay.sh`)
- `plugins/mega-sdd/skills/execute-bolts/SKILL.md` — the `bolt-report.md` + `preflight.json` + `postflight.json` producers
- `jd` — optional; used for the canonical `<unit>-divergence.patch` when installed
