---
description: Compare a vault against the actual codebase and report drift (missing entities, renamed fields, undocumented endpoints, mode-migration gaps).
argument-hint: "[path/to/vault] [path/to/codebase]"
---

Invoke the `mega-sdd:detect-drift` skill via the Skill tool to reconcile a vault against a live codebase.

User arguments (vault path, codebase root, scope filters): $ARGUMENTS

Follow the skill exactly:
- Read the vault (especially `03-data-model.md`, `02-architecture.md`, `vault.json`).
- Inspect the codebase for entities, fields, endpoints, and flows.
- Categorize drift: vault-only (documented but missing in code), code-only (implemented but undocumented), name/shape mismatches.
- For `IMPLEMENTATION_MODE=existing` vaults past `mode_migrate_after`, surface migration-readiness gaps separately.
- Produce `DRIFT-REPORT.md` with confidence-rated findings; never edit the vault or code automatically.
