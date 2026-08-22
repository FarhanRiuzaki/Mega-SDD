# bind-codebase — Framework packs + Suggested Unit Hard Rules (Steps 2.8, 2.9)

## Contents
- 2.8 Load framework convention pack
- 2.9 Emit Suggested Unit Hard Rules
- Output section + anti-hallucination rails

## 2.8 Load framework convention pack

Read `codebase-map.md` §7 Framework. Load the matching pack from `plugins/mega-sdd/references/framework-conventions/<framework>.md`. If `framework.name = _universal` or no match → load `_universal.md` only.

**Protocol:** read the pack file completely; extract its `## Hard Rules emitted` section into structured records; if the pack has `extends: <parent>` frontmatter, load the parent first then overlay (child rules override parent on `path_glob` conflict). Opt-out `--no-framework-pack` skips this step; `--framework-pack=<custom-path>` uses a project-specific pack. Loaded pack rules feed Step 2.9.

**Halts:** pack declared (`pack_path: X`) but file not found → `framework_pack_missing` (halt YAML lists expected path + fallback). `extends:` chain cycle → `framework_pack_cycle`. Pack fails to parse → `framework_pack_unparseable`.

**Graceful fallback (no halt):** pre-§7 codebase-map → treat as `_universal`, log advisory in binding.md. `last_verified_against:` >365 days stale → advisory note, no halt.

## 2.9 Emit Suggested Unit Hard Rules

Bind-codebase suggests Hard Rules that `generate-units` pulls into per-unit `## Hard rules` sections — the bridge from binding intelligence → per-unit pre/post-flight enforcement. Governing rule: KB gotchas → Anti-patterns by default; promoted to Hard rules ONLY when the KB marker is `[VERIFIED]` AND the gotcha is mechanically detectable.

**Sources (priority order):**

a. **Framework pack rules** — Hard Rules from the loaded pack's `## Hard Rules emitted`. Universal-pack rules are the baseline; framework-pack rules overlay (override on `path_glob` conflict). Apply project-wide regardless of unit-specific signals.

   **Pack→bolt translation table (S6 EB-GATE-7 — packs ship `rule_type` inventories, NOT ready-made ast-grep blocks; a pack rule reaches a unit's `## Hard rules` ONLY through one of these productions, so the bolt-stage scan can always execute what the unit carries):**

   | Pack `rule_type` | Emitted into the unit as | Bolt-time check |
   |---|---|---|
   | `NAMING_RULE` (has `path_glob` + case style) | v1 `<path-glob> MUST follow <case-style> naming` | deterministic (filename regex) |
   | `LOCATION_RULE` (files-belong-here) | v1 `<path-glob> MUST follow …` when expressible; else Anti-pattern | deterministic / advisory |
   | `DEP_RULE` (no new deps / pinned manifest) | v1 `DO NOT add new <manifest> dependencies` | deterministic (manifest diff) |
   | `LOCK_RULE` (do-not-touch file) | v1 `DO NOT modify <path>` | deterministic (commit-touch / sha) |
   | `SIGNATURE_RULE` | v1 `function <name> MUST preserve signature: <sig>` | deterministic (decl compare) |
   | rule carrying a real ast-grep `rule:` body | v2 fenced YAML block (verbatim) | deterministic (`ast-grep scan`) |
   | `CUSTOM` / `SECURITY` / `PERFORMANCE` prose | `## Anti-patterns` (informational) by default; a generic `MUST/DO NOT` directive line ONLY when the obligation is genuinely load-bearing (honest tier — post-flight records it `directive_unverified` unless attested) | advisory / attested |

   A pack rule that fits NO row is an Anti-pattern, never a Hard rule — emitting prose the scan cannot execute breaks the chain of custody (`unit-spec` counts it, the bolt scan can't check it, B1 then demands a verdict nothing can produce).

b. **Binding state-derived** (per claim with `state: IMPLEMENTED` or `UNKNOWN`): anchor file exists + claim CONFIRMED → suggest `DO NOT modify <anchor-file>` for any unit whose `vault_source` overlaps the claim, UNLESS the claim is an extend candidate. Conservative — defaults to "don't touch what's working."

c. **CONFLICT-derived** (per CONFLICT after user resolution via resolve-oq): resolved `KEEP_CODE` → suggest `DO NOT modify <conflicting-file>` for downstream units that might touch it; `KEEP_VAULT` → no Hard rule (intentional rewrite — the code-update obligation is carried by generate-units' task_type route instead: the claim types `extend`-toward-vault per `generate-units/references/task-typing.md`, never a no-code `verify`); `DEFER` → no Hard rule (OQ propagates).

d. **KB-derived hard rules** (only when KB present AND marker `[VERIFIED]`): a `## 9. Edge Cases & Gotchas` entry `[VERIFIED]` AND mechanically detectable → `DO NOT modify <gotcha-anchor-file>`; a `## 8. State Machine` entry `[VERIFIED]` for a function with stable signature → `function <name> MUST preserve signature: <sig>`. `[INFERRED]`/`[OPEN]` → NOT promoted (Anti-patterns instead).

e. **KB-derived Anti-pattern suggestions** (informational, not machine-validated): every `## 9. Edge Cases & Gotchas` entry → suggested Anti-pattern with brief description + KB anchor; every "do-not-replicate" critical finding in the KB README → suggested Anti-pattern.

**Output** — write to `binding.md` under `## Suggested Unit Hard Rules`:

```markdown
## Suggested Unit Hard Rules

> Picked up by generate-units; inserted into each relevant unit's ## Hard rules (machine-validated at bolt time) or ## Anti-patterns (informational).

### Hard rules (machine-validated at bolt time)
| Source | Suggested rule | Applies to units derived from |
|---|---|---|
| Implementation state | DO NOT modify app/Http/Controllers/UserController.php | flows.md §read-endpoints |
| KB [VERIFIED] gotcha | DO NOT modify app/Services/MT202Dispatcher.php | vault.md §Decisions IDR-routing |

### Anti-patterns (informational guidance)
| Source | Suggested guidance | Applies to units derived from |
|---|---|---|
| KB gotcha G-002 | Don't replicate the IDR MT202 dispatch path — file written but never sent; see knowledge-base/10-domains/30-swift-messaging.md §G-002 | flows.md §payment-settlement |
| KB critical finding | Don't replicate cfkdhl→CFKDDL silent typo; see knowledge-base/10-domains/10-cif-customer.md §Edge Case 9 | flows.md §customer-edit |
```

**Anti-halu rails:** NEVER promote `[INFERRED]`/`[OPEN]` KB items to Hard rules (Anti-patterns only). NEVER suggest a Hard rule whose anchor file isn't in the codebase-map (`hard_rule_unanchored` would fire at bolt time — surface it here). Suggestions are RECOMMENDATIONS — `generate-units` reviews + filters before inserting into units.
