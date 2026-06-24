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
      "anchor": "UserController.php:45 + routes/api.php:12 | null",
      "confidence": "high | medium | low | null",
      "field_diff": "ADD: [...] · KEEP: [...] · REMOVE: [...] | (exact match) | n/a",
      "vault_source": "03-data-model.md:42 | null"
    }
  ]
}
```

## Parity rule (validated by `scripts/validate-binding-json.sh`)

For every row in the `binding.md` Implementation State Map there MUST be exactly
one `claims[]` entry with the same `id`, `verdict`, and `state`, and vice-versa.
Anchor and field_diff are NOT compared by the validator (the gate is the source
of truth: it enforces id/verdict/state only). This does not mean anchor mismatches
are acceptable — anchor accuracy is enforced at bind time by bind-codebase, not by
this read-time parity validator. A mismatch is a FAIL — the binding write is
inconsistent and the graph would inherit the error.
