# Batch full-suite gate + out-of-band bypass guard — design

**Status:** accepted · **Date:** 2026-06-26 · **Skills:** `execute-bolts`, `orchestrate-flow` (sync lane) · **Enforcement:** `scripts/validate-bolt-artifacts.sh` + Stop-hook aggregator

## Problem

Every bolt's acceptance command is **scoped** to that unit (`<runner> <unit-target>`, never the whole project suite), and `execute-bolts` has **no final full-suite run**. Two failure modes ship a RED suite with nothing to catch it:

1. **Within-batch cross-bolt regression.** Bolt N (later) changes shared behavior that breaks bolt M's (earlier) contract. M's scoped acceptance test already passed at M's commit and never re-runs; N's scoped test doesn't cover M. The batch is declared `completed` while the project suite is RED.
2. **Out-of-band post-batch edit.** A commit touches a unit's `target_files` *without going through a bolt* (no pre/post-flight, no review panel, no `SDD-PROVENANCE` trailer) and breaks an earlier bolt's contract. The within-batch gate has already finished, so only the **sync lane** can catch it — and today the sync lane re-verdicts binding but never re-runs the suite.

"Prose that says run the full suite enforces nothing" — the obligation must be a deterministic artifact wired to a hook.

## Design

### A. Final full-suite gate (`execute-bolts`)

After the **last committed code-bearing bolt** of an invocation (single OR batch — a lone bolt can break a sibling just as a batch can; the suite runs in the shell, costing wall-clock not model tokens, so there is no cost reason to narrow it to multi-unit), run the project's **full** test suite — the runner detected at pre-flight check 3.5, **with no per-unit scope filter** — exactly once. Write `<vault>/bolts/_batch-suite.json`:

```json
{ "command": "<full-suite command>", "status": "green|red",
  "passed": N, "failed": N, "todo": N,
  "head_sha": "<sha at run>", "ran_at": "<iso>",
  "units": ["U-001", "..."], "bypass_commits": [] }
```

- `status: red` → **halt `batch_suite_red`**: the batch is NOT complete; emit the blocker with the failing test names; do not emit a `status: completed` handoff; leave the tree for human review (do not auto-revert).
- Runs once per invocation, after the last bolt — affordable. Skipped only for: `--dry-run`, a run that committed zero code (verify-only / all-skipped), or `--no-full-suite` (DISCOURAGED escape hatch, logged in `_summary.md` + handoff `notes.full_suite_skipped: true`, never silent).

### B. Out-of-band bypass guard (`execute-bolts`, at the gate)

Before the gate verdict, scan commits in the **batch window only** — from the invocation's base SHA (recorded at batch start) to HEAD, **excluding** this run's own bolt commits — for any commit that touched a unit's `target_files` yet carries no `SDD-PROVENANCE` trailer. Record them in `_batch-suite.json.bypass_commits[]`. A non-empty list does not by itself halt (the full-suite run is the real gate), but it is surfaced in `_summary.md` and forces the suite to run even on an otherwise-skippable invocation. Bounding to the batch window is mandatory — an unscoped `git log` would flag every pre-SDD commit in history.

### C. Sync-lane full-suite re-run (`orchestrate-flow --sync`)

After the sync lane reconciles any out-of-band edit (re-scan → drift triage → re-bind → unit reconcile), it **re-runs the full suite** and writes `_batch-suite.json` (same shape, `units: []`, `source: sync`). RED → surface in the sync output and `SYNC-REPORT.md`. This is the catch for failure mode 2. **Ownership:** the full-suite re-run is owned by B2 (here); C2 (SYNC-REPORT terminal verification) owns the `SYNC-REPORT.md` emission + staleness re-check and *consumes* this artifact rather than re-running the suite — they compose, they do not duplicate.

### Enforcement (gate, not prose)

`scripts/validate-bolt-artifacts.sh --batch-suite-gate` adds a check, mirroring the existing `bolt_artifacts_missing` next-run aggregator (the hook **verifies the artifact; it never runs the suite** — running 200s+ suites inside a PreToolUse hook is exactly the inflation to avoid). It is **commit-keyed, not handoff-keyed** — it never reads a handoff:

- It walks `git log` for two anchors: the newest **`(bolt): U-XXX` commit** that touched a code file (outside `.mega-sdd/`) — which *activates* the gate (no code-bearing bolt yet ⇒ nothing to gate) — and the newest commit touching a code file **regardless of subject** (`newest_code`), which is the *freshness* anchor.
- "Code file" = outside `.mega-sdd/` AND not a pure-docs file (`.md`/`.markdown`/`.rst`/`.adoc`) — a docs commit cannot break a test suite, so it must not force a re-run.
- A green `_batch-suite.json` **covers** the tree iff `newest_code` is an ancestor of (or equal to) the gate's `head_sha` (`git merge-base --is-ancestor`). Anchoring freshness on `newest_code` (not the newest bolt) is what closes the **out-of-band half** of the incident: a hotfix / manual edit / `git pull` that touches source after a green suite is no longer "covered" → **halt `batch_suite_gate_missing`** (with `out_of_band: true` when the uncovered change carried no bolt provenance).
- No covering green gate → **`batch_suite_gate_missing`** (missing or stale). An existing `_batch-suite.json` with `status: red` → **`batch_suite_red`** (blocked until green, mirroring the Factory-Line FAIL aggregator).

The validator keys on a code commit existing for the run, decided deliberately (not "multi-unit only"): a single bolt can break a sibling, and the artifact check is free. (The within-batch gate + this freshness anchor are defense-in-depth; the sync lane (§C) remains the reconciliation path for out-of-band edits.)

## Tests (behavioral — exercise the validator, never grep prose)

`tests/batch-suite-gate/` — fixtures of a `.mega-sdd` tree with a completed `execute-bolts` handoff:
1. code-committed bolt + no `_batch-suite.json` → validator exits non-zero, emits `batch_suite_gate_missing`.
2. code-committed bolt + `_batch-suite.json status: red` → emits `batch_suite_red`.
3. code-committed bolt + `_batch-suite.json status: green` at HEAD → exit 0.
4. verify-only handoff (no code commit) + no `_batch-suite.json` → exit 0 (gate not required).
Plus a wiring assertion that the Stop-hook aggregator invokes the new check.

## §B1 — Post-flight evidence gate (companion fix, same validator + doctrine)

The same field audit found the post-flight Hard-rule scan was **prose-only**: one `extend` bolt with non-empty `## Hard rules` committed with no `postflight.json`, and nothing caught it — the Stop-hook checked bolt-report presence but never the post-flight evidence. Textbook "prose that says HALT enforces nothing."

**Rule.** A committed `create`/`extend`/`modify` bolt whose unit has a **non-empty `## Hard rules`** section MUST carry `<vault>/bolts/U-XXX/postflight.json` with `status: pass` and every `rules[].verdict: pass`. Verify units skip post-flight (no changes to validate) and are exempt.

**Enforcement.** `validate-bolt-artifacts.sh --postflight-scan` (new mode) walks bolt commits, reads each unit's `task_type` + `## Hard rules` body, and flags any Hard-rule non-verify bolt with a missing or non-passing `postflight.json` → **`postflight_evidence_missing`**, written to `.bolt-postflight-state.json`. The Stop hook runs it each turn end; the PreToolUse execute-bolts aggregator blocks the next run on FAIL — exactly the orphan-scan / batch-suite pattern. The `postflight.json` schema is formalized in `execute-bolts/references/hard-rule-scan.md`.

**Test:** `tests/postflight-evidence/test-postflight-scan.sh` (behavioral) + `test-postflight-wired.sh` (wiring).

## Out of scope / deferred

- Choosing the full-suite command for exotic monorepos with multiple runners (the gate uses the single runner from pre-flight 3.5; multi-runner projects get a follow-up).
- The provenance trailer *format* is unchanged (defined in `execute-bolts/references/halts-and-handoff.md`).

---

## Amendment — S6 god-review hardening (2026-07-03, v4.59.0)

The stage-6 god-review found the B1/B2 gates dormant-or-forgeable in practice. This amendment is the new contract:

1. **Commit identity (EB-GATE-2).** A bolt commit is recognized by ANY of: the canonical conventional-commit scope `<type>(U-XXX):` (bolt-contract §Commit message format), the legacy `(bolt): U-XXX` subject, or the `Unit: U-XXX` git trailer. All validator modes (orphan / B2 / B1 / B3) share this identity. Producers additionally emit the `SDD-PROVENANCE:` trailer (the bypass-guard key).
2. **Evidence artifacts are writer-only (EB-GATE-4).** `postflight.json` and `_batch-suite.json` are Write/Edit-denied and Bash-tamper-guarded; they are produced ONLY by `scripts/run-postflight-scan.sh` (executes the unit's Hard rules: v1 productions deterministically, v2 via ast-grep, directives via explicit `--attest-directives`) and `scripts/run-full-suite.sh` (runs the detected full suite, pins `head_sha` via `git rev-parse HEAD`). No remediation text may instruct hand-writing either artifact.
3. **`head_sha` must be 40-hex (EB-VAL-1).** `covers()` rejects symbolic revs; a green artifact with `head_sha: "HEAD"` never covers anything.
4. **Gate-time re-derivation (EB-GATE-1/5).** The execute-bolts PreToolUse gate re-runs all six bolt-stage/quality validators (orphans, B2, B1, B3 whitelist, ui-quality, cross-cutting, factory-ledger) before the aggregator reads their states — a forged, stale, or absent state is overwritten with current truth.
5. **Obligation stickiness (EB-GATE-8).** B1 reads the unit's `task_type`/`## Hard rules` from the BOLT COMMIT (`git show`), falling back to the working tree only for untracked vaults.
6. **B3 whitelist observer (EB-GATE-11).** `--whitelist-scan` diffs each bolted unit's committed paths against `target_files` ∪ sanctioned extras (vault/bolt artifacts, `.mega-sdd/`, `docs/mega-sdd/`, `*-bound/`, test-file shapes); escapes block the next run with `whitelist_violation` (state `.bolt-whitelist-state.json`, guarded like its siblings).
7. **Layout + monorepo coverage (EB-VAL-2/5).** Unit/report/postflight/_batch-suite lookups go through `scripts/_lib/vault_layouts.py` (mirrors validate-unit-spec discover_units; pinned by test); git walks are pathspec-scoped to `git rev-parse --show-prefix` and the code-file filter excludes the legacy vault trees.
8. **Root resolution (EB-GATE-6).** `resolve_project_root` returns the nearest SUBSTANTIVE `.mega-sdd/` ancestor (vaults/ | knowledge-base/ | codebase/ | config.yaml); pure state-litter roots never shadow the true root; read-side validators SKIP (never mkdir) when no `.mega-sdd/` exists at the resolved root.
9. **Commit topology (EB-GATE-3).** One truth, everywhere: the implementer commits after tests pass; L0 gates / panel / post-flight are detect-after. All halt texts (incl. `secret_in_code`) describe committed-state remediation.

---

## Amendment — B1 recompute-at-gate (2026-07-03, v4.61.0)

S6 point 4 (EB-GATE-1/5) closed forgery for the SIX *derived* bolt-stage states (re-derived from ground truth before the read). B1 was the one hold-out: the execute-bolts gate re-ran `--postflight-scan`, but that mode only **re-read** the recorded `status`/`verdict` in the `postflight.json` **artifact** — it never re-executed the rules. So the artifact's status was trust-based; only the Write/Edit + Bash write-guards (verb enumeration) protected it — "a best-effort deny, not a cryptographic guarantee." This amendment makes the gate recompute B1's mechanical evidence from git/fs ground truth, closing the artifact-trust vector to parity with the other six states.

### Contract

- **`--postflight-scan --recompute` (gate mode, NEW).** For each committed Hard-rule bolt, re-execute the unit's rules from ground truth (the mechanical v1 productions + v2 ast-grep) and **OVERWRITE** `postflight.json` before `.bolt-postflight-state.json` is derived. A forged/stale/absent artifact cannot open the gate — it is regenerated, exactly like the six derived states. Under `--recompute`, an **absent** `postflight.json` is **produced** from ground truth, not flagged `evidence_missing`; `postflight_evidence_missing` under recompute now means a **recomputed non-pass verdict** (a rule genuinely failed), not "the agent skipped the scan."
- **`--postflight-scan` (read-only, UNCHANGED).** Retains the evidence-present contract: an absent/non-passing artifact for a Hard-rule bolt is `evidence_missing`. This is the mode the Stop hook and `run-postflight-scan.sh`'s self-refresh use, and the `run-postflight-scan.sh` wrapper is the sanctioned single-unit writer. **Two modes, two contracts for the same artifact — deliberate.**
- **Authority.** The gate (recompute) is authoritative: its overwrite lands before the aggregator's read (pre-tool-use line ~419 recompute → line ~493 read, same invocation — verified as the *sole* blocking reader of `.bolt-postflight-state.json`). A transient between-turns `evidence_missing` written by the read-only Stop hook self-heals at the next gate. Keeping the Stop hook read-only is the right call — a recompute on every turn-end (seconds) vs once before a multi-minute run.

### Why this is a strengthening, not a weakening (reviewer-ack)

The "force the agent to run the post-flight scan" obligation is **preserved exactly where it matters**:
- A unit with a **directive** Hard rule still blocks under recompute — no prior artifact ⇒ no attestation carry-forward ⇒ `directive_unverified` ⇒ FAIL, so the agent is still forced to run `run-postflight-scan.sh --attest-directives=<who/why>` after human review.
- A unit with only **mechanical** rules is now verified directly by the gate from ground truth, so separately requiring the agent to run the scan was redundant paperwork. Nothing real is lost; failing rules block *more precisely*, and the gate re-verifies against current HEAD every time — catching a FILE_PRESENCE/SIGNATURE regression a stale-but-honest artifact would have hidden. This is a genuine gain.

**Security of the mechanical/directive split (load-bearing).** `scan_unit` reclassifies every rule by its **text** (the STRICT v1 regexes are tried first), so an attacker CANNOT relabel a mechanical rule as a directive to dodge recompute. Directive attestation is carried forward from the prior artifact (`verdict==attested`, `type∈{directive,directive_prose}`) — no weaker than before, because directives were always trust-based (they require an explicit human `--attest-directives`). Obligation stickiness (EB-GATE-8) is unchanged: the rules are read from the unit text AT the bolt commit, so a retroactive Hard-rules-blanking edit cannot erase an incurred obligation.

### Cost bound

The gate does **one** `git log -N --name-status -- .` walk (N=300) shared across all units, then one `scan_unit` per Hard-rule unit — **no cache** (a cache file is itself a forge vector) and **no parallelism** (fan-out adds overhead + is fragile on Windows Git Bash). Measured on a pessimal 300-commit / 50-Hard-rule-unit fixture with a SIGNATURE git-grep per unit: **~7.3s @ 50 units (0.146s/unit) → ~15s @ 100 units**, within the hot-path budget. It fires ONLY on `Skill(mega-sdd:execute-bolts)`, once per invocation, immediately before a multi-minute bolt run — not on every tool call.

### Engine factoring + incidental fix

The rule engine is factored into **`scripts/_lib/postflight_rules.py`** (`walk_unit_commits` + `scan_unit`), imported by BOTH `run-postflight-scan.sh` (byte-identical to the pre-refactor inline engine — proven 0 diffs across 11 rule shapes) AND `validate-bolt-artifacts.sh --postflight-scan --recompute`. A single shared engine is a hard requirement: if the gate's recompute diverged from the writer's logic, an honest artifact would false-block on engine drift. **Incidental fix:** the shared walk uses the `-- .` pathspec (EB-VAL-5 form), which also *corrects* `run-postflight-scan.sh`'s previous `-- <PREFIX>` pathspec (which matched nothing when the vault lived under a monorepo subproject).

### Honest ceiling

B1's **mechanical** rules recompute at the gate; **directives** stay `attested` via carry-forward (unchanged trust model); **B2** (the full suite, ~387s) stays evidence-based — re-running a suite inside a PreToolUse hook is exactly the inflation the doctrine forbids, so B2 remains a verified artifact (writer `run-full-suite.sh` + write-guard), not a recompute.

### Tests

- `tests/postflight-evidence/test-postflight-recompute.sh` (behavioral): forged-pass→recomputed-fail overwrite, honest-pass kept, directive attestation carry-forward, obligation stickiness.
- `tests/postflight-evidence/test-postflight-scan.sh` (unchanged) pins the read-only evidence-present contract.
- `tests/god-review-s6/test-6a-gate-hooks.sh` (updated): the forged-PASS-overwritten assertion now plants a forged `postflight.json` PASS for a unit whose Hard rule GENUINELY fails on recompute (FILE_PRESENCE for a file the bolt never creates), asserting the gate overwrites both the artifact and the state to a real FAIL.


> **Amendment (2026-07-06, token-efficiency B2/M-05):** PASS-path stdout goes quiet — gates read STATE FILES/artifacts, never stdout. (a) `run-postflight-scan.sh` prints ONE line on pass (`postflight U-XXX: pass (N rules, M attested) -> <path>`); the full rules[] artifact dump prints only on fail (artifact write, exit codes, and the B1 gate path are unchanged). (b) per-bolt streaming is TWO lines (start + done folding the anchors-honesty count + commit sha); stage detail lives in `_summary.md` and prints in chat only when a stage fails. (c) the parent-thread post-batch re-scan and bind's scorecard preflight invoke their validators with `--quiet`, branch on exit code, and read the specific state file only on non-zero.

> **Amendment (2026-07-09, god-review S7 Batch A — Hard-rule engine).** Six engine holes + three doc lies fixed in the shared B1 engine (`scripts/_lib/postflight_rules.py`), all reproduced empirically before fixing (audit archive `~/.mega-sdd/god-review-s7/hardrules.md`): **(HR-1, CRITICAL)** `ast-grep scan --rule` matches a bare relative `files:` glob against NOTHING, so every v2 rule authored in the grammar ref's documented shape was silently INERT (zero files scanned → verdict pass while the lock never executed) — the engine now normalizes relative globs to `**/`-prefixed before scanning and the grammar ref mandates `**/` authoring (deliberately NO sha256-vs-preflight compare — see the review-round paragraph below); **(HR-2)** the grammar's flagship v2 example was not a valid ast-grep rule (no positive matcher — the doc's own preflight parse-check halts on it) and the v1→v2 mapping promised migrations ast-grep cannot express (it is stateless: no "modified"/"new dep") — example replaced with a parseable content-lock, mapping rows route DO_NOT_MODIFY/ADD_DEPS/NAMING back to v1, migrate template fixed; **(HR-3)** the no-snapshot SIGNATURE_RULE check was token-SUBSET — an ADDED parameter (the doc's own canonical violation) passed — now full paren-list EQUALITY, fail-closed when unextractable; **(HR-4)** the lexer accepted only `- ` bullets, silently dropping `*`/`+`/numbered rules while the B1 obligation was "satisfied" by a placeholder pass — dash bullets and keyword-carrying non-dash bullets now lex as rules, continuations join, keyword-LEADING non-bullet lines fail `unparseable`, and non-rule prose stays tolerated (see the review-round paragraph); **(HR-5)** DO_NOT_ADD_DEPS diffed `oldest^..HEAD/working-tree`, so any LATER unrelated dep commit retroactively false-failed the unit (and gate recompute persisted the false block) — now diffed per own-commit (see the review-round paragraph); **(HR-6)** `git mv locked new` dodged DO_NOT_MODIFY (rename kept only the new path) — the vacated old path now records as a deletion; **(HR-7)** `MUST NOT modify X` / `NEVER …` classified as attestable directives, waving a machine-checkable lock through on trust — modal synonyms with a PATH-SHAPED object now classify MECHANICAL (prose objects stay directives — see the review-round paragraph), and the blanket-per-run `--attest-directives` semantics are disclosed; **(HR-8)** hard-rule-scan.md still called recompute-at-gate "backlog" (shipped v4.62.0) — corrected; **(HR-9)** the writer scans working-tree unit text while the gate recomputes at the bolt commit, so the sanctioned "edit the rule → re-run → pass" was silently overridden at the next gate — the writer now WARNs PROVISIONAL on drift and the remediation instructs committing the rule edit. Pinned by `tests/god-review-s7/test-s7a-hardrule-engine.sh` (empirical fixture, probes A–F).

> **Amendment (2026-07-09, S7-A adversarial review round — 2 blind reviewers, both FIX-FIRST, every finding empirically reproduced).** Five of the nine fixes were revised before ship: **(r1-1)** the inline `files:` comma-split corrupted brace/char-class globs in ALREADY-`**/`-correct rules into `Cannot parse glob pattern` permanent false-fails → the split is now quote/brace/bracket-aware, `files:` keys are matched at column 0 only (a `files:`-looking line inside a block-scalar `message:` is document text), and `./`-stripping preserves hidden-path leading dots. **(r1-2)** the sha256-vs-preflight defense shipped in the first HR-1 cut was DELETED: it compared preflight shas against the live working tree for any path+sha256 preflight entry, so a bolt that FIXES a pre-bolt violation could never pass (fixing the violation necessarily changes the file), any later legitimate edit false-blocked old units at gate recompute (the exact HR-5 class, reintroduced), and it enforced a files-lock semantic the mapping table forbids for v2 (locks stay v1 `DO_NOT_MODIFY`). A v2 rule is a pattern scan; the preflight v2 snapshot is an audit record only. **(r1-3)** HR-5's single `oldest^..newest` span was re-widened across interleaved unrelated commits the moment the sanctioned `fix(U-XXX):` remediation commit existed → DO_NOT_ADD_DEPS now diffs each of the unit's OWN commits (`sha^..sha`) and unions the additions; manifest rev-paths use `:./` (cwd-relative) because repo-root-relative `git show sha:package.json` read a monorepo ROOT manifest at both edges — a dep added by the unit's own commit passed, fail-open (found independently by both reviewers). **(r1-4)** the first HR-4 cut failed ANY non-bullet line as `unparseable`, but `validate-unit-spec.sh` documents "other non-dash prose stays tolerated" — units lint had passed would retroactively hard-fail at recompute → the engine's net now mirrors the unit-stage net EXACTLY (dash bullets always rules; non-dash bullets rules only with a rule keyword; non-bullet lines fail only when keyword-LEADING; everything else tolerated). **(r2-2)** HR-7's bare `\S+` object capture turned prose ("MUST NOT modify existing API response contracts") into a mechanical lock on the path "existing" → vacuous auto-PASS, a DOWNGRADE from the directive tier's required human attestation → modal synonyms classify mechanical only for a PATH-SHAPED object (contains `.` or `/`); `validate-unit-spec.sh`'s strict productions mirror the same shapes. Also fixed: the HR-9 warn was inert on native Windows (`os.path.relpath` backslashes in a git rev-path); SKILL.md §B1's threat note still called recompute "backlog"; four grammar-v2 internal contradictions; and the upgrade blast radius (previously-green bolts flipping at the next gate recompute) is now disclosed in `references/upgrade-from-old-version.md §Common halts after upgrade`.
