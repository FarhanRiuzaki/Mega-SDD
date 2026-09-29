# execute-bolts Trigger Test

## Trigger cases

### E1: Explicit unit ID
- **Prompt:** `/mega-sdd:execute-bolts U-001`
- **Expect:** Skill invoked

### E2: --all
- **Prompt:** `/mega-sdd:execute-bolts --all`
- **Expect:** Skill invoked with topo-sort over all units

### E3: Indonesian
- **Prompt:** `jalanin unit semua`
- **Expect:** Skill invoked

## Pre-flight checks

### P1: No superpowers installed (v7.4.0 — no vendored fallback exists)
- **Setup:** uninstall superpowers
- **Expect:** the run uses the built-in inline loop (`references/inline-run.md` (c)); NO halt, NO install demand

### P2: Superpowers installed
- **Setup:** real install present
- **Expect:** the run invokes `superpowers:executing-plans` with the plan path (`references/inline-run.md` (c)); no agent dispatch

## Behavior

Mode: every run is inline (BI1, BI2, BI4, BH6); the per-unit `--agents` path is retired (spec v9 §8.6).

### BI1: the default run executes every unit in this session from a generated plan
- **Setup:** a layout-3 vault with U-001..U-004; U-003 has an open CONFLICT, U-004 `depends_on: [U-003]`
- **Prompt:** `/mega-sdd --guarded` (forwarded as `execute-bolts --all --lite`); `/mega-sdd --guarded --inline` (forwarded as `execute-bolts --all --lite --inline`) behaves identically — `--inline` is a no-op alias
- **Expect:**
  - the announce line ends with `mega-sdd-trace:execute-bolts`
  - `derive-exec-plan.sh --pending` → `rebind-units.sh --units=<pending>` → `derive-exec-plan.sh`: U-003 `binding_conflict`, U-004 `depends_on_quarantined` in ONE `Karantina:` chat line; the plan names U-001, U-002 only
  - no verdict is ever hand-written and `binding.json` is never edited (hook-guarded); each task re-binds (a CONFLICT there → `write-unit-quarantine.sh`, dependents skipped, the run continues), tests first, commits with the canonical trailers, then commits its evidence (`chore(sdd): evidence U-XXX`)
  - ONE blind review of `run_base..HEAD` (no `.mega-sdd/` in its package, the trace line on its own line), `delivery-check.sh` `VERDICT: PASS`, the run-boundary gate with `--conflict-bypass-scan` exits 0 before the result contract

### BI2: the inline run never launders a CONFLICT
- **Setup:** as BI1, the model commits U-003 anyway, then re-binds it (the commit created the file the CONFLICT claimed)
- **Expect:** the run-boundary gate FAILS `closed_conflict` for U-003 (and U-004 via U-003 if committed); the result is never reported done; the remedy offered is `resolve-oq --binding` (the human decides the closed episode in the one-screen shape: the claim, the code reality with `file:line`, KEEP_VAULT / KEEP_CODE / SPLIT; it writes `write-unit-binding.sh --resolve=<claim-id>=<ACTION> --by=user`) — never another re-bind

### BI4: the close re-binds a leftover own_wip CONFLICT
- **Setup:** a resumed run: U-011's own test file was untracked with its provenance header at the task's re-bind (CONFLICT `own_wip`); the unit then committed and finished its evidence
- **Expect:** (d)6 `derive-exec-plan.sh --rebind-wip` (before the run evidence commit) prints `rebound: ["U-011"]`, U-011's binding re-reads CONFIRMED and the `chore(sdd): evidence run` commit carries it, so the (d)7 gate sees it; (d)8 `--retire` then re-binds nothing. Had that re-bind left another CONFLICT, `--rebind-wip` exits 1 (`scope: close`) naming it, a `Close: halt` ledger line keeps it named, `--retire` refuses too and nothing is retired — the human decides it via `resolve-oq --binding`; re-invoking `execute-bolts` resumes at (d)4 (`Close: reviewed`), never a second review
- **`--dry-run`:** the plan is shown, then `--retire --dry-run` removes it and re-binds nothing

### BH1: target_files whitelist enforced
- **Setup:** unit has `target_files: [src/foo.ts]`; implementation step tries to edit `src/bar.ts`
- **Expect:** halt before write

### BH2: Test failure → retry → halt
- **Setup:** unit with always-failing test
- **Expect:** prose cap (`--max-retries`, default 3; no hook counts it): the step still failing after 3 fixes → STOP the run and report the failure

### BH3: --dry-run does not commit
- **Setup:** any valid unit
- **Prompt:** `/mega-sdd:execute-bolts U-001 --dry-run`
- **Expect:** procedure walks; no `git commit` calls; bolt-report still written marked status=preview

### BH6 (v1.1+): --squad=<id> filters and runs single squad
- **Setup:** vault with 3 squads; user runs on their FE laptop
- **Prompt:** `/mega-sdd:execute-bolts --squad=squad-fe-web`
- **Expect:** only units where `squad: squad-fe-web` are selected (the set becomes `--units=<ids>` for the plan, `references/inline-run.md` (a)); BE and integrations units skipped; bolts written only for FE units

### BH7 (v1.1+): --squad=<id> quarantines a unit whose consumed interface is draft
- **Setup:** FE unit U-FE-002 declares `consumes_interfaces: [api-x]`; `interfaces/api-x.md` has `status: draft`, `producer: squad-be`
- **Prompt:** `/mega-sdd:execute-bolts --squad=squad-fe-web`
- **Expect:** U-FE-002 quarantined `cross_squad_interface_draft` (Karantina row names api-x and producer squad squad-be), its dependents skipped via it, the other FE units run

## Hard Rule pre-flight + post-flight (v1.2+, Iter 3)

### HR1: Pre-flight snapshot persisted
- **Setup:** unit U-001 has `## Hard rules` with 2 rules: `DO NOT modify src/Models/User.php` + `function authenticateUser MUST preserve signature: (email: string, password: string) => Promise<User>`
- **Expect:**
  - Pre-flight runs before bolt execution
  - `<vault>/bolts/U-001/preflight.json` exists with sha256 of User.php + signature snapshot of authenticateUser
  - Bolt proceeds to executing-plans

### HR2: Hard rule violated — DO_NOT_MODIFY
- **Setup:** unit U-002 has `DO NOT modify src/Models/User.php`; bolt's implementation steps modify User.php
- **Expect:**
  - Pre-flight snapshot captured (sha256 = X)
  - executing-plans runs, modifies User.php
  - acceptance tests pass
  - Post-flight: new sha256 ≠ snapshot
  - HALT with `hard_rule_violated` blocker YAML
  - Detect-after: the bolt commit already landed; the B1 gate blocks every further `execute-bolts` until fixed-forward or reverted (code is NOT left uncommitted)
  - bolt-report.md has `status: halted_postflight` with violation list

### HR3: Hard rule violated — DO_NOT_ADD_DEPS
- **Setup:** unit U-003 has `DO NOT add new package.json dependencies`; bolt adds a new dependency to package.json
- **Expect:** post-flight diff detects new top-level dep entry; HALT with `hard_rule_violated`; violation evidence quotes added entry

### HR4: Hard rule violated — SIGNATURE_RULE
- **Setup:** unit U-004 has `function authenticateUser MUST preserve signature: (email: string, password: string) => Promise<User>`; bolt modifies the function to add a `twoFactor?: string` parameter
- **Expect:** signature re-extract shows extra param; HALT with violation evidence quoting old vs new signature

### HR5: Hard rule violated — FILE_PRESENCE_RULE
- **Setup:** unit U-005 has `file src/Models/AuditLog.php MUST exist after bolt`; bolt forgets to create the file (or deletes it)
- **Expect:** post-flight probe shows file missing; HALT with violation

### HR6: Hard rule violated — NAMING_RULE
- **Setup:** unit U-006 has `file:src/api/*.ts MUST follow kebab-case naming`; bolt creates `src/api/auditLog.ts` (camelCase)
- **Expect:** post-flight scans new files matching glob; auditLog.ts fails kebab-case regex; HALT with violation listing the file

### HR7: Hard rule unparseable → halt at pre-flight
- **Setup:** unit U-007 has `## Hard rules` with an unrecognized rule: `forbid users from x`
- **Expect:** pre-flight halts BEFORE bolt execution with `hard_rule_unparseable` listing the offending line + the 5 expected grammar productions

### HR8: Hard rule unanchored — function not in tracked source
- **Setup:** unit U-008 has `function doesNotExist MUST preserve signature: () => void`; no tracked source file defines a symbol with that name
- **Expect:** pre-flight halts with `hard_rule_unanchored`; rule references a symbol that can't be snapshotted

### HR9: Verify-unit special path
- **Setup:** unit U-009 with `task_type: verify`, empty target_files, Anchors cite existing implementation, acceptance_test runs existing test suite
- **Expect:**
  - Pre-flight passes (no Hard rules required for verify; if present, parsed normally)
  - Skip executing-plans (no code to write)
  - Run acceptance tests
  - Skip post-flight Hard rule scan
  - Commit only bolt-report.md (or skip commit on `--no-empty-commits`)

### HR10: All clean — bolt proceeds normally
- **Setup:** unit U-010 has Hard rules; bolt's implementation respects all rules
- **Expect:**
  - Pre-flight snapshot taken
  - executing-plans runs
  - acceptance tests pass
  - Post-flight: all rules clean (snapshot matches / new files conform / file presence verified)
  - Commit proceeds
  - postflight.json shows all rules `status: passed`

### HR11: Multiple rules, one violated → halt
- **Setup:** unit U-011 has 3 Hard rules; bolt violates one
- **Expect:** post-flight detects 1 violation; HALT with `hard_rule_violated` listing all 3 rules in evidence (passed + failed); bolt-report.md captures per-rule status

## Pass criteria

All triggers fire, pre-flight gates behave, the JIT bind verdicts every unit by script and an open CONFLICT closes only its own unit (BI1/BI2), whitelist + retry/halt protocol works. Hard Rule pre/post-flight (HR1-HR11) follows §4 (pre-flight) + §Post-flight Hard Rule validation. Violations NEVER silent — post-flight is detect-after (the bolt commit already landed): the run HALTS, the B1 gate blocks every further `execute-bolts` until the flagged commit is fixed-forward or reverted.
