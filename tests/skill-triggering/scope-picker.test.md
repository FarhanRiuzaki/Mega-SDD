# Scope Picker — Skill Triggering Tests

Manual test fixtures for `plan --scope` — plan Step 0.9 scope detection (`skills/plan/references/scope-flow.md`; the picker moved here from generate-intent, removed in 9.0). Step through each case; document actual vs expected output.

## Test 0: Front door with `--scope` → guarded lane

**Setup**:
- cwd: `~/test-projects/order-be/` (a starterkit is present)
- PRD: `tests/scenarios/sample-prd-multi-scope.md`

**Invocation**:
```bash
cd ~/test-projects/order-be/
/mega-sdd ./tests/scenarios/sample-prd-multi-scope.md --scope=BE
```

**Expected**:
- `--scope` is a pipeline-only flag → it implies `--guarded` (route-lane.sh records the override)
- The picker is bypassed; the proposed chain is `plan <prd> --lite --mode=<existing|new> --scope=BE` → `execute-bolts --all --lite`, ONE confirmation

**Pass criteria**: Guarded lane forced; no picker; `--scope=BE` reaches the `plan` hop.

---

## Test 1: Canonical multi-scope PRD → interactive picker

**Setup**:
- cwd: `~/test-projects/order-be/`
- PRD: `tests/scenarios/sample-prd-multi-scope.md`
- No `--scope` flag

**Invocation**:
```bash
cd ~/test-projects/order-be/
/mega-sdd:plan ./tests/scenarios/sample-prd-multi-scope.md
```

**Expected**:
- plan detects `scopes: { BE, MW, FE }` from frontmatter
- AskUserQuestion fires with 5 options (3 scopes + "All scopes" + Cancel), led by the line "Memilih satu scope memfilter PRD ke bagian scope itu; …"
- Smart default: BE (cwd basename `order-be` matches BE)
- Option 1 labeled "BE — Backend API (recommended)"

**Pass criteria**: AskUserQuestion fires; BE recommended; vault tagged scope=BE on accept.

---

## Test 2: Canonical PRD + --scope=<valid> flag → silent

**Setup**: Same PRD as Test 1

**Invocation**:
```bash
/mega-sdd:plan --scope=MW ./tests/scenarios/sample-prd-multi-scope.md
```

**Expected**:
- plan reads scopes; validates `MW` is declared
- NO AskUserQuestion (silent)
- `vault.json` tagged `scope: MW` + `scope_metadata` (via the Step-3 `derive-vault-json.sh --patch`, never hand-written); `context.md` frontmatter carries `scope` / `scope_name`
- `context.md ## Overview` carries the H3 `### Sibling scopes (managed externally — NOT in this vault)` listing BE + FE
- Consumed contracts: be-mw-appointment-events
- Published contracts: (none — MW is mid-stream in this fixture)

**Pass criteria**: Silent execution; vault tagged scope=MW; sibling notes include BE+FE.

---

## Test 3: Canonical PRD + --scope=<invalid> flag → halt

**Setup**: Same PRD as Test 1

**Invocation**:
```bash
/mega-sdd:plan --scope=XYZ ./tests/scenarios/sample-prd-multi-scope.md
```

**Expected**:
- The PreToolUse scope-flag gate (`validate-scope-flag.sh`, on the `plan` / front-door dispatch) blocks with `scope_not_declared_in_prd`; plan's own Step 0.9 check is the in-skill twin
- Halt YAML shows: declared_scopes: [BE, MW, FE], requested_scope: XYZ
- Options: `re-pick-from-declared` / `cancel`, each with keterangan

**Pass criteria**: Halt fires; YAML structure correct; no vault written.

---

## Test 4: PRD without a `scopes:` block → single-scope, no ask

**Setup**:
- PRD: `tests/scenarios/sample-prd-legacy-no-frontmatter.md`
- No `--scope` flag

**Invocation**:
```bash
/mega-sdd:plan ./tests/scenarios/sample-prd-legacy-no-frontmatter.md
```

**Expected**:
- plan reads PRD; no `scopes:` block detected → treated as single-scope
- NO AskUserQuestion, NO retrofit subagent — interactive and `--auto` alike (the 8.x retrofit bridge left with generate-intent)
- The vault.json patch records `scope_inferred: single`; no scope tagging
- ONE delivery-report line offers the manual retrofit: add a `scopes:` block by hand, then `plan --regenerate --scope=<id>`
- Original PRD untouched

**Pass criteria**: No prompt; one report line; PRD byte-identical.

---

## Test 5: Single-scope PRD → silent (no picker)

**Setup**:
- PRD: `tests/scenarios/sample-prd-single-scope.md`
- No `--scope` flag

**Invocation**:
```bash
/mega-sdd:plan ./tests/scenarios/sample-prd-single-scope.md
```

**Expected**:
- plan reads scopes; only 1 scope declared (BE)
- NO AskUserQuestion (silent — single scope is unambiguous)
- Vault tagged scope=BE
- No sibling-scope note in `context.md ## Overview` (there are none)

**Pass criteria**: Silent execution; vault tagged scope=BE; no AskUserQuestion fired.

---

## Test 6: Prior-vault hit on re-invocation

**Setup**:
- cwd: `~/test-projects/order-be/`
- PRD: `tests/scenarios/sample-prd-multi-scope.md`
- Run Test 1 first (its vault.json now carries `scope: BE` + `prd_sha256` — the pipeline record; there is no side memory)

**Invocation**:
```bash
# Same PRD, same cwd, second time — the vault exists, so plan needs --regenerate
/mega-sdd:plan --regenerate ./tests/scenarios/sample-prd-multi-scope.md
```

**Expected**:
- plan reads scopes; multi-scope detected
- Existing-vault lookup: a vault in this project carries the same `prd_sha256` + `scope: BE` → suggest BE
- AskUserQuestion fires with shortened prompt:
  ```
  ▶ PRD ./...md recognized (sha256: <hash>...)
    Existing vault scope: BE (vault.json)
  ❓ Same scope this run?
     [Enter] BE (recommended — confirm-once)
     [2/3/4] Different scope
     [5] Cancel
  ```
- On Enter: BE accepted without re-picking (AskUserQuestion has no timer — nothing defaults silently); under `--auto` the prior-vault scope is taken silently
- Without `--regenerate`, plan refuses in one line (existing `context.md`) before any scope prompt

**Pass criteria**: Confirm-once UX fires; Enter accepts BE; no timeout exists or is claimed.

---

## Test 7: --scope=all (legacy single-vault)

**Setup**: Same PRD as Test 1

**Invocation**:
```bash
/mega-sdd:plan --scope=all ./tests/scenarios/sample-prd-multi-scope.md
```

**Expected**:
- plan skips picker entirely
- Warning emitted: "Combined vault may produce noisy units for non-applicable scopes."
- The patch omits the `scope` field (back-compat) — vault written WITHOUT scope tagging
- All PRD content included (universal + BE + MW + FE)

**Pass criteria**: Warning shown; vault has no scope field; full content included.

---

## Test 8: --scope=BE on a brownfield repo (composition)

**Setup**:
- cwd: `~/test-projects/order-be/` — an existing Laravel app (GROUND has built the symbol index; `derived.framework_pack` = the Laravel pack)
- PRD: `tests/scenarios/sample-prd-multi-scope.md`

**Invocation**:
```bash
/mega-sdd:plan --scope=BE --mode=existing ./tests/scenarios/sample-prd-multi-scope.md
```

**Expected**:
- Scope filter applied first (universal sections + §Backend only)
- Brownfield task typing from the symbol index (`query-symbol-index.sh`): a hit → `verify`/`extend` + `## Anchors` + `## Claims`; a miss → `create` + a `must-not-exist` claim — never a CONFIRMED/CONFLICT verdict (the JIT bind writes those at dispatch)
- The framework pack's rules reach each bolt as the advisory T2 slice at dispatch, not as new machine-checked unit rules
- `vault.json` has scope=BE + scope_metadata; there is no `--scan=<map>` input any more (scan-codebase was removed in 9.0; GROUND replaces it)

**Pass criteria**: Scope filter + brownfield typing compose; vault carries the scope metadata; units carry contracts, not verdicts.

---

## Notes

- All tests can run manually by stepping through plan Step 0.9 (`skills/plan/references/scope-flow.md`)
- Skill should announce which test case is active for traceability
- Failed test → file issue with verbatim AskUserQuestion output / halt YAML / vault.json
