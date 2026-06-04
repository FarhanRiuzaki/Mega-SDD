---
generated_by: mega-sdd:extract-intelligence
domain: lc-amendments
classification: workflow
criticality: high
verified_count: 3
inferred_count: 2
open_count: 0
---

# LC Amendments

## 6. Business Rules

- **BR-amend-1**: Amendment writes flag_amend and update_status. `[VERIFIED]` (`approval/act_amend.php:39-71`).

## 8. State Machine

- Maker submits → dispatch. No read-side predicate documented; the P1 anomalies in the
  scorecard are NOT surfaced as open-question markers in this KB — the hidden gap the validator must catch.

## 11. Source References

- `approval/act_amend.php:39-71`
