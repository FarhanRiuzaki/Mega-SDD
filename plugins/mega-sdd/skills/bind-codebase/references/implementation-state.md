# bind-codebase — Implementation-state classification (Step 2.5)

## Contents
- Classification states + per-claim-type rules
- Field-level diff detection
- Worked example
- Anti-hallucination rails

For each claim marked CONFIRMED, classify implementation readiness per `binding-contract.md` §Implementation-State Classification. States: `IMPLEMENTED` / `NEW` / `UNKNOWN` / `PARTIAL_FIELDS_MISSING` / `PARTIAL_FIELDS_SURPLUS` / `PARTIAL_FIELDS_BOTH`. Result is written to `binding.md` under `## Implementation State Map`.

## Per-claim-type rules

> **Truncation exception (all claim types):** when the map frontmatter lists the claim's
> section in `truncated_sections` (the 200-per-category extraction cap fired there),
> absence in that section is NOT evidence — classify `UNKNOWN`, never `NEW` (a
> truncated-away implemented element must not become a duplicate-implementation
> `create` task). Per `scan-codebase/references/codebase-map-schema.md`.
> **Carry the reason onto the binding surface** (S4): the State Map row's Anchor
> cell MUST cite the truncation (`truncated §N — absence is not evidence`) and the
> `binding.json` claim MUST set `state_reason: truncated_section` — downstream
> `generate-units` keys its direct-probe sub-rule (probe the repo, never `create`
> straight off the capped map) on exactly this signal; an unmarked truncation-UNKNOWN
> is indistinguishable from a dynamic-route UNKNOWN and defeats the protection.

**Endpoint claims** (`POST /api/foo`):
- Route in codebase-map §3 AND handler symbol in §2 with matching signature → `IMPLEMENTED` (high).
- Route found, handler present but signature field-set mismatches claim → `PARTIAL_FIELDS_MISSING` / `PARTIAL_FIELDS_SURPLUS` (see field-level diff).
- Route found, handler symbol absent in §2 → `UNKNOWN` (low).
- Route not found AND handler absent → `NEW` (unless §3 is truncated → `UNKNOWN`).

**Entity claims** (`User has email + role`):
- Entity in §4 AND all claimed fields detected (V == C) → `IMPLEMENTED` (high).
- Entity found but field-set diff (V ⊂ C or C ⊂ V) → `PARTIAL_FIELDS_MISSING` (code missing some claim fields) / `PARTIAL_FIELDS_SURPLUS` (code has fields not in claim).
- Entity found, disjoint field sets → `UNKNOWN`.
- Entity not in §4 → `NEW` (unless §4 is truncated → `UNKNOWN`).

**Method/handler claims** (`sendEmail()`):
- Symbol in §2 with matching signature (param names + types) → `IMPLEMENTED` (high).
- Symbol in §2, different signature → `PARTIAL_FIELDS_*` per direction.
- Symbol absent / disjoint signature → `UNKNOWN`.
- Symbol not in §2 → `NEW`.

## Field-level diff detection

For each CONFIRMED claim that specifies fields/params explicitly:

1. **Extract V** = field set asserted by the vault claim.
2. **Extract C** = field set from the codebase-map (tree-sitter signature extraction at `precision_tier: ast`; regex fallback = lower confidence — run `/mega-sdd:install-deps --tools=tree-sitter` then re-scan for AST precision).
3. **Compute diff:** `ADD = V \ C` (missing in code), `KEEP = V ∩ C` (shared), `REMOVE = C \ V` (surplus in code).
4. **Assign state:** `V == C` → `IMPLEMENTED`; `C ⊂ V` (ADD non-empty, REMOVE empty) → `PARTIAL_FIELDS_MISSING`; `V ⊂ C` (REMOVE non-empty, ADD empty) → `PARTIAL_FIELDS_SURPLUS`; both non-empty → `PARTIAL_FIELDS_BOTH` (rare; semantic mismatch); `V ∩ C` empty but symbol exists → `UNKNOWN`.
5. **Record** the diff in the Implementation State Map's `field_diff` column.

**Disjoint-set check:** BEFORE computing PARTIAL_*, if `V ∩ C` is empty AND both V and C are non-empty → state is `UNKNOWN` (symbol name matches but semantic intent is unrelated; needs human review), NOT `PARTIAL_FIELDS_BOTH`. `PARTIAL_FIELDS_BOTH` applies only when `V ∩ C` is non-empty (some shared fields) AND both `V\C` and `C\V` are non-empty (genuine bidirectional drift).

## Worked example — login scenario

```
Vault claim C-LOGIN-1: POST /api/login accepts { nip, nama, password }
Codebase-map §3: POST /api/login → LoginController@store
Codebase-map §2: LoginController@store(nip: string, password: string)

V = { nip, nama, password }
C = { nip, password }
ADD = V \ C = { nama }   KEEP = V ∩ C = { nip, password }   REMOVE = C \ V = { }
State = PARTIAL_FIELDS_MISSING
```

This state propagates to `generate-units`, which assigns `task_type: extend` with Migration notes auto-populated (ADD: nama; KEEP: nip, password; REMOVE: none).

## Anti-hallucination rails

- Field-level diff REQUIRES `precision_tier: ast`. On `precision_tier: regex`, field extraction is unreliable → fall back to binary classification (PARTIAL collapses to UNKNOWN).
- `PARTIAL_FIELDS_SURPLUS` ALWAYS triggers a human-review prompt in generate-units (code has things the spec doesn't mention → ambiguous intent).
- `PARTIAL_FIELDS_BOTH` is rare and high-stakes — surfaced with a strong warning; the user typically updates the vault OR triages code drift.
- Diff calculation is DETERMINISTIC (set ops on extracted token lists); no fuzzy similarity matching.
- **KB-confirmed claims** (CONFIRMED reached via KB because the codebase-map was silent) → classify as `UNKNOWN` with `low` confidence (the KB documents domain knowledge, not necessarily implementation).
- **Conservative default:** when the heuristic cannot classify → `UNKNOWN` with `low` confidence. Never silently claim `IMPLEMENTED` without a concrete anchor.
- **Anchor recording:** every state assignment carries an `anchor` field citing the source of truth (e.g., `UserController.php:45 + routes/api.php:12`); for state `NEW`, anchor is `—`.
- Implementation-state classification does NOT change blocking rules — CONFLICT still blocks; IMPLEMENTED is still CONFIRMED, just annotated for downstream `task_type` assignment.
