# execute-bolts — Hard Rule pre/post-flight scan

The anti-hallucination gate. Each unit's `## Hard rules` are validated against real codebase state **before** the bolt (pre-flight snapshot) and **after** the bolt (post-flight scan); any post-flight violation **HALTS the run**. Commit topology (detect-after — one truth, per SKILL.md): the `bolt-implementer` commits after its tests pass, so the post-flight scan runs against an already-committed bolt; a violation gates every further `execute-bolts` (B1) and the remediation is fix-forward or revert of the flagged commit — never a claim that the code is uncommitted. The skill body owns the gate's existence + trigger; this file owns the grammar, snapshot formats, and per-rule mechanics.

## Contents
- Pre-flight: grammar detection
- Pre-flight: v2 (ast-grep) snapshot
- Pre-flight: v1 (legacy 5-grammar) snapshot
- `preflight.json` format
- Halt YAMLs (`hard_rule_unparseable`, `hard_rule_unanchored`)
- Post-flight: per-rule re-validation
- Framework-pack rule provenance
- Per-sibling cross-cutting registration scan
- Parent-thread post-flight re-scan
- Violation handling + `hard_rule_violated` halt YAML
- verify-unit special path

## Pre-flight: grammar detection

The entire pre-flight (grammar detection → per-rule validation → snapshot capture) is **executed by `scripts/run-preflight-scan.sh --cwd=<root> --units=U-001,U-002,…`** — the deterministic writer, called ONCE per batch with every target unit (`--unit=U-XXX` remains valid for a single unit). The controller runs the script and maps its exit code to the halt taxonomy; it never computes shas or emits the JSON itself (the artifact is hook-guarded — see §`preflight.json` format). Batch semantics: a FATAL code (3/4/5/6/8) stops the batch at the offending unit (named on stderr, unprocessed remainder listed); **exit 2 is a PRE-LOOP abort** (unresolvable unit id / usage / not a git repo) — nothing was processed, no baseline written for any unit, no remainder listing; exit 7 is per-unit and non-fatal — the batch continues and the final exit is 7 iff ≥1 unit was refused (each named on stderr):

| Exit | Meaning → controller action |
|---|---|
| 0 | snapshot written / existing baseline kept (immutable) / no Hard rules — proceed |
| 2 | usage error (unit not found / not a git repo) — fix the invocation |
| 3 | halt `hard_rule_unparseable` (offending line / ast-grep stderr named verbatim) |
| 4 | halt `hard_rule_mixed_grammar` (`--grammar=v1\|v2` is the escape hatch) |
| 5 | halt `hard_rule_unanchored` (SIGNATURE_RULE symbol not in tracked source) |
| 6 | halt `dep_missing` (v2 grammar, ast-grep absent) |
| 7 | post-hoc refusal — bolt commits already exist and no baseline is on disk; NON-FATAL: proceed, post-flight falls back to commit evidence, log in the bolt-report |
| 8 | dirty-protected-path refusal — a rule target path (a `DO_NOT_MODIFY` path, or the file declaring a `SIGNATURE_RULE` symbol) differs from HEAD at baseline time; no artifact written. FATAL for this run (treat like a `hard_rule_violated`-style STOP, never proceed): commit or restore the protected file, then re-run — a dirty protected path at baseline time is indistinguishable from tampering |

What the script executes, for each unit with a non-empty `## Hard rules` body section:

- YAML code blocks under `## Hard rules` → **v2 grammar** (ast-grep YAML; the grammar spec is the v2 Hard-rule-grammar ref listed in SKILL.md).
- Bulleted line items (`- DO NOT modify ...`) → **v1 grammar** (the 5-type legacy set).
- Mixed (both forms in one unit) → halt `hard_rule_mixed_grammar` (user migrates via `migrate-rules`).
- Override via the script flag `--grammar=v1|v2` (the controller forwards the user-level `--hard-rule-grammar=v1|v2` value as `--grammar=<v>` on the script invocation — the script itself accepts only `--grammar`).

**For v2 grammar:** probe `command -v ast-grep`. Absent → halt `dep_missing` (install guidance is in the v2 Hard-rule-grammar ref listed in SKILL.md). Validate each YAML block via parse-via-scan (`ast-grep test --validate` does NOT exist in the CLI — the snippet is in `hard-rule-grammar-v2.md` §Pre-flight, the single owner of the parse-check mechanics). Unparseable → halt `hard_rule_unparseable`.

**For v1 grammar (legacy path preserved):** parse each rule line against the 5-grammar set per `generate-units/references/unit-schema.md` §Hard rule grammar (plus the directive tier — see §Directive rules below, which is ACCEPTED, not unparseable). NEVER silently skip a line that matches neither — unparseable → halt `hard_rule_unparseable`:

- `DO NOT modify <path>`
- `DO NOT add new <manifest> dependencies`
- `<path-glob> MUST follow <case-style> naming`
- `function <name> MUST preserve signature: <type-sig>`
- `file <path> MUST exist after bolt`

**Directive rules (third category — honest tier).** A generic `- MUST/MUST NOT/DO NOT/NEVER/ALWAYS …` prose line is ACCEPTED by the unit-stage validator (counted `hard_rules_directive_prose`) but is not machine-checkable by construction. At post-flight, `run-postflight-scan.sh` records such a rule as `type: directive` with verdict `directive_unverified` (non-pass) unless the run passes `--attest-directives="<who/why>"` after controller/panel review — then the verdict is `attested`, which `postflight_ok` accepts for directive-typed rules ONLY. **`--attest-directives` is blanket per run**: the one reason attests EVERY directive line in the unit (there is no per-rule attestation) — review ALL of them before attesting. Modal synonyms of the mechanical productions (`MUST NOT modify src/x.php`, `NEVER add new package.json dependencies`) classify as MECHANICAL, never directive — they cannot be attested past — **when the object is path-shaped** (contains `.` or `/`); a prose object (`MUST NOT modify existing API contracts`) stays a directive, because a mechanical check against a non-path would pass vacuously. A fabricated `pass` verdict on a directive line does not exist in the sanctioned writer's vocabulary.

## Pre-flight: v2 (ast-grep) snapshot

For each rule, snapshot AST state via `ast-grep scan --rule <yaml> --json` (zero matches expected pre-bolt for "forbidden" rules). Entries are recorded as `{type: v2_ast_grep, rule: <id>, matched_files: [{path, sha256}]}` in the same top-level `rules[]` array of `preflight.json` — an AUDIT record of the pre-bolt state, nothing more: post-flight re-runs the scan; it does NOT sha-compare (a v2 rule is a pattern scan, not a lock — the bolt may legitimately edit matched files to fix a pre-existing violation).

## Pre-flight: v1 (legacy 5-grammar) snapshot

- `DO_NOT_MODIFY <path>` → record `sha256(file content)` if the file exists; record "absent" otherwise.
- `DO_NOT_ADD_DEPS <manifest>` → record the manifest's dependency-section content.
- `NAMING_RULE <path-glob> <case-style>` → no pre-snapshot (post-flight checks new files only).
- `SIGNATURE_RULE function <name>` → the script extracts the current declaration via the shared `find_decl_line` (the SAME extractor post-flight uses) and records the pre-`{` prefix as `signature_at_preflight`; symbol not found in tracked source → exit 5 → halt `hard_rule_unanchored`.
- `FILE_PRESENCE_RULE file <path>` → no pre-snapshot.

## `preflight.json` format

`run-preflight-scan.sh` persists the snapshot as `<vault>/bolts/U-XXX/preflight.json` for post-flight comparison:

```json
{
  "unit_id": "U-001",
  "snapshot_at": "2026-05-20T10:00:00Z",
  "head_sha": "<HEAD sha at capture>",
  "written_by": "run-preflight-scan.sh",
  "grammar": "v1",
  "rules": [
    {"type": "DO_NOT_MODIFY", "path": "src/Models/User.php", "sha256": "abc123..."},
    {"type": "DO_NOT_ADD_DEPS", "manifest": "package.json", "deps_section": "..."},
    {"type": "SIGNATURE_RULE", "function": "authenticateUser", "signature_at_preflight": "(email: string, password: string) => Promise<User>"}
  ]
}
```

The `snapshot_at` / `head_sha` / `written_by` / `grammar` top-level keys are provenance stamps added by the script; the `rules[]` entry shapes are UNCHANGED (the post-flight engine reads only `rules[]`, so the stamps are ignored by every consumer). The artifact is **hook-guarded like `postflight.json`** — Write/Edit denied plus the Bash tamper verbs — because the engine gives a present sha/signature snapshot precedence over commit evidence: a hand-written baseline with a wrong sha256 is a forged BASELINE that makes a `DO_NOT_MODIFY`/`SIGNATURE` violation undetectable. Lifecycle rules:

1. **Re-capture is allowed only while the unit has no bolt commits** — a re-run overwrites the snapshot (fresh `snapshot_at`).
2. **Once bolt commits exist the baseline is immutable** — an existing artifact is kept byte-identical; an absent one is refused with exit 7 (anti-laundering; post-flight then uses git commit evidence instead).
3. **A baseline is minted only from a tree whose protected paths match HEAD** — before minting, the writer compares every rule target path (`DO_NOT_MODIFY` paths AND the file declaring each `SIGNATURE_RULE` symbol) against HEAD; any difference is refused with exit 8 and NO artifact is written (tamper-BEFORE-mint would bake the tampered sha into the baseline, and the engine gives a present snapshot precedence over commit evidence). Remedy: commit or restore the protected file, then re-run — a dirty protected path at baseline time is indistinguishable from tampering. Unrelated dirty files never block; a legitimate clean-tree pre-flight is unaffected (HEAD == disk).

## Halt YAMLs

```yaml
blocker:
  type: hard_rule_unparseable
  emitted_at: <ISO8601>
  emitted_by: execute-bolts
  details:
    unit_id: U-XXX
    offending_line: "<verbatim>"
    expected_grammar: [DO_NOT_MODIFY, DO_NOT_ADD_DEPS, NAMING_RULE, SIGNATURE_RULE, FILE_PRESENCE_RULE]
  next_action: "Fix the unit's ## Hard rules section per generate-units/references/unit-schema.md §Hard rule grammar."
```

```yaml
blocker:
  type: hard_rule_unanchored
  emitted_at: <ISO8601>
  emitted_by: execute-bolts
  details:
    unit_id: U-XXX
    rule: "function <name> MUST preserve signature: ..."
    reason: "Referenced function not found in tracked source (shared find_decl_line extractor); cannot snapshot or validate"
  next_action: "Verify the function name is correct OR remove this rule if the function doesn't exist yet."
```

## Post-flight: per-rule re-validation

After the implementer reports DONE (its commit already landed), run the post-flight scan via `scripts/run-postflight-scan.sh --cwd=<root> --unit=U-XXX` — the deterministic writer (the postflight.json artifact is hook-guarded; direct writes are denied). This is the safety net.

**v2 grammar (ast-grep):**

```bash
# Per rule: run ast-grep scan; any match against "forbidden" patterns = VIOLATED
ast-grep scan --rule <rule-yaml-tempfile> --json <repo-root>
```

Parse the JSON output. Match found → VIOLATED with `file:line` + matched text as evidence. Zero matches → PASSED. (No sha256-vs-snapshot compare — lock semantics stay v1 `DO_NOT_MODIFY`; see the grammar ref's mapping table.)

**v1 grammar (legacy, preserved):**

| Rule type | Post-flight check |
|---|---|
| `DO_NOT_MODIFY <path>` | Compute current `sha256(file)`. Compare to preflight snapshot. Differs OR file appeared → VIOLATED. |
| `DO_NOT_ADD_DEPS <manifest>` | Read current manifest deps section. Diff against preflight snapshot. ANY new entry → VIOLATED. |
| `NAMING_RULE <path-glob> <case-style>` | Enumerate new files matching `path-glob`. Apply case-style regex. Mismatch → VIOLATED. |
| `SIGNATURE_RULE function <name>` | Re-extract current signature from codebase. Compare to preflight. Differs → VIOLATED. |
| `FILE_PRESENCE_RULE file <path>` | Probe `<path>` exists. Absent → VIOLATED. |

Post-flight results are written to `<vault>/bolts/U-XXX/postflight.json` (per-rule pass/fail + evidence):

```json
{
  "unit_id": "U-001",
  "scanned_at": "2026-05-20T10:05:00Z",
  "status": "pass",
  "rules": [
    {"type": "DO_NOT_MODIFY", "path": "src/Models/User.php", "verdict": "pass", "evidence": "sha256 unchanged"},
    {"type": "SIGNATURE_RULE", "function": "authenticateUser", "verdict": "pass", "evidence": "signature preserved"}
  ]
}
```

**Mandatory evidence (B1 — enforced, not prose).** For a committed `create`/`extend` bolt whose unit has a **non-empty `## Hard rules`** section, this `postflight.json` MUST exist with `status: pass` and every `rules[].verdict: pass` (or `attested` on `directive`-typed rules) — and it is written by `run-postflight-scan.sh` and hook-guarded against direct writes plus the common programmatic write paths (and, since v4.62.0, **RECOMPUTED at the gate**: `validate-bolt-artifacts.sh --postflight-scan --recompute` re-executes each committed Hard-rule bolt's mechanical rules from git/fs ground truth via the shared `scripts/_lib/postflight_rules.py` engine and OVERWRITES the artifact before the state is read — a forged/stale/absent artifact is regenerated; directives keep their prior human attestation via carry-forward). The Stop hook AND the execute-bolts gate re-run `validate-bolt-artifacts.sh --postflight-scan`; the PreToolUse aggregator **blocks the next `execute-bolts`** with **`postflight_evidence_missing`** when a Hard-rule bolt committed with no passing `postflight.json` — the post-flight scan can no longer be silently skipped or satisfied by a naive hand-written artifact. The validator reads the unit's content at the bolt commit (`git show`), so a retroactive unit edit cannot erase the obligation. Verify units skip post-flight (no changes to validate), so they are exempt. Design: `docs/superpowers/specs/2026-06-26-batch-suite-gate-and-bypass-guard.md §B1`.

> `--force-skip-postflight` skips the ast-grep step for ONE run only and is logged per the SKILL.md anti-bypass policy (handoff `notes.postflight_skipped: true` + `_summary.md`). It does NOT downgrade the rail; a follow-up re-run without the flag is required before drift-detect / merge.

## Framework-pack rule provenance

Framework-pack rules (pulled into a unit's Hard Rules by `generate-units` Step 12.4.5) are validated identically to other Hard Rules — Step 12.4.5 emits them **in an executable production** (packs ship `rule_type` inventories, not ready-made ast-grep blocks; the translation happens at emission time per the pack→bolt table in `bind-codebase/references/hard-rules-and-packs.md §2.9a` — v1 production, verbatim v2 YAML when the pack carries a real `rule:` body, or the honest `directive`/Anti-pattern tier). The violation surface includes a `framework_pack_source` field in the halt YAML so the user knows WHICH framework rule fired.

## Per-sibling cross-cutting registration scan (defense-in-depth)

When a unit fans out into N structurally-analogous sibling models (a module's golden exemplar plus siblings), a cross-cutting concern proven on the exemplar (e.g. registering the `BranchScoped` global scope) must be verified in EACH sibling's generated source — not once. The classic execution-fidelity miss: every sibling SPEC named the `BranchScoped` trait, but the bolt forgot the `addGlobalScope(new BranchScoped)` registration in several generated models — a silent cross-branch authorization leak that no unit-spec or Hard-Rule check catches (the spec was correct; the runtime call was dropped).

This is ENFORCED by `scripts/the --cross-cutting mode of validate-sibling-consistency.sh`, which reads the active framework pack's `## Cross-cutting concerns` (each concern's `registration_signature` + `registration_target_glob`) and scans every generated source file that references the concern mechanism AND carries the `applies_when` column, flagging any that lack the registration call. It runs PostToolUse on model/source writes (→ `.cross-cutting-state.json`); PreToolUse Branch 11 blocks the NEXT `execute-bolts` on FAIL (honest detect-and-block-next — a hook cannot un-write a file a bolt just wrote mid-turn). This prose is defense-in-depth; the validator is the gate. Tech-agnostic: never assume a stack's registration idiom — it comes from the pack, so add a stack = add a pack.

## Parent-thread post-flight re-scan

The project-wide quality validators that scan GENERATED SOURCE/VIEWS — `the --cross-cutting mode of validate-sibling-consistency.sh`, `validate-ui-quality.sh`, and (for vault edits) `validate-vault-oqs.sh` — fire via PostToolUse on the writer's Write/Edit. PostToolUse DOES fire on bolt-agent writes (it fires inside subagents — AUDIT L1), so the state is not "invisible"; but under `--parallel` / `--per-squad` the project-wide state can lag concurrent write ordering (each validator is a full-glob current-truth re-scan, and the async hook may not have settled). To make the gate state deterministic: after each bolt batch completes, the **main-thread controller** explicitly bash-invokes those validators against `$PROJECT_ROOT` **with `--quiet`, branching on the exit code** — read the specific `.mega-sdd/.<validator>-state.json` ONLY on non-zero (M-05: the PreToolUse gate reads state files, never stdout; an unquieted PASS printed full state JSON incl. the ~350-char canned next_action per validator) — so the gate reflects current truth regardless of write ordering. This is **defense-in-depth** on top of the detect-and-block-next contract — not a load-bearing compensation for an invisible write.

## Violation handling + `hard_rule_violated` halt YAML

- **ANY rule violated → HALT the run (detect-after).** The violating code is already committed (the implementer commits before the scan). The user reviews + fixes forward or `git revert`s the bolt commit; the B1 gate blocks every further `execute-bolts` until a passing `postflight.json` is recorded by `run-postflight-scan.sh`.
- Emit the `hard_rule_violated` blocker YAML with `violated_rule` + evidence.
- `bolt-report.md` MUST be written with `status: halted_postflight` and list the violations.

```yaml
blocker:
  type: hard_rule_violated
  emitted_at: <ISO8601>
  emitted_by: execute-bolts
  details:
    unit_id: U-XXX
    committed: true          # detect-after — the bolt commit already landed
    commit: <bolt commit sha>
    violations:
      - rule: "DO NOT modify src/Models/User.php"
        evidence: "sha256 mismatch — preflight: abc123..., postflight: def456..."
      - rule: "function authenticateUser MUST preserve signature: (email: string, password: string) => Promise<User>"
        evidence: "Signature changed; postflight: (email: string, password: string, twoFactor?: string) => Promise<User>"
  next_action: "The violation is in commit <sha>: fix the code forward (or git revert the bolt commit), then re-run run-postflight-scan.sh; execute-bolts stays gated until a passing postflight.json is recorded. If the RULE is wrong, edit the unit's Hard rules AND COMMIT the edit as `fix(U-XXX): correct hard rule` — the gate recomputes against the unit text AT the bolt commit, so an uncommitted working-tree edit is silently overridden at the next gate (the writer's pass would be provisional)."
```

## verify-unit special path

`task_type: verify` units run a simplified flow (no code write):

1. Pre-flight: validate the unit's `target_files` is empty / all `operation: none` (else halt `verify_unit_writable` — verify units are read-only and must never be written).
2. Skip `executing-plans` (no code to write).
3. Run acceptance tests.
4. Skip the post-flight Hard-rule scan (no changes to validate).
5. Commit only `bolt-report.md` (no source changes); OR skip the commit entirely on `--no-empty-commits`.
