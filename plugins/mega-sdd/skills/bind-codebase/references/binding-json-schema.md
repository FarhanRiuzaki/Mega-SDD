# binding.json — structured State Map sidecar

`bind-codebase` emits `binding.json` next to `binding.md` (same Step 4 write).
Pure JSON root object, no frontmatter. Mirror of the Implementation State Map
table + Confirmed Claims list, so downstream consumers (the graph builder)
never parse the markdown table.

## Schema

```json
{
  "schema_version": "1.0",
  "generated_by": "bind-codebase@<version>",
  "generated_at": "<ISO8601 UTC>",
  "vault": "<vault dir path>",
  "codebase_map_provenance": "snapshot-verified | snapshot-stale | no-snapshot",
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
  straight off a capped map section). Optional/null for self-evident states.
- `resolution` — set by `/mega-sdd:resolve-oq --binding` when a CONFLICT claim is
  resolved (KEEP_VAULT / KEEP_CODE / DEFER / SPLIT); null until then. resolve-oq
  updates this sidecar alongside `binding.md` when the file exists.

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
