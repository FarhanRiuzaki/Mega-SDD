# Living Vault — continuous-sync design (never-ending development)

Date: 2026-06-10 · Status: SHIPPED (all slices S1–S7; v4.13.0)

## 1. Problem

The pipeline is one-shot: `intent → scan → bind → units → bolts → done`. Real products never stop changing — hotfixes, manual edits, AI-prompted changes outside the pipeline. Today those changes silently rot every downstream artifact (codebase-map, binding, units, vault), and re-entry requires the user to *remember* to re-run full scans. `detect-drift` exists but is cold-start, full-repo, and explicitly refuses to update the vault.

Requirement (user, 2026-06-10): after development "completes" and the code moves on, the skills must continue from that state — detect what changed, update from the latest code, and keep the pipeline usable forever. Tech-agnostic, like everything else.

## 2. Design principles

1. **Ambient awareness** — the system notices change; the user doesn't have to remember. Never blocks normal work; awareness is an advisory channel.
2. **Incremental by reverse-index** — `binding.md` anchors (`file:line` per claim) and unit `target_files` are already a code→spec index. Invert it: changed file → affected claims → affected units. Re-process only what changed.
3. **Spec backflow with human sign-off** — code→vault is a first-class arrow. Accepted drift becomes a cited vault patch (git provenance: commit SHA, author, message). Never auto-applied.
4. **Two capture channels, union'd** — hooks see live in-session writes (even uncommitted); the `last_scanned_commit` stamp sees everything else (manual edits, git pull, other tools). `changed_paths = journal ∪ git diff`.
5. **The moat is untouched** — CONFLICT gate, citation discipline, no-fabrication all apply identically in sync mode.

## 3. Architecture

### 3.1 Change capture (slice S1)

**Dirty-paths journal** — `PostToolUse Write|Edit` (existing async hook): when the written path is inside a project that has `.mega-sdd/codebase/codebase-map.md` AND is not itself under `.mega-sdd/`, append one JSONL row to `.mega-sdd/codebase/.dirty-paths.jsonl`:

```json
{"ts":"<ISO8601>","path":"<repo-relative>","tool":"Write|Edit","session":"<id-prefix>"}
```

Best-effort, fail-silent, append-only (same discipline as telemetry). The journal is a HINT, never ground truth — consumers always union it with the git channel and de-dup.

**Git channel** — `git diff --name-only <last_scanned_commit>..HEAD` plus `git status --porcelain` for uncommitted work. Stamp absent / not a git repo → fall back to full scan.

**Ambient notice** — SessionStart (existing hook): when the journal is non-empty OR `HEAD ≠ last_scanned_commit`, emit ONE line of additional context: `mega-sdd: codebase moved since last scan (N journaled paths; map stamped at <short-sha>) — /mega-sdd:sync reconciles.` Counts only — no file lists, no token bloat.

### 3.2 Incremental re-scan (slice S2)

`scan-codebase --changed-only`: resolve `changed_paths` (union, de-dup, apply default excludes). Re-extract §2/§3/§4 entries ONLY for those paths (per-file sha256 invalidation already exists); carry forward unchanged entries; drop entries whose file vanished; refresh frontmatter (`generated_at`, `last_scanned_commit`); re-run Step 8.5 framework detection only when a manifest is in `changed_paths`. Deep-scan cache (per-slice lock digests) already handles its own invalidation. On successful write: truncate the journal (atomic rename). Fallbacks: no prior map / no stamp / not git → full scan with a one-line note.

### 3.3 Maintenance routing + front-door (slice S3)

**orchestrate-flow Mode D (maintenance)** — new CWD state in the decision matrix: map+binding (and usually bolts) exist AND change signal present (journal non-empty OR `HEAD ≠ last_scanned_commit`). Proposed chain:

```
scan-codebase --changed-only → detect-drift (scoped to changed paths) → [resolve-oq if drift walked]
  → bind-codebase (--paths; S4 claim-scoped) → generate-units (S6 reconcile) → execute-bolts (stale/new units only)
```

**`/mega-sdd:sync`** — user-facing command (parity rule: commands are CLI entry points; like `auto.md` it invokes the orchestrate-flow skill, with `--sync`). `--sync` = run Mode D regardless of other inference; `--dry-run` shows the proposed chain + change summary.

### 3.4 Claim-scoped re-bind (slice S4)

`bind-codebase --paths=<csv|@file>`: build the anchor reverse-index from the previous `binding.md` (file → claim IDs); re-verdict ONLY claims whose anchor files (or whose vault_source sections) intersect `changed_paths`; carry forward untouched verdicts with `provenance: carried_forward` + the prior bind timestamp. Untouched-claim carry-forward NEVER carries forward a CONFLICT silently — active CONFLICTs always re-surface. Full re-bind remains the default; `--paths` is the optimization.

### 3.5 Drift write-back (slice S5)

Extends detect-drift Step 5/6 (the historical report-only boundary is LIFTED by this spec, with guardrails):

- Walkthrough action `UPDATE_VAULT` → the skill DRAFTS the vault patch: the exact section edit, plus a provenance line `(synced from code: <commit short-sha> "<subject>" — <author>, <date>)` derived from `git log -1 --format` on the anchor file. Type/name drift → field edit; missing-in-vault → new subsection marked `[INTENT]`-pending; decision-unwritten → draft ADR stub with `status: proposed`.
- Patches are presented as a batch diff; applied ONLY on explicit user ACCEPT; then `00-index.md` changelog entry + vault version bump + `vault.json` regenerated under the advisory lock.
- `FIX_CODE` actions remain out-of-band (the skill never edits app source).

### 3.6 Unit lifecycle (slice S6)

Units gain `status: implemented | stale | superseded` (frontmatter, optional — absence = legacy). A unit is `stale` when any `target_files` entry's current content hash ≠ the hash snapshotted in its `bolt-report.md`. `generate-units --reconcile` re-reads the refreshed binding and UPDATES existing unit IDs in place (id-stability contract): task_type flips (e.g., `create → verify` when code now implements the claim; `verify → extend` on PARTIAL_FIELDS_*), Migration notes refreshed from the new field_diff, `status` recomputed. New claims → new units; vanished claims → unit marked `superseded`, never deleted. The dedupe gate (`dedup_ambiguous`) protects against duplication.

### 3.7 Autonomous sync (slice S7 — seamless/flawless)

`/mega-sdd:sync --auto` runs the WHOLE Mode D chain after ONE upfront confirmation (consistent with the established single-confirmation autonomy doctrine) and never asks a mid-chain question. The mechanism is **decision deferral**:

- **Safe operations run through**: incremental scan merge, claim-scoped re-bind, unit reconcile, stale/new bolt execution (bolts keep ALL their existing gates — Hard Rule pre/post-flight, target whitelist).
- **Human-required decisions are QUEUED, not blocking**: drift findings needing a direction call, write-back drafts, and any re-bind CONFLICTs are written to `<vault>/PENDING-SYNC.md` (one digest, prioritized). CONFLICTs still close the gate for affected downstream work (units/bolts halt per the moat) — but the chain completes every artifact it legally can and reports, instead of dying mid-flight.
- **`--auto-apply=safe` (opt-in, OFF by default)**: auto-applies ONLY the narrow write-back class — confidence HIGH + category ∈ {name-drift, type-drift, missing-in-vault} + claim NOT `[LOCKED]` + the code side is committed (git provenance available). Every auto-applied patch carries its provenance line and is listed in the report; one vault version bump per run. Everything outside the class queues as usual. Plain `--auto` queues ALL write-backs (human sign-off preserved).
- **End-of-run `SYNC-REPORT.md`** (vault root, overwrite): change summary (journal/git counts), per-phase outcomes, patches applied (with provenance) vs queued, conflicts raised, units reconciled/re-executed, and a closing staleness verification — re-run `compute-unit-staleness.sh`; report MUST state whether stale count reached 0 (flawless check; non-zero = explained, e.g., blocked by a queued CONFLICT).

**Seamless entry** — the `using-mega-sdd` anchor treats "map+binding present + change signal present" as a strong CWD signal: a continuation prompt ("lanjut", "continue") proposes `/mega-sdd:sync --auto` with the one upfront confirmation.

**Flawless journal handling (race-safe consume)** — consumers never truncate in place: rotate `mv .dirty-paths.jsonl .dirty-paths.consumed-<ts>` FIRST, process the rotated file, delete it after the map write succeeds (appends landing mid-sync go to a fresh journal and survive for the next run). The hook stops appending when the journal exceeds 1 MB (runaway guard; the git channel still covers everything, and the >40% rule forces a full scan anyway). Leftover `.consumed-*` files (crashed sync) are re-unioned on the next run, then cleaned.

## 4. Invariants & non-goals

- The binding CONFLICT gate, citation rails, and halt taxonomy apply unchanged in sync mode.
- The journal/notice layer is advisory-only — no new blocking hooks (gates > rules > hooks doctrine; the hot-path PreToolUse surface does not grow).
- Tech-agnostic: change capture is path/git-based; nothing framework-specific. All ecosystems benefit identically.
- Non-goal: file-system watchers/daemons (out of Claude Code's execution model); CI integration (future).

## 5. Test obligations

- `tests/hooks/` — journal append fires on mapped-repo source write; does NOT fire for `.mega-sdd/**` writes or unmapped repos; fail-silent when journal unwritable.
- `tests/skill-triggering/sync.test.md` — "/mega-sdd:sync", "code berubah manual, lanjutin", "continue from current code", near-misses (fresh repo → not sync).
- Scenario: post-bolt manual edit → sync proposes Mode D chain; `--changed-only` map merge preserves untouched entries byte-identical.
