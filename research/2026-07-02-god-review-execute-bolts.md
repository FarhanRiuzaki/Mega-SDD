<!--
God-tier review — pipeline stage 6 (execute-bolts) — FINAL pipeline stage.
Produced by the 8-blind-lens adversarial workflow (lenses -> dedup -> refute-by-default
verify [High = empirical repro required] -> synthesize), 2026-07-02.
Stats: 59 raw -> 40 unique -> 37 survived (10 High / 19 Medium / 8 Low).
Fix round appended after implementation (round-2 section), per stage 3-5 convention.
-->

# God-Tier Review — `execute-bolts` (Stage 6) — Final Report

**Scope:** `plugins/mega-sdd/skills/execute-bolts/**`, `agents/*-reviewer.md`, `agents/bolt-implementer.md`, `scripts/validate-bolt-artifacts.sh` + aux validators, `hooks/pre-tool-use` / `hooks/stop` / `hooks/post-tool-use` (execute-bolts surface), `commands/execute-bolts.md`.
**Findings:** 37 verified (10 High, 19 Medium, 8 Low). Severities below use `verdict.final_severity` where downgraded.

---

## 1. Executive verdict

The spec↔code moat itself — the CONFLICT gate and `.validation-blockers.json`, invariant #2 — is **intact at the bolt layer**: it is re-derived at gate time (`hooks/pre-tool-use:397-408`) and survived every tamper probe. But the bolt stage's *own* headline enforcement — the "enforced, not prose" B1 postflight-evidence, B2 batch-suite, and orphan gates — is currently **prose in practice**: all three key on a commit grammar (`(bolt): U-XXX`) that no producer contract ever emits, so they are dormant on every doc-conformant bolt (EB-GATE-2); when they do activate, one plain agent `Write` of an unguarded evidence artifact clears them, with the gate's own remediation text coaching that write (EB-GATE-4), a symbolic `head_sha: "HEAD"` defeats B2 permanently (EB-VAL-1), a python `open(...,'w')` slips the anti-self-bypass guard (EB-GATE-5), and nested/legacy project layouts fork or blind gate truth entirely (EB-GATE-6, EB-VAL-2). Layered on top: a self-contradictory commit topology whose halt texts lie about a secret being "uncommitted" (EB-GATE-3), two aux gate validators that crash-open or structurally false-PASS on non-Laravel stacks (EB-VAL-3, EB-VAL-4), and a migration script that fabricates a "migrated" audit log while changing nothing (EB-HONEST-1). The fix round must restore the plugin's own doctrine — *gates > rules > hooks; prose that says HALT enforces nothing* — by making the six bolt-stage states gate-time re-derived, unifying the commit identity end-to-end, and guarding or generating the evidence artifacts deterministically.

---

## 2. Findings (most-severe first)

### High

**EB-GATE-2 [High] Bolt commit-identity grammar never delivered to producers — B1/B2/orphan gates silently dormant on contract-conformant bolts**
- **Claim:** All three deterministic bolt-commit discoveries key on `(bolt): U-XXX` while every contract surface prescribes `feat(U-XXX):`; the bypass guard keys on an `SDD-PROVENANCE` commit trailer no producer surface ever instructs.
- **Evidence:** regex `\(bolt\):\s*(U-...)` at `scripts/validate-bolt-artifacts.sh:84,:182,:295` vs `references/bolt-dispatch-prompt.md:150`, `references/bolt-contract.md:24`, `references/halts-and-handoff.md:217`; `SDD-PROVENANCE` appears only in consumers (`SKILL.md:108`, `batch-and-fanout.md:106`). Empirical: doc-format fixture → all three modes PASS with `bolt_commits_seen: 0`; amending only the subject flips all three to FAIL.
- **Failure:** Every doc-conformant bolt run ships with zero postflight/orphan/batch-suite enforcement — "enforced, not prose" (`SKILL.md:93,:110`) is empirically inert.
- **Fix:** Pick ONE canonical identity end-to-end. Widen the validator regex to also accept `feat(U-XXX):` and/or a `Unit: U-XXX` git trailer (bolt-implementer.md:25 already emits the trailer); add the `SDD-PROVENANCE` trailer to the canonical commit format in `bolt-contract.md:24` / `bolt-dispatch-prompt.md:150` or re-key the bypass guard on the chosen subject grammar; correct the false "per the execute-bolts commit discipline" comment at `validate-bolt-artifacts.sh:77-78`. Add a fixture test asserting a doc-format commit trips all three gates.

**EB-GATE-4 [High] B1/B2 evidence artifacts unguarded, self-reported-status trusted, and the gates coach the forgery**
- **Claim:** `postflight.json` and `_batch-suite.json` are agent-writable, absent from `_GUARDED`/`PROTECTED`, and the block messages literally instruct writing them ("or write the postflight.json evidence"; "write ... _batch-suite.json {status:green, head_sha:<HEAD>}"). Survives an EB-GATE-1 fix because re-derivation *reads* these artifacts.
- **Evidence:** `validate-bolt-artifacts.sh:334-355` (postflight_ok trusts file), `:234-254` (B2 trusts status green), `:388-389` + `hooks/pre-tool-use:466,469` (coaching); `_GUARDED` at `pre-tool-use:673-679` and `PROTECTED` at `:816` cover only state files. Empirical: one `printf` per artifact flips both gates PASS; hook ALLOWS the writes while DENYING the same write to the guarded state file.
- **Failure:** Both "hard-block" quality gates cleared by one plain Write that the block message itself dictates; falsifies `hard-rule-scan.md:128`, `batch-and-fanout.md:119`, and CLAUDE.md's enforcement inventory.
- **Fix:** Ship deterministic writers (`scripts/run-full-suite.sh` runs the detected runner and writes `_batch-suite.json` with captured counts; equivalent `run-postflight-scan.sh`), add both artifact paths to `_GUARDED` + the `PROTECTED` regex so the wrapper is the only write path, and delete every "or write the ... evidence" clause from next_action/block texts. If honor-system is retained anywhere, relabel CLAUDE.md's inventory from hard-block to attestation.

**EB-VAL-1 [High] B2 permanently defeated by a floating `head_sha` ("HEAD"/branch/"@")**
- **Claim:** `covers()` passes `head_sha` verbatim to `git merge-base --is-ancestor`, so a symbolic rev resolves at validation time — one artifact covers every future commit forever — and the remediation prose (`<HEAD>`) invites writing the literal string.
- **Evidence:** `validate-bolt-artifacts.sh:245-248` (no format check); prose at `:201-204`, `hooks/pre-tool-use:466,469`; pinned intent only at `batch-and-fanout.md:113`. Empirical: `head_sha:"HEAD"` → PASS forever after out-of-band commits; pinned-SHA control → FAIL stale.
- **Failure:** B2 freshness anchor structurally void; silent, permanent.
- **Fix:** In `covers()` require `re.fullmatch(r"[0-9a-f]{40}", head_sha.lower())` before the git call (or rev-parse and require resolved == literal). Update remediation prose at `pre-tool-use:466/469` and the validator next_action to `head_sha: $(git rev-parse HEAD)`.

**EB-GATE-5 [High] Anti-self-bypass Bash guard misses `python open(...,'w')`, `dd of=`, `install` — PROTECTED state files overwritable to forged PASS**
- **Claim:** Guard enumerates removal/redirect verbs but not python file *write*; forged PASS on the non-re-derived states opens the execute-bolts gate.
- **Evidence:** `hooks/pre-tool-use:824-843`; python branch at `:831` matches only removal patterns. Empirical: rm/redirect/tee/cp/sed BLOCKED; python open-write / heredoc / dd / install ALLOWED; full chain demonstrated (FAIL → forged PASS → gate opens).
- **Failure:** B1/B2 (documented hard-blocks) opened over fabricated state via a Bash call the guard never fires on.
- **Fix:** Verb-enumeration is whack-a-mole — the durable fix is EB-GATE-1's gate-time re-derivation of all six states so a forged PASS is overwritten before read. Optionally add a tamper signal via state-file mtime/hash ledger rather than more command patterns.

**EB-GATE-6 [High] `resolve_project_root` returns the NEAREST `.mega-sdd` ancestor while every caller documents "outermost"; validators mint phantom roots — gate truth forks by session cwd**
- **Claim:** First-match walk-up (`scripts/_lib/resolve-project-root.sh:27-33`) + unconditional `mkdir` in `validate-bolt-artifacts.sh:413-414` (file-path mode, fired on every Write) and `validate-factory-ledger.sh:26-31` mint nested/phantom roots; recorded FAILs at the true root become invisible one directory deeper; three live `.mega-sdd` roots exist in this repo.
- **Evidence:** Empirical end-to-end: B2 `batch_suite_red` FAIL at true root → execute-bolts DENIED at root cwd, silently ALLOWED at `root/sub` (nested root), which the gate then populated with its own PASS states (self-perpetuating). `plugins/mega-sdd/.mega-sdd/` carries its own diverging gate-state set.
- **Failure:** A hook-enforced "un-skippable" gate FAIL vanishes when the session cwd sits below a nested root — the exact chain-behavior scenario the helper was built for.
- **Fix:** Make the helper return the OUTERMOST match (or prefer a match containing `config.yaml`/`vaults/`); fallback signals "no root" (rc 1) instead of echoing input; read-side validators SKIP without writing on no-root; add the missing `[ -d .mega-sdd ]` guards to `validate-bolt-artifacts.sh` file-path mode and `validate-factory-ledger.sh`; clean the `plugins/mega-sdd/scripts/.mega-sdd` litter; have `/mega-sdd:analyze` flag nested `.mega-sdd` dirs as corruption.

**EB-VAL-2 [High] All three bolt-artifact modes discover only the canonical `.mega-sdd/vaults/*` layout — legacy layouts fail B1/orphan OPEN and B2 permanently false-CLOSED**
- **Claim:** Unit/report/postflight/_batch-suite lookups (`validate-bolt-artifacts.sh:89-97,:224,:299-305,:336`) are canonical-only, while v4.58's `validate-unit-spec.sh:737-756 discover_units()` covers 10 layouts including `docs/mega-sdd/vaults/**` and `*-bound/` (S5R-3 mandate).
- **Evidence:** Empirical: legacy-layout fixtures PASS both fail-open gates where the canonical layout FAILs; a genuinely green `_batch-suite.json` at the legacy path leaves B2 unclearable FAIL.
- **Failure:** Zero Hard-rule/audit enforcement on legacy-layout projects; unclearable false block on B2.
- **Fix:** Factor `discover_units()`'s pattern list (plus a parallel bolts-dir list) into a shared helper consumed by `unit_file`/`unit_exists`/`report_exists`/`postflight_ok` and the `_batch-suite.json` collector; or fail CLOSED with a distinct `unit_unlocatable` issue when `bolt_commits_seen > 0` but the unit cannot be located.

**EB-GATE-3 [High] Commit-ordering contract self-contradictory: implementer commits pre-gate while every halt text claims code is "left uncommitted" — "HALTS the commit" is structurally false**
- **Claim:** `agents/bolt-implementer.md:25,:44` and `superpowers-bridge.md:51-52` commit before gates (panel diffs base..head SHAs, `review-panel.md:51`), yet `code-gates.md:3,:47,:54`, `hard-rule-scan.md:93,:148`, `review-panel.md:69`, `SKILL.md:4,:85` all claim pre-commit halts. Secret-in-code halt tells the user the secret never shipped while it sits in an immutable commit.
- **Evidence:** Empirical: `scan-secrets-code.sh` is commit-range-only (`:29,:48`) — an UNCOMMITTED secret scans CLEAN (gate cannot fire in the documented topology); a committed secret fires the halt with a clean working tree, contradicting the halt YAML. Also plural `commits:` in the bolt-report schema (`superpowers-bridge.md:105`) vs "ONE COMMIT" discipline.
- **Failure:** Misdirected security remediation — the documented next_action leaves the secret in pushable history.
- **Fix:** Pick ONE topology and align every surface: (a) implementer stages but does NOT commit — controller commits after L0+panel+post-flight, lenses diff base..working-tree; or (b) keep subagent commits and rewrite every halt text to honest detect-after semantics (revert/rewrite; `secret_in_code` → rotate + history-purge before push). Add a pin test asserting a single topology across `bolt-implementer.md` / `superpowers-bridge.md` / `code-gates.md` / `hard-rule-scan.md` / `SKILL.md`.

**EB-VAL-3 [High] validate-factory-ledger: string/null `attempt` crashes (exit 2) WITHOUT rewriting state — stale PASS persists, both Factory Line gates fail open over a real `phase_stuck` breach**
- **Claim:** Presence-only schema check (`validate-factory-ledger.sh:79-82`); `max_attempt >= cap` at `:106` raises TypeError on string attempts; bare `except` at `:139-140` exits 2 without `write_and_exit`; consumers (`pre-tool-use:244` with `|| true`, `:520-524`) trust the stale PASS.
- **Evidence:** Empirical A/B: int-attempt control → deny; string-attempt identical ledger → gate silently open, state still PASS. State write also non-atomic (`:46-48`).
- **Failure:** Model-emitted stringified numbers (routine) neutralize both directions of a gate advertised as enforced.
- **Fix:** Type-coerce/validate `attempt` in the schema pass (`int(...)` else schema_errors); wrap analysis so any unexpected exception writes a FAIL state (`halt_type: ledger_error`) via `write_and_exit` before exit 2; make the state write atomic (tmp + `os.replace`).

**EB-VAL-4 [High] validate-cross-cutting-registration hardcodes Laravel discovery under a "hardcodes NO stack signature" header — structural false PASS on slim/symfony packs (0 files scanned, positive attestation)**
- **Claim:** `TABLE_DECL_RE = Schema::(create|table)` / `MODEL_TABLE_RE = \$table` (`validate-cross-cutting-registration.sh:177-178`) vs header `:22-26`; `:240 if not scoped_tables: continue` → `:275` PASS with "every branch-scoped model registers the concern".
- **Evidence:** Empirical: slim fixture with missing JWT middleware registration and symfony fixture with unenforced voter both PASS (`model_files_scanned: 0`); Laravel control with the identical defect FAILs.
- **Failure:** The exact 2bdcf1b silent-leak class the gate exists to catch ships on 100% of non-Laravel scan-eligible packs; the false PASS affirmatively opens execute-bolts.
- **Fix:** Move discovery signatures into the pack schema (per-concern `source_decl_regex` + `target_binding_regex`), Laravel regexes as the laravel-chain fallback only; when discovery yields zero sources emit per-concern `not_evaluable` and overall SKIP (never PASS) so `/mega-sdd:analyze` surfaces it.

**EB-HONEST-1 [High] migrate-v1-rules.sh fabricates a "migrated" audit log while modifying nothing; rejects the documented `--to` flag; misses the NAMING_RULE production; aborts on non-tty leaving .tmp litter**
- **Claim:** The scaffold logs `## U-XXX — migrated` and prints "v2 YAML blocks emitted in place" with byte-identical files — fabricated attestation (moat invariant #5); `commands/migrate-rules.md`'s hard rails ("Migration NEVER silent", "Failed v2 validation HALTS") have no implementation.
- **Evidence:** `skills/execute-bolts/scripts/migrate-v1-rules.sh:76-89` (unconditional log), `:16-22` (no `--to=`), `:52-56` (awk misses `MUST follow ... naming`), `:71` (`read -p` under `set -euo pipefail`). Empirical: sha256 identical before/after; `--to=v2` → "Unknown flag" exit 1; `</dev/null` → exit 1 + orphaned `.migration-log.md.tmp`.
- **Failure:** Permanent false audit record; NAMING_RULE units left unmigrated as exactly the mixed-grammar mix `hard-rule-scan.md:24` halts on.
- **Fix:** Log `detected`/`delegated-to-skill`, never `migrated`, unless a content-hash diff proves v2 YAML landed (or make the script do the transform + validate); implement or delete `--to=` in the command doc; add the naming/signature/exists branches to the detector; tty-guard `read -p` (require `--auto-confirm` otherwise); write the log via trap.

### Medium

**EB-GATE-1 [Medium — DOWNGRADED] Six bolt-stage/quality hard-block states read STALE at the execute-bolts gate — no gate-time re-derivation, absent-state fail-open, same-turn TOCTOU**
- **Claim:** v4.58 re-derives only the moat + unit-trio (`pre-tool-use:397-409`); `.bolt-orphans` / `.batch-suite-gate` / `.bolt-postflight` / `.ui-quality-blockers` / `.cross-cutting` / `.factory-ledger` states are read via fail-open `L()` (`:450-524`). First run of a fresh session/clone is ungated; same-turn `--auto` chained dispatches read pre-turn truth; terminal run never gated; ui-quality/cross-cutting refresh only on Write/Edit glob matches (`post-tool-use:64-67,:473,:489` — heredoc/ERB/Symfony-entity writes keep stale PASS).
- **Downgrade rationale:** Anti-self-bypass covers agent seeding of all six files; the one-turn lag is documented design (`batch-and-fanout.md:119`); the moat is re-derived and unaffected. Residual agent-reachable exposure is real but narrow.
- **Fix:** Extend the v4.58 precedent: in the execute-bolts gate block, also run `validate-bolt-artifacts.sh --orphan-scan / --batch-suite-gate / --postflight-scan` (git-bounded, sub-second) and re-run validate-ui-quality / validate-cross-cutting / validate-factory-ledger project-wide. This also neutralizes EB-GATE-5's forge for these states. Refactor BSG's per-commit `git show` loop (`:180-193`) into one `git log --name-status` pass; fix the false "re-derives" claim in the deny message (`:684`).

**EB-GATE-7 [Medium — DOWNGRADED] Framework-pack Hard-rule chain of custody broken: packs emit a 7-type prose grammar the bolt scan cannot execute; scan doc cites a pack ast-grep block no pack contains; producer contract guarantees mixed-grammar units**
- **Evidence:** `hard-rule-scan.md:134` phantom "ast-grep rule: block from the pack" (zero packs contain ast-grep YAML); rule_type inventory (92 CUSTOM, 39 NAMING_RULE regex, ...) has no v1 production (`unit-schema.md:203-219`); `validation-passes.md:64-83` (12.4.5, fenced YAML) vs `:108` (12.5b, every line MUST be v1) three-way contradiction; a mixed unit passes `validate-unit-spec.sh` (empirical PASS) and reaches the documented `hard_rule_mixed_grammar` halt.
- **Downgrade rationale:** The halt and the pack-rule execution are prose-only (zero hits in scripts/hooks); fail direction is closed with a documented recovery; moat unaffected. Docs/design defect.
- **Fix:** Define an explicit pack→bolt translation table per rule_type (NAMING/LOCATION → filename-regex probe; DEP_RULE → manifest diff; CUSTOM/SECURITY/PERFORMANCE → advisory Anti-pattern, never Hard rule); delete the phantom sentence at `hard-rule-scan.md:134`; make 12.4.5 emit ONE grammar (v2 YAML) per unit, converting binding v1 suggestions at emission.

**EB-GATE-8 [Medium] B1 obligation erased by a retroactive, unprotected unit edit** — `validate-bolt-artifacts.sh:366-369` reads the unit's CURRENT text; flipping `task_type: verify` or blanking `## Hard rules` to "None." makes the next Stop re-scan overwrite FAIL→PASS (reproduced both ways). Unit specs are not in `_GUARDED` (`pre-tool-use:673-679`). **Fix:** Snapshot obligations at detection (sticky_obligations map cleared only by passing postflight.json), or read unit content from the bolt commit via `git show <sha>:<unit-path>`.

**EB-GATE-11 [Medium] No deterministic target_files whitelist observer** — a scope-escaping bolt write ships undetected (post-flight is path-scoped; empirical: escaped `src/B.php` passes postflight-scan, file-path mode, orphan-scan; zero `target_files` logic in hooks). Prose is honest (`SKILL.md:122`). Both observer halves already exist (`validate-bolt-artifacts.sh:183` per-commit file enumeration; `:450-499` target_files walker). **Fix:** Add `--whitelist-scan` (or extend `--postflight-scan`): diff committed paths per bolted (uid,sha) against `unit.target_files ∪ {<vault>/bolts/U-XXX/**, .mega-sdd/**}`; residue → `whitelist_violation` in a state the existing PreToolUse aggregator reads; wire into Stop; add the state basename to anti-self-bypass. **Depends on the EB-GATE-2 grammar fix or it is equally dormant.**

**EB-GATE-12 [Medium] Unit gate legalizes directive-prose Hard rules the bolt contract must halt as `hard_rule_unparseable`; B1 then demands verdicts no documented check can produce** — `validate-unit-spec.sh:450,:491-492` accepts directives; `hard-rule-scan.md:29` mandates the halt; fabricated `{"type":"DIRECTIVE","verdict":"pass"}` satisfies B1 (reproduced). Incidental: unit-spec's Check-2 heading regex (`:438`) fails on the canonical template heading, silently skipping the whole grammar check. **Fix:** Pick one truth — add a `directive` category to hard-rule-scan.md (post-flight = panel attestation recorded as verdict `attested`, accepted by `postflight_ok()` for directive lines only), or route directives to `## Anti-patterns` with WARN. Also fix the Check-2 heading regex to tolerate the template's parenthetical.

**EB-VAL-8 [Medium] B1's `has_hard_rules` counts HTML comments/placeholders as rules** — strip set `[`*_>\-\s]` (`validate-bolt-artifacts.sh:325-332`) leaves `<!--...` as a "rule" while `validate-unit-spec.sh:468` skips `<`-prefixed lines; a schema-conformant no-rules unit FAILs B1 and the coached front-doors are fabrication or a blocked re-run (SKILL.md:43's `--force-skip-postflight` follow-up circles into the gate). **Fix:** Align `has_hard_rules` with the unit-stage lexer (skip `<`-prefixed lines); allow one gate-pass when the current invocation targets a unit listed in the B1 FAIL issues (re-run-to-heal).

**EB-GATE-10 [Medium] Panel Critical has no terminal halt type, no machine trace; canonical bolt-report schema omits the mandated `## Review panel` section** — `review-panel.md:64-67` + `code-gates.md:52` + `superpowers-bridge.md:72` mandate the section; the schema (`superpowers-bridge.md:99-123`) lacks it; `halts-and-handoff.md` has zero panel halts; no validator checks anything panel-shaped. **Fix:** Add `review_critical_unresolved` to halts-and-handoff.md mirroring `test_fail`; add `## Review panel` (tier, lenses, findings, dropped count) to the canonical schema; cheap observer in `--postflight-scan` flagging a committed bolt whose report lacks the section or records an unresolved Critical.

**EB-VAL-5 [Medium] Nested-project-in-monorepo: repo-root-relative git names defeat the `.mega-sdd/` code filter** — state-only commits invalidate a pinned green suite (false B2 FAIL, reproduced; control at repo root PASSes) and the unscoped `-300` log walk lets sibling projects' `(bolt):` commits activate this project's gates. **Fix:** Compute prefix via `git rev-parse --show-prefix`, compare against `prefix + '.mega-sdd/'` in `code_files()` (`validate-bolt-artifacts.sh:161`); scope all log walks (`:79,:175,:290`) with `-- <prefix>`.

**EB-VAL-6 [Medium] ui-quality's one-segment-strip glob retry scans outside the pack view_glob** — `validate-ui-quality.sh:139`; a scaffold tell in `backup/resources/views/legacy.blade.php` hard-blocks execute-bolts (reproduced through the real hook). **Fix:** Drop the strip retry or restrict it to declared workspace roots; at minimum add backup/old/tmp/docs/test-fixture wrappers to `SKIP_DIRS` (`:344`). Same pattern exists in `validate-flow-coverage.sh:160` — audit together.

**EB-HONEST-2 [Medium] validate-ui-deferral.sh claims it "blocks the NEXT execute-bolts" while ui-deferral is advisory-only** — `validate-ui-deferral.sh:17-18,:204-208` vs `pre-tool-use:379-381` (DEMOTED) and an aggregator that never reads `.ui-deferral-state.json`; `post-tool-use:641-643` cites a nonexistent "PreToolUse Branch 13". **Fix:** Rewrite the header + emitted reason to "ADVISORY — surfaced via /mega-sdd:analyze as WARN; does NOT block execute-bolts"; fix the post-tool-use comment.

**EB-HONEST-3 [Medium] context-enrichment + post-tool-use claim dispatch-prompt UI enrichment is "non-no-op-able" via a validator that was demoted to advisory** — `context-enrichment.md:154,:305`; `post-tool-use:500-503` ("PreToolUse Branch 9 reads its status" — no Branch 9 exists; zero reads of `.dispatch-prompt-state.json` in pre-tool-use). **Fix:** Rewrite all three spots to "advisory — surfaced by /mega-sdd:analyze" (matching CLAUDE.md's inventory), or re-promote the check into the aggregator via spec if the "kuno UI" regression justifies a hard block.

**EB-PHANTOM-1 [Medium] Phantom per-lens model override** — `review-panel.md:23` claims "Models are NEVER hardcoded" and the override chain "applies per lens", but all five lens agents pin `model:` in frontmatter (the value actually used) and nothing consumes `model_tiers` at panel dispatch; a documented `model_tiers: {security-reviewer: sonnet}` is silently ignored at 2x cost. **Fix:** Make the docs honest (panel models pinned in frontmatter; `model_tiers` does not apply to the panel; catalog↔frontmatter match is a release-time obligation) or implement the override via a general-purpose subagent carrying the lens body. Delete/scope the "NEVER hardcoded" sentence (also in the design spec `:51`).

**EB-PHANTOM-2 [Medium] `ast-grep test --validate` does not exist** — `hard-rule-scan.md:27` instructs it; sibling `hard-rule-grammar-v2.md:111` says verbatim the flag does not exist and prescribes parse-via-scan; empirically errors (exit 2) on ast-grep 0.42.3. Compliant agents spuriously halt every v2 unit. **Fix:** Replace `hard-rule-scan.md:27` with the parse-via-scan snippet, or point at hard-rule-grammar-v2.md §Pre-flight as single owner.

**EB-DOC-1 [Medium] Iron Rule 4 attests "the reuse-index path is in your prompt" but the canonical dispatch-prompt template has zero reuse content** — `bolt-dispatch-prompt.md` (372 lines, grep 'reuse' = 0) vs `context-enrichment.md:30-32,:61,:88-105` (unconditional T1 line + never-dropped T2 slice) and `agents/bolt-implementer.md:16`. Instincts slice also slotless. **Fix:** Add to the template: T1 line `Reuse index: .mega-sdd/codebase/reuse-index.yaml — your PRIMARY reuse lookup surface`, a `### Reuse index (filtered slice)` T2 section, the instincts slot under §Historical memory, and Contents entries for all three.

**EB-DOC-3 [Medium] --parallel overlap rail exists only in SKILL.md:25** — `batch-and-fanout.md:17,:25` and `squad-subagent.md` step 4 define concurrency purely by `depends_on`, and cross-squad units carry no `depends_on` edges by design (`squad-subagent.md:72-73`) — two units sharing `routes/web.php` co-wave into a silent clobber. **Fix:** Copy the one-sentence rail ("independent = no depends_on edge AND pairwise-disjoint target_files") into `batch-and-fanout.md` steps 3/4 and `squad-subagent.md` step 4 (and SKILL.md's `--per-squad` bullet at `:31`).

**EB-DOC-4 [Medium] spec-reviewer carries a stale pre-panel body** — `agents/spec-reviewer.md:9` says the implementer's report is in its prompt (blind protocol forbids: `review-panel.md:52`, `superpowers-bridge.md:66`); it is the only lens with no base/head-SHA/diff instruction despite owning the nothing-extra/target_files check; zero body pins in `tests/review-panel/test-panel-agents.sh`. **Fix:** Rewrite the body to the panel-era input contract (unit body + SHAs + deterministic scan results; NOT the report; `git diff base..head` for nothing-missing/extra); add spec-reviewer to the pin test with a negative report pin + diff-instruction pin.

**EB-DOC-5 [Medium] Bolt-stage halted enum drifted three ways** — operative 6-type list (`halts-and-handoff.md:371`) omits ~12 documented halts; `handoff-contract.md:433` (12) vs `:624` (14) contradict; `commit_rejected_by_hook`/`batch_suite_red`/`hard_rule_mixed_grammar` in NO enum or halt-taxonomy.md; `bolt_introduces_locked_drift` eligibility contradicted across four surfaces incl. the fix-proposer template's hard-coded refusal (`propose-and-confirm-prompt.md:5-8,:75,:173`). **Fix:** One canonical bolt-halt enum in halts-and-handoff.md (union of its table + saga + batch refs); regenerate handoff-contract's per-skill block and halt-taxonomy from it; resolve locked-drift to one eligibility everywhere (add to the template with evidence sources, or downgrade to override-only in `SKILL.md:87` + the table).

**EB-DOC-6 [Medium] Canonical bolt-report schema lacks MANDATORY `target_hashes` and the `halted_postflight`/`forced_pass` statuses** — `superpowers-bridge.md:99-123` vs `SKILL.md:70`, `halts-and-handoff.md:276-281`, `hard-rule-scan.md:150`, `propose-and-confirm-prompt.md:149`; `compute-unit-staleness.sh:68-70` silently returns `unknown` — the living-vault staleness anchor never engages for schema-conformant reports. **Fix:** Add mandatory `target_hashes` (sha256-at-commit), optional scope, widen the status enum — or make halts-and-handoff.md §Outputs the single schema owner. Fold in the `## Review panel` section (EB-GATE-10) in the same edit.

**EB-DOC-7 [Medium] Unit `risk:` frontmatter never consumed by panel tier selection; stale create/extend/modify enum in two surfaces** — `review-panel.md:39-45` re-derives risk from 5 narrower signals (no PII/regulatory/LOCKED); a `risk: critical` unit can match the minimal spec-only tier. `SKILL.md:93` + `hard-rule-scan.md:128` say "create/extend/modify" vs closed enum `{create, verify, extend}` (`unit-schema.md:27`). **Fix:** Add signal 6: frontmatter `risk: high|critical` forces full tier (log disagreements); correct the two enum phrases.

### Low

**EB-GATE-9 [Low — DOWNGRADED] No anchor-freshness rail at implement time** — bind-era `[HIGH]` labels re-stamped mid-batch with no freshness caveat (`context-enrichment.md:83`); no `anchor_stale` halt type; `halts-and-handoff.md:214` advertises "Anchors verified 3/3 ✓" with no backing check. Downgraded: Iron Rule 2 + BLOCKED/NEEDS_CONTEXT escalation contradict the fabrication theory; downstream rails bound blast radius. **Fix:** Cheap assembly-time assert (anchor path exists; region matches when binding recorded excerpt/sha) → inject "ANCHOR STALE (verify before use)" instead of `[HIGH]`; fix the `:214` prose.

**EB-DOC-2 [Low — DOWNGRADED] Two halt/report vocabularies for the same subagent** — dispatch prompt's 5 typed blocker YAMLs (`bolt-dispatch-prompt.md:49-66`) vs the agent's DONE/BLOCKED/NEEDS_CONTEXT enum; 3 of 5 types orphaned from eligibility tables; `missing_dependency` duplicates canonical `dep_missing`. Downgraded: pause-by-default fallback makes routing correct either way; no deterministic consumer of `blocker.type`. **Fix:** Define the mapping once in bolt-implementer.md's Report format; add the three types to the NOT-eligible (pure-pause) list; rename `missing_dependency` → `dep_missing`.

**EB-VAL-7 [Low — DOWNGRADED] UI-bearing classifier misses some template ecosystems** — real residual gap is essentially ASP.NET (`.cshtml`/`.razor`, capitalized `Views/`) + scss/less-only units; Phoenix/Astro have no packs (outside support surface); signature-less-pack SKIP is documented by-design. **Fix:** Extend the universal shapes list (`context-enrichment.md:181-184`) with the missing extensions + segment-anywhere globs; add a "design lens: skipped (not ui-bearing: <detail>)" note to bolt-report `## Review panel`.

**EB-PHANTOM-3 [Low] Phantom `--strict-provenance` flag** — only occurrence in the plugin is the message itself (`validate-bolt-artifacts.sh:590`). **Fix:** Delete the flag clause from the next_action.

**EB-VAL-9 [Low] File-path mode epilogue defects** — IGNORECASE cite regex vs case-sensitive compare (`:554` vs `:567`, false `pbt_citation_invalid` on `§d-001`); only non-atomic state write in the file (`:595-599`); single-slot state flips FAIL→PASS on any later unrelated run; dead ":594 read prior state" comment. Telemetry-only blast radius. **Fix:** Uppercase-normalize both sides; tmp+`os.replace`; merge per-file results into a project-wide issues map (v4.58 unit-spec pattern) or delete the comment.

**EB-VAL-10 [Low] cross-cutting parses only the FIRST yaml fence of the pack chain** — `validate-cross-cutting-registration.sh:101-109` vs the resolver's multi-block emission (`resolve-framework-pack.sh:251-254`); latent until any project pack declares the section (A/B reproduced). Sibling was explicitly hardened (`validate-ui-quality.sh:172-177`). **Fix:** All-fences union with dedup-by-id, first occurrence wins; audit the same `first_yaml_block` pattern in `validate-sibling-consistency.sh:109` and `validate-flow-coverage.sh:197`.

**EB-HONEST-4 [Low] "Read-only" lens claim unenforced** — all five reviewers carry unrestricted Bash, no body do-not-mutate rail; pin test (`tests/review-panel/test-panel-agents.sh:13`) checks only Write/Edit absence. **Fix:** Add one body rail per lens ("never Write/Edit; never run a Bash command that mutates tree, index, or history — git diff/log/show only") + a pin-test assertion. Bash must stay (git diff needs it).

**EB-DOC-10 [Low] CLI-entry flag drift** — `commands/execute-bolts.md:3` omits `--review-panel=`/`--no-code-gates`/`--no-full-suite` (defined `SKILL.md:32-34`); `--no-empty-commits` (`SKILL.md:97`, `hard-rule-scan.md:175`) and `--no-drift-check` (`chain-execution.md:215`) declared nowhere. **Fix:** Add the five flags to the command argument-hint + body; declare the two undeclared flags in SKILL.md Inputs.

---

## 3. Batch plan

Batches are independently shippable, but **the canonical commit-identity decision (EB-GATE-2) and the commit-topology decision (EB-GATE-3) must be made first** — they parameterize edits in every batch.

### Batch 6A — Gate/hook truth (the enforcement spine)
Restore "gates > rules > hooks" at the execute-bolts gate itself.
- **EB-GATE-1**: gate-time re-derivation of all six bolt-stage/quality states (also neutralizes **EB-GATE-5**'s forge vector for them); fix the false claim in the deny message; refactor BSG's git-show loop for speed.
- **EB-GATE-4** (guard half): add `postflight.json` + `_batch-suite.json` paths to `_GUARDED` + `PROTECTED`; ship `scripts/run-full-suite.sh` / `run-postflight-scan.sh` as the only write path; strip the forgery-coaching text.
- **EB-GATE-6**: outermost-match `resolve_project_root`, rc-1 no-root fallback, skip-not-mkdir on read-side validators, `-d` guards in file-path mode + factory-ledger, litter cleanup, analyze corruption flag.
- **EB-GATE-8**: sticky obligations / `git show <sha>:<unit-path>` snapshot for B1.
- **Files:** `hooks/pre-tool-use`, `hooks/post-tool-use`, `scripts/_lib/resolve-project-root.sh`, `scripts/validate-bolt-artifacts.sh`, `scripts/validate-factory-ledger.sh`, `scripts/validate-ui-quality.sh`, `scripts/validate-cross-cutting-registration.sh`, new `scripts/run-full-suite.sh` + `scripts/run-postflight-scan.sh`, `plugins/mega-sdd/CLAUDE.md` (enforcement inventory).

### Batch 6B — Validator correctness
Make the validators compute the truth they claim.
- **EB-GATE-2** (validator half): widen the discovery regex to the canonical grammar (`feat(U-XXX):` and/or `Unit:` trailer); fix the false comment at `:77-78`.
- **EB-VAL-1**: 40-hex `head_sha` fullmatch in `covers()` + rev-parse remediation prose.
- **EB-VAL-2**: shared `discover_units()`-derived layout helper for unit/report/postflight/_batch-suite lookups (or `unit_unlocatable` fail-closed).
- **EB-VAL-3**: type-coerce `attempt`, `write_and_exit` on exception, atomic state write.
- **EB-VAL-4**: pack-schema discovery regexes + `not_evaluable`/SKIP-never-PASS.
- **EB-VAL-5**: `--show-prefix` scoping of code filter + log walks.
- **EB-VAL-6**: drop/restrict the one-segment-strip retry + SKIP_DIRS wrappers (also audit `validate-flow-coverage.sh:160`).
- **EB-VAL-8**: align `has_hard_rules` lexer (skip `<`-prefixed) + re-run-to-heal gate pass.
- **EB-VAL-9**, **EB-VAL-10**, **EB-PHANTOM-3**: epilogue fixes, all-fences union, delete phantom flag clause.
- **Files:** `scripts/validate-bolt-artifacts.sh`, `scripts/validate-factory-ledger.sh`, `scripts/validate-cross-cutting-registration.sh`, `scripts/validate-ui-quality.sh`, `scripts/validate-flow-coverage.sh`, `scripts/validate-sibling-consistency.sh`, `scripts/validate-unit-spec.sh` (shared helper export + Check-2 heading regex from EB-GATE-12), `scripts/_lib/resolve-framework-pack.sh` consumers, `references/framework-conventions/*.md` (pack schema keys).

### Batch 6C — Contract/docs honesty and coherence
One truth per contract; delete every claim of nonexistent enforcement.
- **EB-GATE-3**: pick the commit topology, rewrite `bolt-implementer.md` / `superpowers-bridge.md` / `code-gates.md` / `hard-rule-scan.md` / `SKILL.md` / `batch-and-fanout.md` to it (incl. honest `secret_in_code` remediation).
- **EB-GATE-2** (docs half): align `bolt-contract.md:24` / `bolt-dispatch-prompt.md:150` / `bolt-implementer.md:25` / `halts-and-handoff.md:217` to the canonical grammar + `SDD-PROVENANCE` decision.
- **EB-GATE-7**: pack→bolt translation table; delete `hard-rule-scan.md:134` phantom; single-grammar 12.4.5 emission.
- **EB-GATE-10** + **EB-DOC-6**: one canonical bolt-report schema (target_hashes, widened status enum, `## Review panel` section) with a single owner; `review_critical_unresolved` halt type.
- **EB-DOC-5**: canonical halted enum + regenerated handoff-contract/halt-taxonomy blocks + locked-drift eligibility resolution.
- **EB-HONEST-1**: migrate-v1-rules.sh honest logging + `--to` + detector + tty guard; align `commands/migrate-rules.md`.
- **EB-HONEST-2/3**, **EB-PHANTOM-1/2**, **EB-DOC-1/2/3/4/7/10**, **EB-GATE-9/12** prose legs, **EB-VAL-7** shapes list.
- **Files:** `skills/execute-bolts/SKILL.md` + all `references/*.md` (hard-rule-scan, bolt-dispatch-prompt, bolt-contract, superpowers-bridge, review-panel, halts-and-handoff, batch-and-fanout, context-enrichment, squad-subagent, code-gates, propose-and-confirm-prompt, hard-rule-grammar-v2), `agents/bolt-implementer.md`, `agents/*-reviewer.md`, `commands/execute-bolts.md`, `commands/migrate-rules.md`, `skills/execute-bolts/scripts/migrate-v1-rules.sh`, `scripts/validate-ui-deferral.sh`, `references/model-tiers.md`, `skills/generate-units/references/validation-passes.md` + `unit-schema.md` (12.4.5/12.5b reconciliation).

### Batch 6D — Tests + new observers (backlog)
Pin what 6A-6C fixed; ship the invited-gap observer.
- **EB-GATE-11**: `--whitelist-scan` mode + Stop wiring + aggregator read + anti-self-bypass entry (requires 6B's grammar fix).
- Fixture tests: doc-format commit trips B1/B2/orphan (EB-GATE-2); forged-artifact writes denied (EB-GATE-4); symbolic `head_sha` rejected (EB-VAL-1); legacy-layout parity (EB-VAL-2); string-attempt ledger FAILs closed (EB-VAL-3); slim/symfony `not_evaluable` (EB-VAL-4); nested-root outermost resolution (EB-GATE-6).
- Pin tests: single commit topology across the five surfaces (EB-GATE-3); spec-reviewer negative-report + diff-instruction pins and read-only body rails for all five lenses (EB-DOC-4, EB-HONEST-4) in `tests/review-panel/test-panel-agents.sh`.
- **Files:** `tests/` (new bolt-gate fixture suite), `tests/review-panel/test-panel-agents.sh`, `scripts/validate-bolt-artifacts.sh`, `hooks/stop`, `hooks/pre-tool-use`.

---

## 4. Explicitly NOT defects (do not "fix" these)

Verifiers cleared the following as advisory-by-design or intended behavior. The fix round must not regress them:

1. **The moat/CONFLICT gate re-derivation is intact.** `.validation-blockers.json` is re-derived at gate time (`pre-tool-use:398`) and immune to state forgery — preserve this exact pattern when extending re-derivation to the six bolt states.
2. **One-turn Stop-hook lag is documented design.** "Blocks the NEXT execute-bolts" (`batch-and-fanout.md:119`) is the contract; do not attempt synchronous Stop-time gating — the fix is gate-time re-derivation, not hook-timing changes.
3. **User-shell overrides of state files are permitted.** The anti-self-bypass guard constrains the *agent*, not the user; do not extend it to block human shell operations.
4. **Advisory demotion of ui-deferral and dispatch-prompt is doctrine-compliant.** The defect (EB-HONEST-2/3) is only the prose claiming blocks that do not exist. Fix the prose; do not silently promote either to blocking without a spec-first decision.
5. **ui-quality SKIP for packs without UI signatures is by-design** (`_universal.md:273-280` — "a stack is never blocked for a UI convention it never declared"). EB-VAL-7's fix is broader shapes + a skip-honesty note, not forcing the gate on signature-less packs.
6. **The target_files whitelist being prompt-tier is honestly documented** (`SKILL.md:122`, `unit-schema.md:258` — "no deterministic post-hoc observer yet"). If Batch 6D's observer slips, keep the honest wording; do not add enforcement claims ahead of the code.
7. **The panel severity gate as conductor prose is honest** ("Gate, not hook"). EB-GATE-10's fix adds the missing halt type and schema section; it does not require hook-enforcing panel verdicts.
8. **Reviewer agents must keep Bash.** Read-only enforcement (EB-HONEST-4) is a body rail + pin test; removing Bash would break `git diff base..head`, which the lenses need.
9. **Fail-closed false blocks (EB-VAL-5, EB-VAL-2's B2 leg, EB-VAL-6) never shipped unvalidated code.** Fixes must preserve the fail-closed direction — scope the inputs correctly rather than loosening the gates.
10. **Panel lens frontmatter models currently match the model-tiers catalog defaults** (EB-PHANTOM-1). Only the *override* claim is phantom; keeping catalog↔frontmatter parity as a release-time check is the minimal honest fix.
11. **BLOCKED/NEEDS_CONTEXT vs typed blocker YAMLs are complementary layers with a pause-by-default fallback** (EB-DOC-2 downgrade). The fix is a documented mapping + enum hygiene, not collapsing the two vocabularies.
12. **Iron Rule 2 + escalation statuses already forbid anchor fabrication** (EB-GATE-9 downgrade). The anchor-freshness rail is a transparency improvement (STALE downgrade note), not a missing moat gate.