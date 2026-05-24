# Iter 40 — Silent-Failure Path Closure Design

**Status:** Approved (autonomous execution per user directive)
**Source:** Iter 38 audit — `docs/superpowers/audits/2026-05-25-iter-38-e2e-optimization-audit.md` priority 1 (Robustness D3)
**Plugin:** v3.26.3 → v3.27.0 (MINOR — new halts = orchestrator behavior change)
**Estimated effort:** ~2hr

---

## §1 — Problem (from audit)

The Iter 38 audit identified 3 silent-failure paths where mega-sdd skills exit a chain without surfacing a halt, leaving the orchestrator (or user) to discover the failure via downstream cryptic errors:

1. **Producer skill crashes before handoff emission.** Orchestrator polls expected handoff path, finds nothing, proceeds with empty state OR fails downstream with confusing "missing artifact" error. **Failure mode:** silent restart from chain-start state.

2. **Handoff YAML lists `artifacts: [paths]` but paths don't exist on disk.** Orchestrator validates schema fields (Iter 33 F3+F4) but doesn't existence-check paths. Next skill in chain consumes a non-existent path and fails with cryptic "file not found." **Failure mode:** halt fires at wrong skill (consumer), not producer.

3. **`execute-bolts --resume` loads corrupt `partial-state.json`.** Current behavior is undefined — JSON parse fails → likely overwrites with fresh state, hiding the original recovery context. **Failure mode:** silent loss of partial work.

All 3 leak debugging signal. All 3 close with one new ALWAYS-STOP halt per failure mode.

---

## §2 — Design (new halts)

### `handoff_missing` (ALWAYS STOP, emitted by orchestrate-flow)

**Fires when:** orchestrator polls expected handoff YAML path after sub-skill returns; file does not exist OR is zero bytes.

**Producer:** orchestrate-flow v3.2.0+ (new — emitter is orchestrator itself).

**Detection point:** orchestrate-flow Procedure step `b.i` (before YAML parse). Inserted as new step `b.0` (pre-check).

**Resolution:** user inspects sub-skill chat output for crash logs; runs sub-skill again standalone to reproduce; reports as skill-author bug.

**Type-specific envelope fields:**
- `failing_skill`: string
- `expected_handoff_path`: string (absolute)
- `last_known_step`: string (best-effort — from any checkpoint trail or "unknown")

### `artifact_missing` (ALWAYS STOP, emitted by orchestrate-flow)

**Fires when:** handoff YAML passes schema validation (Iter 33 F3+F4), declares `artifacts: [paths]`, and one or more paths fail `test -f` / `test -d`.

**Producer:** orchestrate-flow v3.2.0+.

**Detection point:** new Procedure step inserted AFTER existing `b.vi` (all schema validation passes) and BEFORE `c` (continue to next skill).

**Resolution:** user inspects sub-skill chat to confirm whether artifact was actually written; possibly producer crashed mid-write. Reports as skill-author bug OR re-runs sub-skill.

**Type-specific envelope fields:**
- `failing_skill`: string (producer)
- `missing_paths`: array<string>
- `present_paths`: array<string>
- `handoff_file`: string

### `partial_state_corrupt` (ALWAYS STOP, emitted by execute-bolts)

**Fires when:** `execute-bolts --resume` reads `<vault>/.internal/checkpoints/partial-state.json` and JSON parse fails.

**Producer:** execute-bolts v2.7.3+ (new emitter — adds explicit parse-check; previously silent overwrite).

**Detection point:** execute-bolts §Resume logic, before partial-state consumption.

**Resolution:** user inspects partial-state.json contents; either fixes manually (rare) OR renames to `.corrupt-<ISO8601>` and re-runs `--resume` (will start from scratch but corruption preserved for forensics) OR runs without `--resume` to restart bolt batch fresh.

**Anti-bypass rationale:** previously silent recovery hid bolt-author bugs (e.g., race condition during partial-state write). Halt makes diagnosis trivial. Per "no bypassing anti-hallucination" CLAUDE.md.

**Type-specific envelope fields:**
- `partial_state_path`: string (absolute)
- `parse_error`: string (first 200 chars of exception)
- `corrupt_backup_path`: string (suggested rename target)

---

## §3 — 4-surface taxonomy update (per propagation directive)

Each new halt updates ALL 4 surfaces (Iter 33 +Iter 31 mandate):

| Surface | Update |
|---|---|
| Producer SKILL.md | orchestrate-flow §Procedure (handoff_missing + artifact_missing); execute-bolts §Resume (partial_state_corrupt) |
| `vault-contract.md` enum | + handoff_missing, + artifact_missing, + partial_state_corrupt |
| `vault-contract.md` descriptions | 3 new entries in halt-protocol description list |
| `orchestrate-flow/SKILL.md` halt taxonomy | 3 new entries in ALWAYS-STOP section |
| `handoff-contract.md` per-skill | document detection points orchestrator performs |

---

## §4 — Version bumps

- `plugin.json`: 3.26.3 → **3.27.0** (MINOR — new orchestrator halts = chain behavior change for any user with silent-failure history)
- `orchestrate-flow` SKILL.md: 3.1.2 → **3.2.0** (MINOR — 2 new procedure steps + 2 new halts emitted)
- `execute-bolts` SKILL.md: 2.7.2 → **2.7.3** (PATCH — new error path; same procedure)
- `vault-contract.md`: no per-file version; covered by skill bumps that reference it

---

## §5 — Out of scope

- **Convergence eligibility:** all 3 halts are ALWAYS STOP (producer bugs require human inspection, not auto-loop). Cycle-eligible bridge from Iter 33 §Convergence does NOT extend here.
- **Memory recording:** these halts indicate skill bugs, not user choices. NOT recorded in routing-outcomes.md memory.
- **Backward compat:** chains that previously silently-passed now halt explicitly. Documented in CHANGELOG as expected-behavior change.

---

## §6 — Cross-refs

- Iter 38 audit: `docs/superpowers/audits/2026-05-25-iter-38-e2e-optimization-audit.md`
- Iter 33 F3+F4 (precedent for orchestrator-emitted halts): `docs/superpowers/specs/2026-05-24-iter-33-flawless-seamless-intelligence-design.md`
- Halt envelope contract: `plugins/mega-sdd/skills/generate-intent/references/vault-contract.md §halt-protocol`
- Handoff contract: `plugins/mega-sdd/skills/orchestrate-flow/references/handoff-contract.md`

---

## §7 — Standing directives applied

- **simplifikasi:** 3 halts → 3 surgical additions to existing surfaces. No new files.
- **flawless:** Producer + consumer ship in-iter (orchestrate-flow emits + same skill consumes via halt-protocol). No deferred propagation.
- **reuse-first:** extends existing halt envelope (vault-contract.md), existing ALWAYS-STOP taxonomy (orchestrate-flow.md), existing per-step JSONL checkpoint protocol (no new persistence).
