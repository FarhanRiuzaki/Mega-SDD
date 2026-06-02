---
unit_id: U-001 Widget widgets
title:  migration +  model
task_type: create
phase: 1
module: catalog
scope: branch-scoped
loc_budget: 150
---

# U-001 Widget widgets  migration +  model

## Hard rules
- `branch_id` UUID FK branches (denormalized for BranchScoped direct hop)
- Model uses `BranchScoped` global scope (direct branch_id)
- DO NOT add new composer dependencies

## Implementation steps
1. Create migration creating `` with a `branch_id` UUID FK.
2. Create model `app/Models/.php`:
   - `HasUuids`, `BranchScoped` global scope (direct branch_id)
   - Relationships: `branch()` belongsTo Branch

## Target files
```
app/Models/.php
```

## Acceptance
- Migration runs cleanly
