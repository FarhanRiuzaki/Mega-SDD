# bind-codebase — binding.md output template (Step 4)

Write `binding.md` using this template (schema source: `binding-contract.md`).

```yaml
---
vault: <vault path>
codebase_map: <map path>
bound_at: <ISO timestamp>
strict: <true/false>
binding_metadata:
  codebase_map_provenance: <"snapshot-verified" | "snapshot-stale" | "no-snapshot">   # per Step 1 shared-snapshot check; consumed by orchestrate-flow chain optimization
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

## Implementation State Map (N; field_diff column when precision_tier: ast)
| Claim ID | Verdict | State | Anchor | Confidence | Field diff |
|---|---|---|---|---|---|
| C-001 | CONFIRMED | IMPLEMENTED | UserController.php:45 + routes/api.php:12 | high | (exact match) |
| C-LOGIN-1 | CONFIRMED | PARTIAL_FIELDS_MISSING | LoginController.php:45 | high | ADD: [nama] · KEEP: [nip, password] · REMOVE: [] |
| C-007 | CONFIRMED | UNKNOWN | dynamic route detected; heuristic cannot classify | low | n/a |
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
| ID | Vault Claim | Codebase Reality | Resolution Needed |
|---|---|---|---|
| X-001 | ... | ... | KEEP_VAULT / KEEP_CODE / DEFER / SPLIT |

## Open Questions (N)
| ID | Question | Source | Auto-resolve attempted |
|---|---|---|---|
| OQ-001 | ... | <vault file:line> | N/A (fresh OQ) |

## Auto-Resolved Deferred OQs (N)
| OQ-ID | Question | Evidence (codebase-map) | Status |
|---|---|---|---|
...
```

Bound-vault annotation format (HTML comments injected into the `<vault>/bound/` copy) is specified in `binding-contract.md`.
