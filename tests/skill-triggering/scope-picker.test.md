# Scope Picker — Skill Triggering Tests

Manual test fixtures for `generate-intent` Step 0.9 scope detection (Iter 28). Step through each case; document actual vs expected output.

## Test 1: Canonical multi-scope PRD → interactive picker

**Setup**:
- cwd: `~/test-projects/order-be/`
- PRD: `tests/scenarios/sample-prd-multi-scope.md`
- No `--scope` flag

**Invocation**:
```bash
cd ~/test-projects/order-be/
/mega-sdd:generate-intent ./tests/scenarios/sample-prd-multi-scope.md
```

**Expected**:
- generate-intent detects `scopes: { BE, MW, FE }` from frontmatter
- AskUserQuestion fires with 5 options (3 scopes + "All scopes" + Cancel)
- Smart default: BE (cwd basename `order-be` matches BE)
- Option 1 labeled "BE — Backend API (recommended)"

**Pass criteria**: AskUserQuestion fires; BE recommended; vault tagged scope=BE on accept.

---

## Test 2: Canonical PRD + --scope=<valid> flag → silent

**Setup**: Same PRD as Test 1

**Invocation**:
```bash
/mega-sdd:generate-intent --scope=MW ./tests/scenarios/sample-prd-multi-scope.md
```

**Expected**:
- generate-intent reads scopes; validates `MW` is declared
- NO AskUserQuestion (silent)
- Vault tagged scope=MW
- 00-index.md sibling scopes: BE, FE
- Consumed contracts: be-mw-appointment-events
- Published contracts: (none — MW is mid-stream in this fixture)

**Pass criteria**: Silent execution; vault tagged scope=MW; sibling notes include BE+FE.

---

## Test 3: Canonical PRD + --scope=<invalid> flag → halt

**Setup**: Same PRD as Test 1

**Invocation**:
```bash
/mega-sdd:generate-intent --scope=XYZ ./tests/scenarios/sample-prd-multi-scope.md
```

**Expected**:
- generate-intent reads scopes; validates `XYZ` not in declared list
- Halts `scope_not_declared_in_prd`
- Halt YAML shows: declared_scopes: [BE, MW, FE], requested_scope: XYZ
- Options: re-pick from valid list OR cancel

**Pass criteria**: Halt fires; YAML structure correct; no vault written.

---

## Test 4: Legacy PRD (no frontmatter) → retrofit bridge

**Setup**:
- PRD: `tests/scenarios/sample-prd-legacy-no-frontmatter.md`
- No `--scope` flag

**Invocation**:
```bash
/mega-sdd:generate-intent ./tests/scenarios/sample-prd-legacy-no-frontmatter.md
```

**Expected**:
- generate-intent reads PRD; no `scopes:` block detected
- AskUserQuestion fires with options:
  - [1] Yes, propose retrofit (recommended)
  - [2] Treat as single-scope PRD
  - [3] Cancel
- On user choosing [1]:
  - Subagent dispatched per `legacy-retrofit-prompt.md`
  - Detects: BE (Backend Lead: Alice Doe), FE (UX Lead: Bob Smith), MW (Integration Lead: Carol Lee)
  - Confidence: HIGH for BE+FE, MEDIUM for MW
  - Diff rendered to user

**Pass criteria**: Retrofit AskUserQuestion fires; subagent dispatched on accept; original PRD untouched.

---

## Test 5: Single-scope PRD → silent (no picker)

**Setup**:
- PRD: `tests/scenarios/sample-prd-single-scope.md`
- No `--scope` flag

**Invocation**:
```bash
/mega-sdd:generate-intent ./tests/scenarios/sample-prd-single-scope.md
```

**Expected**:
- generate-intent reads scopes; only 1 scope declared (BE)
- NO AskUserQuestion (silent — single scope is unambiguous)
- Vault tagged scope=BE
- 00-index.md sibling scopes: [] (empty)

**Pass criteria**: Silent execution; vault tagged scope=BE; no AskUserQuestion fired.

---

## Test 6: Memory hit on second invocation

**Setup**:
- cwd: `~/test-projects/order-be/`
- PRD: `tests/scenarios/sample-prd-multi-scope.md`
- Run Test 1 first (which records scope=BE to memory)

**Invocation**:
```bash
# Same PRD, same cwd, second time
/mega-sdd:generate-intent ./tests/scenarios/sample-prd-multi-scope.md
```

**Expected**:
- generate-intent reads scopes; multi-scope detected
- Memory lookup: PRD sha256 found → last scope BE
- AskUserQuestion fires with shortened prompt:
  ```
  ▶ PRD ./...md recognized (last scope: BE)
  ❓ Same scope this run?
     [Enter] BE (default after 5s; confirm-once)
     [2/3/4] Different scope
     [5] Cancel
  ```
- On Enter (or 5s timeout): silent default to BE

**Pass criteria**: Confirm-once UX fires; BE silently defaulted; 5s timeout works.

---

## Test 7: --scope=all (legacy single-vault)

**Setup**: Same PRD as Test 1

**Invocation**:
```bash
/mega-sdd:generate-intent --scope=all ./tests/scenarios/sample-prd-multi-scope.md
```

**Expected**:
- generate-intent skips picker entirely
- Warning emitted: "Combined vault may produce noisy units for non-applicable scopes."
- Vault written WITHOUT scope field (legacy behavior)
- All PRD content included (universal + BE + MW + FE)

**Pass criteria**: Warning shown; vault has no scope field; full content included.

---

## Test 8: --scope=BE + --kb=<path> + --scan=<map> (full composition)

**Setup**:
- cwd: `~/test-projects/order-be/`
- PRD: `tests/scenarios/sample-prd-multi-scope.md`
- KB: synthetic `.mega-sdd/knowledge-base/` from prior extract-intelligence run
- codebase-map: synthetic `.mega-sdd/codebase/codebase-map.md` with framework: laravel-base-26

**Invocation**:
```bash
/mega-sdd:generate-intent --kb=.mega-sdd/knowledge-base/ --scan=.mega-sdd/codebase/codebase-map.md --scope=BE ./tests/scenarios/sample-prd-multi-scope.md
```

**Expected**:
- Scope filter applied first (BE-only PRD content)
- KB consulted with tier-aware routing (Iter 22): [LOCKED] preserved, [INTENT] free
- Framework pack loaded (Iter 23): laravel-base-26 Hard Rules emitted
- Starterkit-first vault (Iter 27): dual-citation in 02-architecture
- Vault has scope=BE + scope_metadata + pack_path + KB tier annotations

**Pass criteria**: All four iters compose correctly; vault has all expected metadata fields.

---

## Notes

- All tests can run manually by stepping through generate-intent skill procedure
- Skill should announce which test case is active for traceability
- Failed test → file issue with verbatim AskUserQuestion output / halt YAML / vault.json
