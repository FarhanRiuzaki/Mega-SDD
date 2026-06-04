---
generated_by: mega-sdd:extract-intelligence
domain: lc-amendments
classification: workflow
criticality: high
verified_count: 4
inferred_count: 1
open_count: 0
---

# LC Amendments

## 6. Business Rules

- **BR-amend-1**: An approved amendment must trigger the downstream SWIFT dispatch + facility re-balance. `[VERIFIED][INTENT]` (`approval/act_amend.php:39-71`). Captured as a BUSINESS OUTCOME — the rebuild owns the encoding (no legacy status value pinned here).

## 8. State Machine

- Maker submits → SPV reviews (read predicate filters the worklist) → dispatch. Writer and reader both cited. `[VERIFIED]` (`approval/spv_worklist.php:120`).

## 11. Source References

- `approval/act_amend.php:39-71`
- `approval/spv_worklist.php:120`
