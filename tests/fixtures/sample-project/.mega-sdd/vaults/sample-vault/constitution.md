---
type: prose
doc_id: constitution
constitution_version: "1.0.0"
---

# Constitution — Sample Project

## §A — Coding standards

- **A-001**: TypeScript strict mode. No `any` types.
- **A-002**: All functions must have explicit return types.
- **A-003**: Use ESM imports, not CommonJS require().

## §B — Security

- **B-001**: Argon2id for password hashing. Never bcrypt/MD5.
- **B-002**: All API endpoints require authentication middleware.

## §C — Testing

- **C-001**: Minimum 80% branch coverage for new code.
