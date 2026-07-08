# Instincts + GateGuard — ECC-adoption Batch 1

**Date:** 2026-06-12 · **Research:** ECC review (affaan-m/everything-claude-code, session 2026-06-12)
**Scope:** (A) instinct layer — confidence-scored atomic learnings with bounded session-start re-injection; (B) GateGuard — deny→force→allow investigation gate on LOCKED-anchored files.

## A. Instincts (closes the learning loop)

mega-sdd's learning loop ends at `patterns.md ## Pending suggestions` — learnings accumulate but never re-enter context automatically. ECC's contribution is the missing half: schema + re-injection.

- **Schema** (`skills/memory/references/instincts.md`): one YAML file per instinct under `<scope>/memory/instincts/` — `trigger`, `action`, `confidence` 0.3–0.9, `domain`, `scope`, `evidence[]`, `status`. Atomic: one trigger, one action.
- **Lifecycle** (owned by the existing chain-end pass, learning-rules §1 — no new mid-chain evaluation): birth at 0.5 from a threshold-crossing observation class; +0.1 per reconfirmation (cap 0.9); −0.2 on explicit user correction; −0.1 staleness when unconfirmed >30 days; <0.3 → `status: retired`.
- **Promotion** project→global: chain-end appends `(project_hash, key, confidence)` to `~/.mega-sdd/memory/instincts/_seen.jsonl`; same key from ≥2 projects with avg confidence ≥0.8 → copied to user scope.
- **Re-injection (the point):** SessionStart hook appends a `<learned-instincts>` block — top 6 by confidence (≥0.7), project scope before global, hard char budget 1200, config opt-out `instincts: false`. Bolt T2: matching-domain instincts ride the existing historical-memory slice.

## B. GateGuard (rule → gate, one level deeper)

ECC's strongest mechanism: PreToolUse **blocks the FIRST Edit/Write and prescribes the exact investigation whose output becomes the unlock**; the retry passes. Rationale (ECC, empirically argued): self-evaluation fails, but forcing "list every file that imports this module" makes the model run Grep/Read — the investigation itself changes the output.

mega-sdd fit: files anchored to **[LOCKED]** claims. Today a LOCKED violation is caught AFTER the fact (bolt post-flight drift check, sync triage). GateGuard prevents the blind edit BEFORE it happens — including manual/out-of-pipeline edits the bolt rails never see.

- **Index** (`scripts/build-locked-index.sh`): parses `vaults/*/binding.md` + bound/vault docs for `[LOCKED]` markers + their file anchors → `.mega-sdd/.locked-files-index.json` (file → claim refs). Rebuilt lazily by the hook when older than the newest binding.md. No `[LOCKED]` anywhere (typical greenfield) → empty index → gate inert, zero false positives.
- **Gate** (pre-tool-use, new `Edit|Write|MultiEdit` branch; hooks.json matcher widened): target file in index AND not yet investigated this session → deny ONCE with the prescribed facts (read the claim + binding verdict; Grep the file's importers; name the covering acceptance test; route real behavior changes through sync/propose-and-confirm) → the retry is allowed. Session state `.mega-sdd/.gateguard-state.json`: per-session entries, 30-min expiry, 500-entry cap. *(Amendment 2026-07-06, token-efficiency B2/M-07: the 30-min expiry is dropped — dedup is session-LIFETIME (session_id key + 500-entry LRU). A >30-min bolts run re-denied the SAME file and re-forced an investigation the session already performed (~1–3K tok each); first-touch-per-file-per-session still gets the full deny + prescription, so the gate's teaching function is intact.)* ECC's hygiene kept: quick-exit fast path (2 stats), hook never crashes the tool call, state deliberately NOT in the anti-self-bypass protected list (deleting it merely re-gates — fail-safe direction).
- Opt-out: `gateguard: false` in `.mega-sdd/config.yaml`.

## Doctrine check

GateGuard is critical + un-promptable (the editor being gated is the one who'd skip the prose) → hook is justified. Hot-path cost: 2 stat calls for non-SDD/unlocked paths. Instinct injection is advisory context, not a gate. Deny-once never hard-blocks work — it taxes the first edit with exactly the grounding mega-sdd's invariants already demand.

## Files

Create: `skills/memory/references/instincts.md`, `scripts/build-locked-index.sh`, `tests/instincts-gateguard/*`.
Edit: `hooks/hooks.json` (PreToolUse matcher + Edit|Write|MultiEdit), `hooks/pre-tool-use` (parse file_path/session_id + GateGuard branch), `hooks/session-start` (instinct block), `learning-rules.md` (§instinct emission), `memory-schema.md` (instincts rows), `memory/SKILL.md` (route), `project-config.md` (`instincts:`, `gateguard:`), CHANGELOG + 4.25.0.

## Acceptance

- Functional: LOCKED-anchored fixture → index built → first Edit denied with prescribed facts → identical retry allowed → non-locked file untouched → `gateguard: false` disables.
- Instincts: conf-0.8 instinct injected at SessionStart, conf-0.5 not; block bounded.
- All hooks `bash -n` clean; `claude plugin validate` passes; full pin regression green.
