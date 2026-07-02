---
type: prose
doc_id: constitution
constitution_version: "1.0.0"
---

# Constitution — Sample Project

## §A — Coding standards

- **A-001**: TypeScript strict mode. No `any` types. (source: codebase-map §conventions)
- **A-002**: All functions must have explicit return types. (source: codebase-map §conventions)
- **A-003**: Use ESM imports, not CommonJS require(). (source: tsconfig.json:3)

## §B — Security

- **B-001**: Argon2id for password hashing. Never bcrypt/MD5. (source: PRD §security)
- **B-002**: All API endpoints require authentication middleware. (source: binding §scan_results)

## §C — Testing

- **C-001**: Minimum 80% branch coverage for new code. (source: PRD §quality-bar)
