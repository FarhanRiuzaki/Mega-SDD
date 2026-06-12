# Bolt-Folder Creation Hardening (loud detection + strengthened creation) — Bugfix Design

**Status:** implemented (v4.11.0)
**Reported:** user ran `execute-bolts` via `orchestrate-flow --auto`; code was committed but no `<vault>/bolts/U-XXX/` folder + `bolt-report.md` were generated.

## Root cause

Bolt-folder creation was **prose-only**, with no deterministic creation and no end-of-run existence gate — a direct violation of the plugin's own doctrine ("a blocking gate is a deterministic validator wired to a hook; prose that says HALT enforces nothing").

- The `bolt-implementer` **agent** writes target files + acceptance test + commit — it never writes into `<vault>/bolts/U-XXX/` (that's why the code landed).
- The **controller** (the model running execute-bolts) was instructed — in prose only — to write `dispatch-prompt.md` (`context-enrichment.md` "Log final prompt") and `bolt-report.md` (`superpowers-bridge.md`) into the bolt folder. There was **no `mkdir`** anywhere; the folder only materialized if a Write auto-created its parents.
- Under `--auto` the controller runs terse/non-interactive, committed the code via the agent, and moved on without writing the folder artifacts → folder silently absent.
- Enforcement gap: `validate-bolt-artifacts.sh` only validates a file's content *if one is written* (detection-only). `validate-handoff-yaml.sh`'s `artifact_missing` check only verifies that *declared* `artifacts:` paths exist — it passes **vacuously** when the controller declares none.

## Fix (two layers — strengthened creation + deterministic enforcement)

Per the plugin's own doctrine (*gates > rules > hooks*), the creation step alone cannot **enforce** anything — it is prose the controller runs. So Layer 1 strengthens the creation step and Layer 2 is the deterministic, hook-wired gate that actually catches a skip.

1. **Strengthened creation step (prose — controller-run).** `execute-bolts` SKILL.md gains a per-unit **Procedure Step 0**: `mkdir -p <vault>/bolts/U-XXX/` as the literal first action, *before* pre-flight/dispatch — so the folder exists even for empty-Hard-rules units, `verify` units, early halts, and `--auto`/`--parallel`. `context-enrichment.md` also `mkdir -p`s before writing the dispatch-prompt (idempotent belt-and-suspenders). The bolt folder + `bolt-report.md` are declared MANDATORY per-unit outputs. This is still an instruction to the controller, not a guarantee — Layer 2 is what makes the skip loud.

2. **Deterministic enforcement (hook-wired — the real gate).** `validate-handoff-yaml.sh` (run by the Stop hook on every `handoff:`-bearing response) gains a new halt **`bolt_artifacts_missing`**: an `emitted_by: execute-bolts` `status: completed` handoff that **executed units** (`metrics.items_processed > 0`) but lists **no** `bolts/` artifact now FAILS. Scoped tightly to avoid false positives — only `execute-bolts`, only `completed` (a `halted` pre-flight run legitimately produces nothing), only when units were actually executed (a `--dry-run` or an "all units already done" no-op re-run completes with `items_processed == 0` and is exempt; an absent/unparseable metrics block stays conservative and does NOT fire), and only when the existing `artifact_missing` check has already passed (so it never masks a genuine missing-path failure). Registered in the halt taxonomy (`halts-and-handoff.md`, `handoff-contract.md`).

## Acceptance

- `execute-bolts/SKILL.md` contains the mandatory `mkdir -p <vault>/bolts/U-XXX/` Procedure Step 0 and references the `bolt_artifacts_missing` gate.
- `validate-handoff-yaml.sh` raises `bolt_artifacts_missing` for a `completed` execute-bolts handoff that executed units (`metrics.items_processed > 0`) with no `bolts/` artifact, and does NOT raise it when a real `bolts/U-XXX/` path is listed, when `items_processed == 0` (dry-run / no-op re-run), or when the metrics block is absent.
- No existing handoff fixture (code-delivery handoff-types, iter77 range-shorthand) regresses — verified: none has an execute-bolts `completed` handoff that executed units yet lacks a bolts artifact.
- Gate suite `tests/bolt-folder-fix/` green; all prior suites green; versions consistent (plugin 4.11.0, execute-bolts 2.5.0, orchestrate-flow 2.1.1).

## Notes / caveats

- The reporter's installed plugin was a stale older 4.x/3.x cache, but the gap was verified present in current `main`, so this is a genuine long-standing fix (not resolved by an update alone).
- Layer 2 (`bolt_artifacts_missing`) only fires in `--auto`/handoff-emitting runs (the path the user hit). Interactive runs rely on Layer 1 (the mandatory `mkdir` step) + the MANDATORY-output prose. A future hardening could add a non-`--auto` end-of-run check, but that needs a non-handoff trigger and is out of scope here.
- The gate keys off `metrics.items_processed` as the work-evidence signal. The no-deps YAML parser hands `metrics` back as either a real dict (block style, values may carry an inline `# comment`) or an inline-flow string; the `_items_processed` helper tolerates both and extracts the integer, returning `None` (→ does not fire) when undeterminable. This deliberately trades a possible false-negative (a completed run that omits metrics entirely) for zero false-positives, per the doctrine that a spurious C2 halt is worse than a missed advisory. (We considered also *requiring* `items_processed` on completed execute-bolts handoffs to close the hole unconditionally, but rejected it: a combined `--auto --dry-run` preview or a no-op re-run could legitimately omit/under-report metrics, and forcing a halt there would reintroduce the very C2 false-positive this revision exists to remove.)
- **Dry-run is not a real false-positive path** (resolves the review's first concern with evidence, not assumption): the handoff YAML is emitted only under `--auto` (execute-bolts SKILL.md), and `--dry-run` is a separate "walk steps, do not commit" preview. The only way a preview reaches the gate is a combined `--auto --dry-run`, and the handoff contract now mandates `items_processed: 0` for any dry-run/preview or no-op re-run (units *actually* committed, never the would-process count) — so the exemption is contract-grounded, not inferred. `handoff-contract.md` and execute-bolts `halts-and-handoff.md` both carry this requirement.
