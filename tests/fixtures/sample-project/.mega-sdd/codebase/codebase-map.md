---
generated_by: mega-sdd:scan-codebase
generated_at: 2026-05-27T00:00:00Z
repo_root: ./
scan_depth: 5
scan_includes: ["src/**"]
scan_excludes: ["node_modules/**"]
languages_detected: ["typescript"]
package_managers: ["npm"]
test_frameworks: ["jest"]
engine: regex
precision_tier: regex
---

# Codebase Map

## 1. Top-level structure

```
src/
├── models/
│   ├── user.ts
│   └── leave-request.ts
├── controllers/
│   └── leave.ts
├── middleware/
│   ├── auth.ts
│   └── gdpr.ts
├── validators/
│   └── leave.ts
├── config/
│   ├── leave-policies.ts
│   └── accessibility.ts
└── app.ts
```

## 2. Public interfaces

| File | Type | Symbol | Signature |
|---|---|---|---|
| src/models/user.ts | class | User | { id: string, email: string, name: string, role: string } |
| src/models/leave-request.ts | class | LeaveRequest | { id: string, userId: string, startDate: Date, endDate: Date } |
| src/controllers/leave.ts | function | submitLeave | (req: Request, res: Response) => void |
| src/middleware/auth.ts | function | requireAuth | (req, res, next) => void |

## 3. Routes / Endpoints

| Method | Path | Handler |
|---|---|---|
| POST | /api/leave | leave.submitLeave |
| GET | /api/leave/:id | leave.getLeave |
| PATCH | /api/leave/:id/approve | leave.approveLeave |

## 4. Data models / Schemas

| Entity | File | Fields |
|---|---|---|
| User | src/models/user.ts | id, email, name, role, created_at |
| LeaveRequest | src/models/leave-request.ts | id, user_id, start_date, end_date, type, status |

## 5. Naming conventions

- Case style: camelCase
- File suffix: .ts
- Test files: .test.ts

## 6. Pattern signatures

- Auth pattern: middleware
- Error handling: try-catch
- State: none

## 7. Framework

framework:
  name: express
  version: "4.x"
  confidence: high
  pack_path: _universal.md
  detection_source: package.json express dependency
