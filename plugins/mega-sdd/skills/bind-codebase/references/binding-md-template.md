# bind-codebase — binding.md output template (Step 4)

Write `binding.md` using this template (schema source: `binding-contract.md`). The model writes **NO banner and NO enum legend** — both are static boilerplate injected post-write by `scripts/stamp-binding-boilerplate.sh` (bind Step 4.5, BEFORE the derive; see §Authoring notes). Conflicts render as `### CONFLICT-N` detail blocks ONLY — the machine-read form is the only form (no summary table).

```yaml
---
vault: <vault path>
codebase_map: <map path>
bound_at: <ISO timestamp>
strict: <true/false>
binding_metadata:
  codebase_map_provenance: <"snapshot-verified" | "snapshot-stale" | "no-snapshot" | "unverified-external">   # per Step 1 shared-snapshot check (unverified-external = map failed validate-codebase-map.sh writer-provenance — externally authored); consumed by orchestrate-flow chain optimization
  head: <git HEAD sha at bind time, or null outside git>   # written ONCE here at Step 4; derive-binding-json.sh copies it VERBATIM into binding.json `head` (never recomputed at derive time, so a resolve-oq re-derive cannot falsely clear the graph's stale_vs_head signal)
constitution_hash: <sha256>          # only when <vault>/constitution.md exists (Step 2.10)
scope_metadata: { id, name }         # only when vault.json is scoped (Step 1)
---

# Binding Manifest

## Summary
- claims_total: N
- confirmed: N
- conflict: N
- oq: N

## Confirmed Claims (N)
- C-001 | <vault file:line> | <codebase evidence> | <claim text>

## Implementation State Map (N — ALWAYS 6 columns; the Field diff cell is `n/a` unless precision_tier: ast)
| Claim ID | Verdict | State | Anchor | Confidence | Field diff |
|---|---|---|---|---|---|
| C-001 | CONFIRMED | IMPLEMENTED | UserController.php:45 + routes/api.php:12 | high | (exact match) |
| C-LOGIN-1 | CONFIRMED | PARTIAL_FIELDS_MISSING | LoginController.php:45 | high | ADD: [nama] · KEEP: [nip, password] · REMOVE: [] |
| C-007 | CONFIRMED | UNKNOWN | dynamic route detected; heuristic cannot classify [reason: dynamic] | low | n/a |
| C-044 | CONFIRMED | UNKNOWN | truncated §4 — absence is not evidence (map capped) [reason: truncated_section] | low | n/a |
| C-012 | OQ | NEW | — | n/a | n/a |
| C-023 | CONFIRMED | PARTIAL_FIELDS_SURPLUS | OrderController.php:88 | medium | ADD: [] · KEEP: [order_id, items] · REMOVE: [legacy_ref] (CAUTION: code has fields vault doesn't mention) |

## Tech-OQ Auto-Resolved (Scan) (N)
| OQ-ID | Category | Question | Scan target | Resolution | Citations |
|---|---|---|---|---|---|
| OQ-AR-1 | tech / scan | which test framework? | codebase-map §test_frameworks | phpunit | phpunit.xml:1 |

## Tech-OQ Recommendations (review required) (N)
> Each has ACCEPT / OVERRIDE / REJECT options. Recommendations do NOT block; user reviews one-pass after binding completes.

### OQ-AR-7 [P2] [tech / recommend] [conf: high]
…

## Suggested Unit Hard Rules
> Picked up by generate-units; inserted into each relevant unit's ## Hard rules (machine-validated) or ## Anti-patterns (informational).

### Hard rules (machine-validated)
| Source | Suggested rule | Applies to units derived from |
|---|---|---|
…

### Anti-patterns (informational)
| Source | Suggested guidance | Applies to units derived from |
|---|---|---|
…

## Conflicts (N) — BLOCKING
> One canonical `### CONFLICT-N` detail heading per conflict — the ONLY carrier, machine-read
> AND human-read (the Step 5 gate, `validate-handoff-binding-units.sh`, and
> `validate-conflict-classification.sh` read the heading form; a conflict recorded anywhere
> else is invisible to the validators). IDs use the canonical `CONFLICT-N` form
> (advisor-sourced ones may use `CONFLICT-ADV-N` — both are read by the validators).
> Resolution markers are STRUCTURAL — grammar in §Authoring notes below.

### CONFLICT-1 — <short title>
- **Vault claim**: <the claim text — verbatim what the vault asserts>
- **Codebase reality**: <what the code shows> (<evidence anchor file:line>)
- **Claim**: <C-NNN — the State Map claim id this conflict binds to. MANDATORY on
  RESOLVED blocks (`derive-binding-json.sh` exits 2 on a RESOLVED block without a
  parsable Claim line, or on a Claim id absent from the State Map); recommended on
  ACTIVE blocks (`validate-conflict-classification.sh` WARNs when it is missing)>
- **Vault doc**: <vault file §section>
- **Codebase artifact**: <file path>
- **conflict_class**: naming-collision | signature-drift | semantic | regulatory
- **resolution_complexity**: low | medium | high
- **Verdict**: CONFLICT (BLOCKING)
- **Suggested action**: KEEP_VAULT | KEEP_CODE | DEFER | SPLIT — <1-line rationale citing the evidence anchor; the enum never surfaces bare>

## Open Questions (N)
| ID | Question | Source | Auto-resolve attempted |
|---|---|---|---|
| OQ-001 | ... | <vault file:line> | N/A (fresh OQ) |

## Auto-Resolved Deferred OQs (N)
| OQ-ID | Question | Evidence (codebase-map) | Status |
|---|---|---|---|
...
```

Bound-vault annotation format (HTML comments injected into the `<vault>/bound/` copy) is specified in `binding-contract.md` and emitted by `scripts/make-bound.sh` (Step 5) — the model never types the bound copies.

## Authoring notes (not emitted)

Static boilerplate + grammar the emitted file carries but the model never types:

> **Do-not-hand-edit banner (stamped post-write by `scripts/stamp-binding-boilerplate.sh`).**
> The emitted file's first line after the frontmatter is:
> `> REGENERATED by bind-codebase on every run — do NOT hand-edit. Manual verdict edits are LOST on re-bind; CONFLICT resolutions belong in /mega-sdd:resolve-oq --binding (which records them durably in decisions.md).`
> The stamp script injects it in Step 4.5 (before `derive-binding-json.sh`); it is idempotent and parser-invisible (`_lib/binding_md.py` reads no region the banner or legend occupies, so `binding.json` is byte-identical whether derived before or after stamping).

> **`[reason: <enum>]` Anchor-cell token (W2 — machine-closed `state_reason` grammar).**
> When a row's state reflects a truncation/heuristic condition, the Anchor cell MUST end
> with a trailing `[reason: <enum>]` token — closed enum: `truncated_section` |
> `ambiguous_match` | `dynamic` | `regex_tier` | `kb_confirmed`. The token lives INSIDE
> the Anchor cell — NEVER a 7th column (the table stays 6 columns always).
> `scripts/derive-binding-json.sh` strips the token into the binding.json claim's
> `state_reason` and FAILS the derive (exit 2) on an unknown token OR on an Anchor cell
> citing truncation with no token (the `implementation-state.md` S4 MUST — "cite the
> truncation in the Anchor cell" — is now machine-enforced, never prose-trusted).

> **Resolution markers are STRUCTURAL** (S4): a conflict counts as resolved ONLY when the
> heading carries ✅ or the word `RESOLVED` immediately AFTER the conflict ID
> (`### ✅ CONFLICT-1 RESOLVED (KEEP_CODE) — …`), or a dedicated
> `- **Resolution**: ✅ RESOLVED (<action>) <date>` line whose VALUE STARTS with the marker —
> written by `/mega-sdd:resolve-oq --binding`. Prose containing the word "resolved" elsewhere
> (a TITLE like "tickets are auto-resolved", a `Status: NOT RESOLVED` line, Suggested-action
> text) does NOT count (and must not — business vocabulary would silently open the gate).

> **Enum legend (keterangan contract).** The 4-code gloss text (what choosing
> KEEP_VAULT / KEEP_CODE / DEFER / SPLIT actually DOES) lives ONLY in
> `scripts/stamp-binding-boilerplate.sh` (single source) — the script stamps it as a
> blockquote under the `## Conflicts` heading post-write, so every emitted binding.md still
> carries it. binding.md is a durable ARTIFACT — the stamped legend is written in English
> (Tier-3: artifact language, per output-language.md); the DISPLAYER localizes it at prompt
> time (halt-protocol §Consumer dispatch step 0 / the resolve-oq --binding menu carry the
> Tier-2 rendering). Codes stay English everywhere (Tier-1).
