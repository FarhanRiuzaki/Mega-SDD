# binding.json — structured State Map sidecar

`binding.json` is SCRIPT-DERIVED from `binding.md` by
`scripts/derive-binding-json.sh` (bind-codebase Step 4.5; re-run by resolve-oq
`--binding` after its write-back) — never hand-written or model-emitted, so
`generated_by` is always `derive-binding-json@1.0.0`. Pure JSON root object, no
frontmatter. Mirror of the Implementation State Map table + Confirmed Claims
list, so downstream consumers (the graph builder) never parse the markdown
table. Value provenance: `codebase_map_provenance` + `head` come verbatim from
the `binding_metadata` frontmatter (written once at bind Step 4 — a re-derive
never recomputes them); `state_reason` comes from the trailing
`[reason: <enum>]` token in the State Map row's Anchor cell (stripped from
`anchor` at derive time); `resolution` comes from RESOLVED `### CONFLICT-N`
blocks' `- **Claim**: C-NNN` lines. `schema_version` stays `"1.0"` — the key
set and shapes are unchanged; only value provenance and `generated_by` changed.

## Schema

```json
{
  "schema_version": "1.0",
  "generated_by": "derive-binding-json@1.0.0",
  "generated_at": "<ISO8601 UTC>",
  "vault": "<vault dir path>",
  "codebase_map_provenance": "snapshot-verified | snapshot-stale | no-snapshot | unverified-external",
  "head": "<git HEAD sha at bind time, or null>",
  "claims": [
    {
      "id": "C-001",
      "verdict": "CONFIRMED | CONFLICT | OQ",
      "state": "IMPLEMENTED | PARTIAL_FIELDS_MISSING | PARTIAL_FIELDS_SURPLUS | PARTIAL_FIELDS_BOTH | NEW | UNKNOWN | null",
      "state_reason": "truncated_section | ambiguous_match | dynamic | regex_tier | kb_confirmed | null",
      "anchor": "UserController.php:45 + routes/api.php:12 | null",
      "confidence": "high | medium | low | null",
      "field_diff": "ADD: [...] · KEEP: [...] · REMOVE: [...] | (exact match) | n/a",
      "vault_source": "03-data-model.md:42 | null",
      "resolution": "KEEP_VAULT | KEEP_CODE | DEFER | SPLIT | null"
    }
  ]
}
```

Field notes (S4):
- `state_reason` — WHY a state is `UNKNOWN` (or otherwise degraded). `truncated_section`
  is load-bearing: `generate-units` keys its direct-probe sub-rule on it (never `create`
  straight off a capped map section). Optional/null for self-evident states. Sourced
  from the State Map Anchor cell's `[reason: <enum>]` token; the derive FAILS (exit 2)
  on an unknown token or on a truncation-citing Anchor cell with no token.
- `resolution` — set by `resolve-oq --binding` when a CONFLICT claim is
  resolved (KEEP_VAULT / KEEP_CODE / DEFER / SPLIT); null until then. resolve-oq
  writes the structural RESOLVED markers + the `- **Claim**: C-NNN` line into
  `binding.md`, then refreshes this sidecar by re-running
  `scripts/derive-binding-json.sh` (the ACTION is read from whichever RESOLVED
  surface matched; the Claim line maps it onto the State Map claim id).

## Parity rule (validated by `scripts/validate-binding-json.sh`)

For every row in the `binding.md` Implementation State Map there MUST be exactly
one `claims[]` entry with the same `id`, `verdict`, and `state`, and vice-versa.
Anchor and field_diff are NOT compared by the validator (the gate is the source
of truth: it enforces id/verdict/state only). This does not mean anchor mismatches
are acceptable — anchor accuracy is a **bind-time authoring obligation** (rules
tier: the skill's anti-hallucination rails, plus the default-on phase-advisor pass
which samples anchors adversarially). No deterministic validator checks binding
anchors themselves; the only deterministic anchor check downstream is
`validate-unit-spec.sh`'s verify+HIGH grounding rail (A1), which covers unit
acceptance-criteria anchors only. A parity mismatch is a FAIL — the binding write
is inconsistent and the graph would inherit the error.
