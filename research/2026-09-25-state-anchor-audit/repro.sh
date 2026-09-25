#!/usr/bin/env bash
# repro.sh <outdir> — Fase 0 state-anchor audit, lane X2 (see ../2026-09-25-state-anchor-audit.md §5): reproduce the FE-team drift scenario on a
# monorepo-shaped playground and capture byte-exact what mega-sdd hands the model.
#
# Everything is rebuilt from scratch under <outdir>:
#   <outdir>/pg              the playground (git repo; apps/web = FE scope, apps/api = BE scope,
#                            ONE .mega-sdd/ at the root holding TWO vaults: api (classic, legacy
#                            7-file + binding.md/binding.json/bound/claims-ledger) and web
#                            (lite, layout-3 context.md + per-unit bolts/U-*/binding.json))
#   <outdir>/home            sandbox HOME (the session-start hook installs a wrapper into $HOME)
#   <outdir>/work/<cp>/...   throw-away COPIES the probes run on (every probe mutates state)
#   <outdir>/captures/<cp>/  raw captures: <name>.stdout / .stderr / .rc / .cmd
#   <outdir>/captures/_normalized/  same tree, SHAs -> labels, paths -> <OUT>, timestamps -> <TS>
#   <outdir>/labels.tsv      label -> sha map used by the normalizer
# The plugin under R is only READ/EXECUTED (never written): PYTHONDONTWRITEBYTECODE=1 and a
# find -newer marker check at the end prove it.
set -uo pipefail
[ $# -ge 1 ] || { echo "usage: repro.sh <outdir>" >&2; exit 2; }
# R = repo root, derived from this file's location (research/2026-09-25-state-anchor-audit/repro.sh).
R="$(cd "$(dirname "$0")/../.." && pwd -P)"
P="$R/plugins/mega-sdd"; S="$P/scripts"
case "$1" in "$R"|"$R"/*) echo "refusing: outdir inside R" >&2; exit 2;; esac
rm -rf "$1"; mkdir -p "$1"; OUT="$(cd "$1" && pwd -P)"
export PYTHONDONTWRITEBYTECODE=1 TZ=UTC GIT_CONFIG_NOSYSTEM=1
export HOME="$OUT/home"
mkdir -p "$HOME/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.0"
unset ANTHROPIC_BASE_URL CLAUDE_PROJECT_DIR CLAUDE_SESSION_ID CLAUDE_PLUGIN_ROOT || true
MARK="$OUT/.r-marker"; touch "$MARK"; sleep 1
R_STATUS_BEFORE="$(git -C "$R" status --porcelain 2>/dev/null)"
PG="$OUT/pg"; CAP="$OUT/captures"; WORK="$OUT/work"; LABELS="$OUT/labels.tsv"
mkdir -p "$CAP" "$WORK"; : > "$LABELS"
GW_URL="https://ai-gateway.mono.test"
T_OLD=202609010000   # PRD mtimes (older than every vault doc -> never prd_revision by accident)
log() { printf '[repro] %s\n' "$*" >&2; }

# ─── git helpers (fixed identities + dates; SHAs still vary because tracked artifacts carry
# writer timestamps — the normalizer maps every SHA to its label) ─────────────────────────
commit_as() { # dir who date msg [more -m args...]
  local d="$1" who="$2" when="$3"; shift 3
  local n e
  case "$who" in
    platform) n=platform e=platform@mono.test ;;
    be)       n=be-dev   e=be-dev@mono.test ;;
    fe)       n=fe-dev   e=fe-dev@mono.test ;;
    femate)   n=fe-mate  e=fe-mate@mono.test ;;
    *) echo "unknown author $who" >&2; return 2 ;;
  esac
  GIT_AUTHOR_NAME="$n" GIT_AUTHOR_EMAIL="$e" GIT_COMMITTER_NAME="$n" GIT_COMMITTER_EMAIL="$e" \
  GIT_AUTHOR_DATE="$when" GIT_COMMITTER_DATE="$when" git -C "$d" commit -q "$@"
}
label() { printf '%s\t%s\n' "$1" "$(git -C "$2" rev-parse HEAD)" >> "$LABELS"; }
pin_mtimes() { # dir stamp — every non-.git file to <stamp>, PRDs to T_OLD
  /usr/bin/find "$1" -path "$1/.git" -prune -o -exec /usr/bin/touch -h -t "$2" {} + 2>/dev/null
  /usr/bin/touch -t "$T_OLD" "$1"/docs/PRD-*.md 2>/dev/null || true
}
sha256() { /usr/bin/shasum -a 256 "$1" | cut -c1-64; }

# ═════════════════════════════════════════════════════════════════════════════
# S0 — seed the monorepo (platform author)
# ═════════════════════════════════════════════════════════════════════════════
log "S0 seed"
mkdir -p "$PG/apps/web/src/pages" "$PG/apps/web/src/components" "$PG/apps/web/src/api" "$PG/apps/api" "$PG/docs"
cp -R "$R/tests/blackbox/fixture/src" "$PG/apps/api/src"
cp "$R/tests/blackbox/fixture/docs/PRD-leave.md" "$PG/docs/PRD-leave.md"
cat > "$PG/package.json" <<'EOF'
{
  "name": "mono",
  "private": true,
  "workspaces": ["apps/*"],
  "scripts": { "test": "node -e \"console.log('mono suite: 0 tests, ok')\"" }
}
EOF
printf '{\n  "name": "web",\n  "private": true,\n  "dependencies": { "react": "^18.2.0" }\n}\n' > "$PG/apps/web/package.json"
printf '{\n  "name": "mono/api",\n  "require": { "php": ">=8.1" }\n}\n' > "$PG/apps/api/composer.json"
cat > "$PG/apps/web/src/pages/Login.tsx" <<'EOF'
import { LoginForm } from "../components/LoginForm";

export default function LoginPage() {
  return (
    <main className="login-page">
      <h1>Sign in</h1>
      <LoginForm />
    </main>
  );
}
EOF
cat > "$PG/apps/web/src/components/LoginForm.tsx" <<'EOF'
import { useState } from "react";
import { login } from "../api/client";

export function LoginForm() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    await login(email, password);
  }
  return (
    <form onSubmit={handleSubmit}>
      <input value={email} onChange={(e) => setEmail(e.target.value)} />
      <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} />
      <button type="submit">Sign in</button>
    </form>
  );
}
EOF
cat > "$PG/apps/web/src/api/client.ts" <<'EOF'
// HTTP client for the web app (FE scope)
export const BASE_URL = "/api/v1";

export interface LoginResponse { token: string; expiresIn: number }

export async function login(email: string, password: string): Promise<LoginResponse> {
  const res = await fetch(`${BASE_URL}/auth/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, password }),
  });
  if (!res.ok) throw new Error(`login failed: ${res.status}`);
  return res.json();
}

export async function logout(token: string): Promise<void> {
  await fetch(`${BASE_URL}/auth/logout`, { method: "POST", headers: { Authorization: `Bearer ${token}` } });
}
EOF
cat > "$PG/docs/PRD-web-login.md" <<'EOF'
# PRD — Web Login (apps/web)

## §2.1 Validation
- AC-W1: the login form rejects a malformed email before any network call.

## §2.2 Remember me
- AC-W2: the login request carries a `rememberMe` flag chosen by the user.
EOF
# .gitignore = the 8.7.2 "always" block (references/paths.md §Recommended .gitignore) PLUS two
# DEVIATIONS for this audit: .mega-sdd/codebase/ and .mega-sdd/state.json are ignored so the
# freshness stamps can equal HEAD at A (a tracked stamped file can never equal the commit that
# contains it). The literal 8.7.2 setup is measured separately (variant V-872).
cat > "$PG/.gitignore" <<'EOF'
node_modules/
# --- mega-sdd 8.7.2 "always" block ---
.mega-sdd/.validation-blockers.json
.mega-sdd/.ui-quality-blockers.json
.mega-sdd/.*-state.json
.mega-sdd/.analyze-freshness.json
.mega-sdd/.locked-files-index.json
.mega-sdd/.stop-scan-stamp
.mega-sdd/.ptu-scan-stamp
.mega-sdd/.cache/
.mega-sdd/codebase/.dirty-paths.jsonl
# --- X2 audit deviation (see repro.sh header) ---
.mega-sdd/codebase/
.mega-sdd/state.json
EOF
git -C "$PG" init -q -b main
git -C "$PG" config user.name fe-dev; git -C "$PG" config user.email fe-dev@mono.test
git -C "$PG" config commit.gpgsign false; git -C "$PG" config core.autocrlf false
git -C "$PG" add -A
commit_as "$PG" platform "2026-09-20T09:00:00+07:00" -m "chore: monorepo baseline (apps/web + apps/api)"
label S0 "$PG"

# ═════════════════════════════════════════════════════════════════════════════
# Vaults + units at S0 (model-written artifacts SIMULATED per the shipped grammars; every
# derived artifact produced by the REAL plugin script)
# ═════════════════════════════════════════════════════════════════════════════
log "vaults at S0"
VA="$PG/.mega-sdd/vaults/api"; VW="$PG/.mega-sdd/vaults/web"
mkdir -p "$VA" "$VW/units" "$VA/units"
# ── BE vault `api`: legacy 7-file canonical (blackbox recipe) ──
cp "$P/tests/graph/fixtures/derive-vault/"0*.md "$VA/"
cp "$P/tests/graph/fixtures/derive-vault/authored-patch.json" "$OUT/api-patch.json"
bash "$S/derive-vault-json.sh" --vault "$VA" --patch "$OUT/api-patch.json" </dev/null >"$OUT/build.log" 2>&1
bash "$S/derive-claims-ledger.sh" --vault "$VA" </dev/null >>"$OUT/build.log" 2>&1
S0SHA="$(git -C "$PG" rev-parse HEAD)"
cat > "$VA/binding.md" <<EOF
---
vault: api
codebase_map: .mega-sdd/codebase/codebase-map.md
bound_at: 2026-09-20T02:10:00Z
strict: false
binding_metadata:
  codebase_map_provenance: snapshot-verified
  head: $S0SHA
---

# Binding Manifest

## Summary
- claims_total: 4
- confirmed: 3
- conflict: 0
- oq: 1

## Confirmed Claims (3)
- C-001 | 03-data-model.md:7 | apps/api/src/models/LeaveRequest.php:3 | LeaveRequest entity exists
- C-044 | 04-flows.md:12 | apps/api/src/services/ApprovalService.php:8 | approval flow exists
- C-050 | 03-data-model.md:7 | apps/api/src/models/Employee.php:3 | Employee entity owns the role enum

## Implementation State Map (4 — ALWAYS 6 columns; the Field diff cell is \`n/a\` unless precision_tier: ast)
| Claim ID | Verdict | State | Anchor | Confidence | Field diff |
|---|---|---|---|---|---|
| C-001 | CONFIRMED | IMPLEMENTED | apps/api/src/models/LeaveRequest.php:3 | high | (exact match) |
| C-012 | OQ | NEW | — | n/a | n/a |
| C-044 | CONFIRMED | IMPLEMENTED | apps/api/src/services/ApprovalService.php:8 | high | n/a |
| C-050 | CONFIRMED | UNKNOWN | apps/api/src/models/Employee.php:3 | medium | n/a |

## Conflicts (0)

### ✅ CONFLICT-1 RESOLVED (KEEP_VAULT — code update pending) — employee role collision
- **Claim**: C-050
- **Vault claim**: vault Employee entity owns the role enum (03-data-model.md §Employee)
- **Codebase reality**: pre-existing Employee model already defines role (apps/api/src/models/Employee.php:3)
- **conflict_class**: naming-collision
- **resolution_complexity**: low
- **Verdict**: CONFIRMED
- **Suggested action**: KEEP_VAULT — vault Employee is the target entity (apps/api/src/models/Employee.php:3)
- **Resolution**: ✅ RESOLVED (KEEP_VAULT) 2026-09-20 — vault correct; code change lands via U-010

## Open Questions (1)
| ID | Question | Source | Auto-resolve attempted |
|---|---|---|---|
| OQ-001 | which notification channel? | 04-flows.md:39 | N/A (fresh OQ) |
EOF
bash "$S/derive-binding-json.sh" --vault "$VA" </dev/null >>"$OUT/build.log" 2>&1
bash "$S/make-bound.sh" --vault "$VA" </dev/null >>"$OUT/build.log" 2>&1
cat > "$VA/units/U-010.md" <<'EOF'
---
id: U-010
title: Approval endpoint wiring
vault_source: 04-flows.md:F-U-001
task_type: extend
binding_refs:
  - C-044
  - CONFLICT-1
target_files:
  - path: apps/api/src/services/ApprovalService.php
    operation: edit
  - path: apps/api/src/routes.php
    operation: create
acceptance_test:
  - type: test
    command: "test -f apps/api/src/routes.php && echo routes-present"
    expects: "routes-present"
mutability: "INTENT — approval flow shape follows PRD §3.2 (maker-checker)"
---

## Goal
Wire the approval flow route to ApprovalService per vault 04-flows.md F-U-001.

## Context (read first)
Per binding C-044 the approval flow exists in ApprovalService; this unit adds the route wiring only.

## Anchors
- apps/api/src/services/ApprovalService.php:8 — approveRequest (binding C-044)

## Hard rules
- DO NOT modify apps/api/src/config/limits.php
  Source: binding C-044 — policy constants frozen per PRD §3.2
- function approveRequest MUST preserve signature: public function approveRequest(int $requestId, int $approverId, string $note): bool
  Source: binding C-044 anchor apps/api/src/services/ApprovalService.php:8

## Anti-patterns
- Don't bypass the maker-checker role check.

## Implementation steps
Create apps/api/src/routes.php exposing POST /leave/approve calling ApprovalService::approveRequest.

## Migration notes
- ADD: apps/api/src/routes.php (new file, this unit).
- KEEP: ApprovalService::approveRequest contract (apps/api/src/services/ApprovalService.php:8, binding C-044).
- REMOVE: nothing.

## Acceptance criteria
See frontmatter `acceptance_test` (structured authority).
EOF
# ── FE vault `web`: layout-3 (plan-born, lite lane shape) ──
PRDW_SHA="$(sha256 "$PG/docs/PRD-web-login.md")"
cat > "$VW/context.md" <<EOF
---
type: context
doc_id: context
vault_layout: 3
vault_version: "1.0"
project_shape: web-app
implementation_mode: existing
mode_migration_trigger: null
prd_status: approved
output_mode: compact
project_scale: xs
prd_path_at_generation: docs/PRD-web-login.md
prd_sha256: $PRDW_SHA
author: fe-dev
stakeholders: ["PM web"]
---

# Context: Web Login

## Overview

Login page of the web app (apps/web) — the FE scope of the monorepo.

## Flows

### F-U-001: Validate login email

**Flow**:
\`\`\`mermaid
flowchart TD
    A["Submit login form"] --> B{"Email well-formed?"}
    B -- no --> C["Show inline error"]
    B -- yes --> D["Call login()"]
\`\`\`

**Definition of Done**:
- [ ] malformed email blocked client-side

**Source**: PRD §2.1 (AC-W1)

### F-U-002: Remember me

**Flow**:
\`\`\`mermaid
flowchart TD
    A["Remember-me chosen"] --> B["login() sends rememberMe"]
\`\`\`

**Definition of Done**:
- [ ] rememberMe flag in the request body

**Source**: PRD §2.2 (AC-W2)

## Data model

\`\`\`dbml
// Purpose: client-side session token
Table session {
  token varchar [pk]
  expires_in int
}
\`\`\`

### session

- **Purpose**: client-side session token
- **Key fields**: token, expires_in

## Constraints

### Non-functional requirements

| Category | Requirement | Source |
|---|---|---|
| Performance | login round-trip < 1s | PRD §2 |

## Decisions

### D-001: Keep fetch()
No new HTTP dependency. **Decision**: native fetch. **Source**: PRD §2.

## Open Questions

- [x] **OQ-FL-1** [P1] [business] [origin: context.md#F-U-002]: default of remember me? → **Resolved v1.0** (2026-09-20): unchecked.
- [ ] **OQ-CN-2** [P3] [business] [origin: context.md#Constraints]: session lifetime per role?
EOF
cp "$R/tests/v8-layout3/fixtures/context-vault/constitution.md" "$VW/constitution.md"
cat > "$VW/units/U-001.md" <<'EOF'
---
id: U-001
title: Login form client-side email validation
prd_source: docs/PRD-web-login.md#2-1-validation
context_source: context.md#F-U-001
task_type: extend
depends_on: []
target_files:
  - path: apps/web/src/components/LoginForm.tsx
    operation: modify
acceptance_test:
  - type: test
    command: "grep -n validateEmail apps/web/src/components/LoginForm.tsx"
    expects: "validateEmail"
---

## Goal
Reject a malformed email before login() is called (PRD §2.1 AC-W1).

## Anchors
- apps/web/src/components/LoginForm.tsx:7 — handleSubmit (the submit handler the validation hooks into)
- apps/web/src/pages/Login.tsx:7 — LoginForm mount point

## Claims
- C-U001-01 "login form component exists" — expect: apps/web/src/components/LoginForm.tsx — must-exist

## Hard rules
- DO NOT modify apps/web/src/api/client.ts
  Source: context.md#F-U-002 — the API client belongs to U-002

## Implementation steps
Add validateEmail() and call it from handleSubmit before login().

## Migration notes
- ADD: validateEmail() in apps/web/src/components/LoginForm.tsx.
- KEEP: handleSubmit contract (apps/web/src/components/LoginForm.tsx:7); login() untouched.
- REMOVE: nothing.

## Acceptance criteria
See frontmatter `acceptance_test` (structured authority).
EOF
cat > "$VW/units/U-002.md" <<'EOF'
---
id: U-002
title: Login client sends the remember-me flag
prd_source: docs/PRD-web-login.md#2-2-remember-me
context_source: context.md#F-U-002
task_type: extend
depends_on: []
target_files:
  - path: apps/web/src/api/client.ts
    operation: modify
existing_interfaces:
  - file: apps/web/src/api/client.ts
    symbol: login
acceptance_test:
  - type: test
    command: "grep -n rememberMe apps/web/src/api/client.ts"
    expects: "rememberMe"
---

## Goal
Send the remember-me flag with the login request (PRD §2.2 AC-W2).

## Anchors
- apps/web/src/api/client.ts:6 — login() request contract (the JSON body gains rememberMe)
- apps/web/src/api/client.ts:16 — logout() (must keep working)

## Claims
- C-U002-01 "login() lives in the API client" — expect: apps/web/src/api/client.ts:login

## Hard rules
- DO NOT modify apps/web/src/components/LoginForm.tsx
  Source: context.md#F-U-001 — the form belongs to U-001

## Implementation steps
Add `rememberMe: boolean` to login() and include it in the JSON body.

## Migration notes
- ADD: rememberMe parameter on login() (apps/web/src/api/client.ts:6).
- KEEP: logout() (apps/web/src/api/client.ts:16) unchanged.
- REMOVE: nothing.

## Acceptance criteria
See frontmatter `acceptance_test` (structured authority).
EOF
bash "$S/derive-vault-json.sh" --vault "$VW" </dev/null >>"$OUT/build.log" 2>&1
# ── codebase-map (classic substrate) via the real deterministic assembler; the delta dir is the
# model-written input (hand-written here, shape copied from tests/token-efficiency/test-derive-codebase-map.sh)
mkdir -p "$PG/.mega-sdd/codebase/.scan" "$OUT/delta-full" "$OUT/delta-merge"
git -C "$PG" ls-files -z -- apps > "$PG/.mega-sdd/codebase/.scan/files.z"
printf '{"scan_depth": 5, "languages_detected": ["typescript", "php"], "package_managers": ["npm", "composer"], "test_frameworks": [], "engine": "regex", "precision_tier": "regex"}\n' > "$OUT/delta-full/frontmatter.json"
cat > "$OUT/delta-full/s2.rows" <<'EOF'
| apps/web/src/api/client.ts | function | login | (email: string, password: string) => Promise<LoginResponse> |
| apps/web/src/api/client.ts | function | logout | (token: string) => Promise<void> |
| apps/web/src/components/LoginForm.tsx | function | LoginForm | () => JSX.Element |
| apps/web/src/pages/Login.tsx | function | LoginPage | () => JSX.Element |
| apps/api/src/services/ApprovalService.php | class | ApprovalService | approveRequest(int, int, string): bool |
EOF
printf '| POST | /leave/approve | ApprovalService.approveRequest |\n| POST | /api/v1/auth/login | (external, consumed by apps/web client.ts) |\n' > "$OUT/delta-full/s3.rows"
printf '| LeaveRequest | apps/api/src/models/LeaveRequest.php | id, employeeId, status, approvedBy |\n| Employee | apps/api/src/models/Employee.php | id, email, role, leaveBalance |\n' > "$OUT/delta-full/s4.rows"
printf -- '- Case style: camelCase (TS), camelCase members (PHP)\n' > "$OUT/delta-full/s5.md"
printf -- '- Auth pattern: bearer token issued by /auth/login\n' > "$OUT/delta-full/s6.md"
printf 'framework:\n  name: react\n  version: "18.x"\n  confidence: medium\n  pack_path: _universal.md\n  detection_source: apps/web/package.json react dependency\n' > "$OUT/delta-full/s7.md"
printf '{}' > "$OUT/delta-merge/frontmatter.json"
bash "$S/derive-codebase-map.sh" --cwd="$PG" --mode=full --delta="$OUT/delta-full" --plugin-root="$P" --quiet </dev/null >>"$OUT/build.log" 2>&1
# GROUND at S0 (index + state.json + the C1 battery's vault.json mode guard)
bash "$S/ground.sh" --cwd="$PG" </dev/null >>"$OUT/build.log" 2>&1
# ── JIT bind wave 1 (U-001 + U-002) — execute-bolts pre-flight 3.9, real writers ──
bash "$S/check-anchor-freshness.sh" --cwd="$PG" --units=U-001,U-002,U-010 </dev/null >>"$OUT/build.log" 2>&1
bash "$S/derive-unit-claims.sh" --cwd="$PG" --vault="$VW" --units=U-001,U-002 </dev/null >>"$OUT/build.log" 2>&1
for u in U-001 U-002; do bash "$S/write-unit-binding.sh" --cwd="$PG" --vault="$VW" --unit=$u --claims="$VW/bolts/_wave-claims.json" </dev/null >>"$OUT/build.log" 2>&1; done
bash "$S/validate-handoff-binding-units.sh" --cwd="$PG" --units=U-001,U-002 --quiet </dev/null >>"$OUT/build.log" 2>&1
bash "$S/run-preflight-scan.sh" --cwd="$PG" --units=U-010,U-001 </dev/null >>"$OUT/build.log" 2>&1
bash "$S/build-dispatch-prompt.sh" --cwd="$PG" --vault="$VA" --unit=U-010 --plugin-root="$P" --quiet </dev/null >>"$OUT/build.log" 2>&1
bash "$S/build-dispatch-prompt.sh" --cwd="$PG" --vault="$VW" --unit=U-001 --plugin-root="$P" --quiet </dev/null >>"$OUT/build.log" 2>&1

# ── the two bolts (code commits, canonical identity + trailers) ──
log "bolts"
printf '<?php\n// POST /leave/approve -> ApprovalService::approveRequest\nrequire_once __DIR__ . "/services/ApprovalService.php";\n' > "$PG/apps/api/src/routes.php"
echo "// route wired by U-010" >> "$PG/apps/api/src/services/ApprovalService.php"
git -C "$PG" add apps/api/src/routes.php apps/api/src/services/ApprovalService.php
commit_as "$PG" be "2026-09-20T10:00:00+07:00" -m "feat(U-010): Approval endpoint wiring" -m "Route POST /leave/approve to ApprovalService." \
  -m "Refs: 04-flows.md:F-U-001
Binding: C-044
Tests: 1 passing
Unit: U-010
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-010
SDD-Acceptance: v5"
label BOLT_BE "$PG"
python3 - "$PG/apps/web/src/components/LoginForm.tsx" <<'PY'
import sys; p=sys.argv[1]; s=open(p).read()
s=s.replace("    await login(email, password);\n", "    if (validateEmail(email)) await login(email, password);\n")
s+="\nexport function validateEmail(v: string): boolean {\n  return /^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$/.test(v);\n}\n"
open(p,"w").write(s)
PY
git -C "$PG" add apps/web/src/components/LoginForm.tsx
commit_as "$PG" fe "2026-09-20T10:10:00+07:00" -m "feat(U-001): Login form client-side email validation" -m "validateEmail() guards handleSubmit." \
  -m "Refs: context.md#F-U-001
Tests: 1 passing
Unit: U-001
SDD-PROVENANCE: mega-sdd/execute-bolts unit=U-001
SDD-Acceptance: v5"
label BOLT_FE "$PG"
for u in U-010 U-001; do
  bash "$S/run-postflight-scan.sh" --cwd="$PG" --unit=$u </dev/null >>"$OUT/build.log" 2>&1
  bash "$S/run-acceptance-tests.sh" --cwd="$PG" --unit=$u </dev/null >>"$OUT/build.log" 2>&1
done
write_report() { # vault unit status targets...
  local v="$1" u="$2"; shift 2
  { printf -- '---\nunit: %s\nstatus: completed\ncommit: %s\ntarget_hashes:\n' "$u" "$(git -C "$PG" log -1 --format=%H --grep="($u)")"
    for f in "$@"; do printf '  %s: %s\n' "$f" "$(sha256 "$PG/$f")"; done
    printf -- '---\n# Bolt report %s\n\n## Summary\nImplemented per unit; acceptance + postflight recorded by their script writers.\n' "$u"; } > "$v/bolts/$u/bolt-report.md"
}
write_report "$VA" U-010 apps/api/src/services/ApprovalService.php apps/api/src/routes.php
write_report "$VW" U-001 apps/web/src/components/LoginForm.tsx
bash "$S/run-full-suite.sh" --cwd="$PG" </dev/null >>"$OUT/build.log" 2>&1
git -C "$PG" add -A .mega-sdd
commit_as "$PG" fe "2026-09-20T10:20:00+07:00" -m "chore(sdd): evidence U-010, U-001 — vaults, units, bolt evidence"
label A "$PG"
# post-commit "sync": re-stamp the (gitignored) map + index at A — what /mega-sdd:sync leaves behind
bash "$S/derive-codebase-map.sh" --cwd="$PG" --mode=merge --delta="$OUT/delta-merge" --plugin-root="$P" --quiet </dev/null >>"$OUT/build.log" 2>&1
bash "$S/ground.sh" --cwd="$PG" </dev/null >>"$OUT/build.log" 2>&1
rm -f "$PG/.mega-sdd/codebase/.dirty-paths.jsonl"
pin_mtimes "$PG" 202609201030
cp -a "$PG" "$WORK/pgA"   # frozen A snapshot (controls + variants branch off it)

# ═════════════════════════════════════════════════════════════════════════════
# Checkpoint edit functions (deterministic; applied to the main chain AND to controls)
# ═════════════════════════════════════════════════════════════════════════════
do_B() { # BE team: touch ONLY apps/api/** (an anchored BE model) — out of FE scope
  local d="$1"
  python3 - "$d/apps/api/src/models/LeaveRequest.php" <<'PY'
import sys; p=sys.argv[1]; s=open(p).read()
s=s.replace("    public ?int $approvedBy = null;\n", "    public ?int $approvedBy = null;\n    public ?string $rejectReason = null;\n")
open(p,"w").write(s)
PY
  git -C "$d" add apps/api/src/models/LeaveRequest.php
  commit_as "$d" be "2026-09-21T09:00:00+07:00" -m "feat(api): leave request carries a reject reason"
}
do_C1() { # FE teammate: change content of FE unit targets, NO line shift
  local d="$1"
  python3 - "$d/apps/web/src/api/client.ts" "$d/apps/web/src/components/LoginForm.tsx" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
s=s.replace('export const BASE_URL = "/api/v1";','export const BASE_URL = "/api/v2";')
s=s.replace("if (!res.ok) throw new Error(`login failed: ${res.status}`);","if (!res.ok) throw new Error(`auth/login returned ${res.status}`);")
open(p,"w").write(s)
q=sys.argv[2]; t=open(q).read()
t=t.replace('<button type="submit">Sign in</button>','<button type="submit" disabled={!email}>Sign in</button>')
open(q,"w").write(t)
PY
  git -C "$d" add apps/web/src/api/client.ts apps/web/src/components/LoginForm.tsx
  commit_as "$d" femate "2026-09-21T10:00:00+07:00" -m "fix(web): v2 auth endpoint + disable empty submit"
}
do_C2() { # FE teammate: insert lines ABOVE the anchored line client.ts:6 (anchor still resolves)
  local d="$1"
  python3 - "$d/apps/web/src/api/client.ts" <<'PY'
import sys; p=sys.argv[1]; s=open(p).read()
ins=("export async function refreshToken(token: string): Promise<LoginResponse> {\n"
     "  const res = await fetch(`${BASE_URL}/auth/refresh`, { method: \"POST\", headers: { Authorization: `Bearer ${token}` } });\n"
     "  return res.json();\n"
     "}\n\n")
s=s.replace("export async function login(", ins+"export async function login(",1)
open(p,"w").write(s)
PY
  git -C "$d" add apps/web/src/api/client.ts
  commit_as "$d" femate "2026-09-21T11:00:00+07:00" -m "feat(web): token refresh helper"
}
do_D() { # FE dev's own uncommitted WIP in FE scope (IDE edit — NOT through Claude, so no journal row)
  local d="$1"
  python3 - "$d/apps/web/src/pages/Login.tsx" <<'PY'
import sys; p=sys.argv[1]; s=open(p).read()
s=s.replace('import { LoginForm } from "../components/LoginForm";\n',
            'import { LoginForm } from "../components/LoginForm";\n\nexport function useLoginRedirect(next: string): string {\n  return next.startsWith("/") ? next : "/";\n}\n',1)
open(p,"w").write(s)
PY
}
do_E() { # rewrite history: orphan-root squash of the whole branch + reflog expire + gc
  local d="$1"
  # --orphan keeps the index (= the old HEAD tree); D's unstaged WIP stays dirty, as a real dev's would
  git -C "$d" checkout -q --orphan rewritten
  commit_as "$d" platform "2026-09-22T09:00:00+07:00" -m "chore: squash history (force-pushed rewrite)"
  git -C "$d" branch -q -D main
  git -C "$d" branch -q -m rewritten main
  git -C "$d" reflog expire --expire=now --all
  git -C "$d" gc -q --prune=now 2>/dev/null
}

# ═════════════════════════════════════════════════════════════════════════════
# Helper python programs (derived VIEWS of on-disk state — labelled as such in captures)
# ═════════════════════════════════════════════════════════════════════════════
H="$OUT/helpers"; mkdir -p "$H"
cat > "$H/state_view.py" <<'PY'
# Selected fields of <root>/.mega-sdd/state.json (derive-state output) — a VIEW, not a capture.
import json, sys
d = json.load(open(sys.argv[1]))
p, dv = d["probes"], d["derived"]
out = {
 "root": d.get("root"),
 "derived": {k: dv.get(k) for k in ("position", "vault", "vault_path", "lane", "spine", "mode_inferred",
             "change_signal", "proposed_next", "drift_recent", "notes")},
 "probes.git": p.get("git"),
 "probes.codebase_map": p.get("codebase_map"),
 "probes.symbol_index": p.get("symbol_index"),
 "probes.dirty_journal_rows": p.get("dirty_journal_rows"),
 "probes.vaults": [{k: v.get(k) for k in ("name", "path", "layout", "has_context_md", "mode", "units_count",
                    "bolts_count", "binding", "pending_sync_open", "drift_report", "oq")} for v in p.get("vaults", [])],
}
print(json.dumps(out, indent=1, sort_keys=True))
PY
cat > "$H/gate_view.py" <<'PY'
# Status of every gate-state file under <root>/.mega-sdd — a VIEW of what the aggregator read.
import glob, json, os, sys
md = os.path.join(sys.argv[1], ".mega-sdd")
rows = {}
for f in sorted(glob.glob(os.path.join(md, ".*-state.json")) + [os.path.join(md, ".validation-blockers.json")]):
    try: d = json.load(open(f))
    except Exception as e: rows[os.path.basename(f)] = {"unreadable": str(e)}; continue
    r = {"status": d.get("status")}
    for k in ("halt_type", "out_of_band", "newest_code_commit", "detail", "stale"):
        if k in d: r[k] = d[k]
    if "drops" in d: r["drops"] = [{k: x.get(k) for k in ("type", "unit_id", "conflict_id", "changed_anchored_files", "binding_head", "current_head", "source_binding") if k in x} for x in d["drops"]]
    if "extras" in d: r["extras"] = [{k: x.get(k) for k in ("type", "unit_id", "source_binding", "binding_head", "current_head") if k in x} for x in d["extras"]]
    if "jit_units" in d: r["jit_units"] = d["jit_units"]
    if "issues" in d and isinstance(d["issues"], list): r["issues"] = [{k: x.get(k) for k in ("halt_type", "unit_id", "type") if k in x} for x in d["issues"]][:12]
    if os.path.basename(f) == ".gateguard-state.json": r = {"session_id": d.get("session_id"), "chain_engaged": d.get("chain_engaged"), "engaged_sessions": d.get("engaged_sessions")}
    rows[os.path.basename(f)] = r
print(json.dumps(rows, indent=1, sort_keys=True))
PY
cat > "$H/stamps_view.py" <<'PY'
# Every SHA-shaped provenance stamp mega-sdd left in the tree, with reachability vs the repo.
import glob, json, os, re, subprocess, sys
root = sys.argv[1]
def git(*a):
    return subprocess.run(["git", "-C", root] + list(a), capture_output=True, text=True)
head = git("rev-parse", "HEAD").stdout.strip()
rows = []
def add(src, key, val):
    if not val: rows.append({"file": src, "key": key, "value": None}); return
    v = str(val)
    full = git("rev-parse", "--verify", "--quiet", v + "^{commit}").stdout.strip()
    anc = (git("merge-base", "--is-ancestor", full, "HEAD").returncode == 0) if full else None
    rows.append({"file": src, "key": key, "value": v, "resolves": bool(full), "equals_HEAD": full == head if full else False, "ancestor_of_HEAD": anc})
md = os.path.join(root, ".mega-sdd")
def rel(p): return os.path.relpath(p, root)
m = os.path.join(md, "codebase", "codebase-map.md")
if os.path.isfile(m):
    mm = re.search(r"(?m)^last_scanned_commit:\s*(\S+)", open(m).read()); add(rel(m), "last_scanned_commit", mm.group(1) if mm else None)
for f, key in ((os.path.join(md, "codebase", "symbol-index.json"), "head_commit"),):
    if os.path.isfile(f):
        add(rel(f), key, json.load(open(f)).get(key))
st = os.path.join(md, "state.json")
if os.path.isfile(st):
    d = json.load(open(st)); add(rel(st), "probes.symbol_index.head_commit", (d["probes"].get("symbol_index") or {}).get("head_commit"))
    add(rel(st), "probes.codebase_map.last_scanned_commit", (d["probes"].get("codebase_map") or {}).get("last_scanned_commit"))
    add(rel(st), "probes.git.head", (d["probes"].get("git") or {}).get("head"))
for b in sorted(glob.glob(os.path.join(md, "vaults", "*", "binding.md"))):
    mm = re.search(r"(?m)^\s+head:\s*(\S+)", open(b).read()); add(rel(b), "binding_metadata.head", mm.group(1) if mm else None)
for b in sorted(glob.glob(os.path.join(md, "vaults", "*", "bolts", "*", "*.json"))):
    try: d = json.load(open(b))
    except Exception: continue
    if not isinstance(d, dict): continue
    for k in ("head", "head_sha", "base_sha"):
        if k in d: add(rel(b), k, d[k])
for b in sorted(glob.glob(os.path.join(md, "vaults", "*", "bolts", "*", "bolt-report.md"))):
    mm = re.search(r"(?m)^commit:\s*(\S+)", open(b).read()); add(rel(b), "commit", mm.group(1) if mm else None)
for b in sorted(glob.glob(os.path.join(md, "vaults", "*", "bolts", "*", "dispatch-prompt.md"))):
    for mm in re.finditer(r"index@([0-9a-f]{7,40})", open(b).read()): add(rel(b), "index@", mm.group(1))
print(json.dumps({"HEAD": head, "stamps": rows}, indent=1))
PY
cat > "$H/anchors_view.py" <<'PY'
# For every `## Anchors` path:line of every unit: the anchored line at checkpoint A (frozen copy)
# vs the working tree now. `same` = byte-identical line text.
import glob, os, re, sys
root, a_root = sys.argv[1], sys.argv[2]
TOK = re.compile(r"((?:[\w.\-]+/)*[\w.\-]+\.[A-Za-z]\w{0,7}):(\d+)")
def line(base, p, n):
    try: L = open(os.path.join(base, p), errors="replace").read().splitlines()
    except OSError: return None
    return L[n - 1] if 1 <= n <= len(L) else "<beyond EOF: %d lines>" % len(L)
for u in sorted(glob.glob(os.path.join(root, ".mega-sdd", "vaults", "*", "units", "U-*.md"))):
    t = open(u).read(); m = re.search(r"(?ms)^## Anchors[^\n]*\n(.*?)(?=^## |\Z)", t)
    if not m: continue
    for tok in TOK.finditer(m.group(1)):
        p, n = tok.group(1), int(tok.group(2)); a, now = line(a_root, p, n), line(root, p, n)
        print("%s  %s:%d  same=%s\n    A  : %s\n    now: %s" % (os.path.relpath(u, root), p, n, a == now, a, now))
PY
cat > "$H/normalize.py" <<'PY'
# captures/ -> captures/_normalized/: SHAs -> <LABEL>, <OUT> path, ISO timestamps -> <TS>.
import os, re, sys
out, cap = sys.argv[1], sys.argv[2]
labels = [l.rstrip("\n").split("\t") for l in open(os.path.join(out, "labels.tsv")) if "\t" in l]
subs = []
for lab, sha in labels:
    subs.append((sha, "<%s>" % lab))
for lab, sha in labels:
    for n in (12, 9, 8, 7):
        subs.append((sha[:n], "<%s:%d>" % (lab, n)))
ts = re.compile(r"\b20\d\d-\d\d-\d\d[T ]\d\d:\d\d:\d\d(?:\.\d+)?(?:Z|[+-]\d\d:?\d\d)?")
dur = re.compile(r"\b\d+\.\d+s\b")
cons = re.compile(r"consumed-\d+")
vsha = re.compile(r"vault_sha256: [0-9a-f]{64}")
fbytes = re.compile(r"(\"file_bytes\": |file_total: )\d+")
nd = os.path.join(cap, "_normalized")
for dp, dn, fn in os.walk(cap):
    if dp.startswith(nd): continue
    for f in fn:
        src = os.path.join(dp, f); dst = os.path.join(nd, os.path.relpath(src, cap))
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        try: s = open(src, encoding="utf-8", errors="replace").read()
        except Exception: continue
        s = s.replace(out, "<OUT>")
        for a, b in subs:
            if a: s = s.replace(a, b)
        s = ts.sub("<TS>", s); s = dur.sub("<DUR>", s); s = cons.sub("consumed-<EPOCH>", s); s = vsha.sub("vault_sha256: <VAULT_SHA256>", s); s = fbytes.sub(lambda m: m.group(1) + "<PATHLEN-DEPENDENT>", s)
        open(dst, "w", encoding="utf-8").write(s)
PY

# ═════════════════════════════════════════════════════════════════════════════
# Capture machinery — hooks run exactly as hooks.json states them (/bin/sh -c "<command>")
# ═════════════════════════════════════════════════════════════════════════════
hook_cmd() { # event index -> command string from hooks.json
  python3 -c 'import json,sys; h=json.load(open(sys.argv[1]))["hooks"][sys.argv[2]]; print(h[0]["hooks"][int(sys.argv[3])]["command"])' "$P/hooks/hooks.json" "$1" "$2"
}
SS_CMD0="$(hook_cmd SessionStart 0)"; SS_CMD1="$(hook_cmd SessionStart 1)"
UPS_CMD="$(hook_cmd UserPromptSubmit 0)"; PTU_CMD="$(hook_cmd PreToolUse 0)"; POST_CMD="$(hook_cmd PostToolUse 0)"
# cap <name> <cwd> <stdin-file|-> <env-assignments...> -- <cmd...>
cap() {
  local name="$1" dir="$2" in="$3"; shift 3
  local envs=()
  while [ $# -gt 0 ] && [ "$1" != "--" ]; do envs+=("$1"); shift; done
  shift
  [ "$in" = "-" ] && in=/dev/null
  ( cd "$dir" && env ${envs[@]+"${envs[@]}"} "$@" ) <"$in" >"$C/$name.stdout" 2>"$C/$name.stderr"
  echo $? > "$C/$name.rc"
  { printf 'cwd: %s\n' "$dir"; printf 'env: %s\n' "${envs[*]-}"; printf 'cmd: %s\n' "$*"; [ "$in" != /dev/null ] && { printf 'stdin: '; cat "$in"; echo; }; } > "$C/$name.cmd"
}
mkstdin() { # file json
  printf '%s' "$2" > "$1"
}
battery() { # <capture-name> <source-pg-dir> [extra-note]
  local cpn="$1" src="$2"
  local C="$CAP/$cpn" W="$WORK/$cpn"
  rm -rf "$W"; mkdir -p "$C" "$W"
  cp -a "$src" "$W/sess"; cp -a "$src" "$W/gweb"; cp -a "$src" "$W/sync"
  local Q="$W/sess" WEB="$W/sess/apps/web" VWQ="$W/sess/.mega-sdd/vaults/web" VAQ="$W/sess/.mega-sdd/vaults/api"
  local TR="$W/transcript.jsonl"
  printf '%s\n' '{"type":"user","message":{"role":"user","content":"lanjutkan U-002 (login client, apps/web)"}}' \
                '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Oke, saya jalankan execute-bolts untuk U-002."}]}}' > "$TR"
  log "battery $cpn"
  # 00 context
  cap 00-git-context "$Q" - -- bash -c 'git log --format="%H %an %s" -12; echo "--- status"; git status --porcelain=v1 --branch; echo "--- remotes"; git remote -v'
  cap 01-stamps "$Q" - -- python3 "$H/stamps_view.py" "$Q"
  cap 02-anchors-A-vs-now "$Q" - -- python3 "$H/anchors_view.py" "$Q" "$WORK/pgA"
  # 10 SessionStart — both bodies, 4 sources, gateway unset/set, cwd = apps/web (FE session)
  local src_ gw
  for src_ in startup resume compact clear; do
    mkstdin "$W/ss-$src_.json" "{\"session_id\":\"fe-session-0001\",\"transcript_path\":\"$TR\",\"cwd\":\"$WEB\",\"hook_event_name\":\"SessionStart\",\"source\":\"$src_\"}"
    cap "10-sessionstart-$src_-gwunset-body0-session-start" "$WEB" "$W/ss-$src_.json" CLAUDE_PLUGIN_ROOT="$P" -- /bin/sh -c "$SS_CMD0"
    cap "10-sessionstart-$src_-gwunset-body1-session-note"  "$WEB" "$W/ss-$src_.json" CLAUDE_PLUGIN_ROOT="$P" -- /bin/sh -c "$SS_CMD1"
    cap "10-sessionstart-$src_-gwset-body0-session-start"   "$WEB" "$W/ss-$src_.json" CLAUDE_PLUGIN_ROOT="$P" ANTHROPIC_BASE_URL="$GW_URL" -- /bin/sh -c "$SS_CMD0"
    cap "10-sessionstart-$src_-gwset-body1-session-note"    "$WEB" "$W/ss-$src_.json" CLAUDE_PLUGIN_ROOT="$P" ANTHROPIC_BASE_URL="$GW_URL" -- /bin/sh -c "$SS_CMD1"
  done
  # 20 UserPromptSubmit
  mkstdin "$W/ups.json" "{\"session_id\":\"fe-session-0001\",\"transcript_path\":\"$TR\",\"cwd\":\"$WEB\",\"permission_mode\":\"default\",\"hook_event_name\":\"UserPromptSubmit\",\"prompt\":\"tim BE udah merge, lanjutkan U-002 di apps/web\"}"
  cap 20-userpromptsubmit "$WEB" "$W/ups.json" CLAUDE_PLUGIN_ROOT="$P" -- /bin/sh -c "$UPS_CMD"
  # 30 front door GROUND (--cwd=<root>) + state view; 31 session-start AFTER ground
  cap 30-ground-cwd-root "$Q" - -- bash "$S/ground.sh" --cwd="$Q"
  cap 30b-state-view-after-ground "$Q" - -- python3 "$H/state_view.py" "$Q/.mega-sdd/state.json"
  cap 30c-stamps-after-ground "$Q" - -- python3 "$H/stamps_view.py" "$Q"
  cap 31-sessionstart-startup-after-ground "$WEB" "$W/ss-startup.json" CLAUDE_PLUGIN_ROOT="$P" -- /bin/sh -c "$SS_CMD0"
  # 32 ground --cwd=apps/web on its own copy (what the model runs if it passes the session cwd as <root>)
  cap 32-ground-cwd-appsweb "$W/gweb/apps/web" - -- bash "$S/ground.sh" --cwd="$W/gweb/apps/web"
  cap 32b-state-view-after-ground-appsweb "$W/gweb" - -- python3 "$H/state_view.py" "$W/gweb/.mega-sdd/state.json"
  # 40 PreToolUse: Skill mega-sdd:execute-bolts (the FE session resumes U-002)
  mkstdin "$W/ptu-skill.json" "{\"session_id\":\"fe-session-0001\",\"transcript_path\":\"$TR\",\"cwd\":\"$WEB\",\"permission_mode\":\"default\",\"hook_event_name\":\"PreToolUse\",\"tool_name\":\"Skill\",\"tool_input\":{\"skill\":\"mega-sdd:execute-bolts\",\"args\":\"--units=U-002\"},\"tool_use_id\":\"toolu_x2_skill\"}"
  cap 40-pretooluse-skill-execute-bolts "$WEB" "$W/ptu-skill.json" CLAUDE_PLUGIN_ROOT="$P" -- /bin/sh -c "$PTU_CMD"
  cap 40b-gate-view-after-skill "$Q" - -- python3 "$H/gate_view.py" "$Q"
  # 41 execute-bolts pre-flight 3.7 — anchor freshness (FE units)
  cap 41-check-anchor-freshness "$Q" - -- bash "$S/check-anchor-freshness.sh" --cwd="$Q" --units=U-001,U-002
  # 42 pre-flight 3.9 — JIT bind of the wave (U-002)
  cp "$VWQ/bolts/U-002/binding.json" "$W/U-002-binding.before.json" 2>/dev/null || true
  cap 42a-derive-unit-claims "$Q" - -- bash "$S/derive-unit-claims.sh" --cwd="$Q" --vault="$VWQ" --units=U-002
  cap 42b-write-unit-binding "$Q" - -- bash "$S/write-unit-binding.sh" --cwd="$Q" --vault="$VWQ" --unit=U-002 --claims="$VWQ/bolts/_wave-claims.json"
  cap 42c-validate-handoff-units "$Q" - -- bash "$S/validate-handoff-binding-units.sh" --cwd="$Q" --units=U-002
  cap 42d-U-002-binding-json "$Q" - -- bash -c "cat '$VWQ/bolts/U-002/binding.json'; echo; echo '--- diff vs before this JIT run'; diff '$W/U-002-binding.before.json' '$VWQ/bolts/U-002/binding.json'"
  # 43 pre-flight 4 — Hard-rule baseline; 44 step 5 — symbol index rebuild
  cap 43-run-preflight-scan "$Q" - -- bash "$S/run-preflight-scan.sh" --cwd="$Q" --units=U-002
  cap 44-build-symbol-index "$Q" - -- bash "$S/build-symbol-index.sh" --cwd="$Q"
  # 45 living-vault staleness per vault
  cap 45a-compute-unit-staleness-web "$Q" - -- bash "$S/compute-unit-staleness.sh" --vault="$VWQ" --project="$Q"
  cap 45b-compute-unit-staleness-api "$Q" - -- bash "$S/compute-unit-staleness.sh" --vault="$VAQ" --project="$Q"
  # 46 Step 4.5 — dispatch prompt for U-002 (what the implementer is handed)
  cap 46-build-dispatch-prompt "$Q" - -- bash "$S/build-dispatch-prompt.sh" --cwd="$Q" --vault="$VWQ" --unit=U-002 --plugin-root="$P"
  cp "$VWQ/bolts/U-002/dispatch-prompt.md" "$C/46b-dispatch-prompt.md" 2>/dev/null || echo "(no dispatch-prompt.md written)" > "$C/46b-dispatch-prompt.md"
  local INLINE
  INLINE="$(python3 -c 'import json,sys
try: print(json.load(open(sys.argv[1])).get("inline_core") or "")
except Exception: print("")' "$C/46-build-dispatch-prompt.stdout")"
  [ -n "$INLINE" ] || INLINE="Read .mega-sdd/vaults/web/bolts/U-002/dispatch-prompt.md first. UNIT: U-002"
  python3 - "$W/ptu-agent.json" "$TR" "$WEB" "$INLINE" <<'PY'
import json, sys
f, tr, cwd, prompt = sys.argv[1:5]
json.dump({"session_id": "fe-session-0001", "transcript_path": tr, "cwd": cwd, "permission_mode": "default",
           "hook_event_name": "PreToolUse", "tool_name": "Agent",
           "tool_input": {"subagent_type": "mega-sdd:bolt-implementer", "description": "bolt U-002", "prompt": prompt},
           "tool_use_id": "toolu_x2_agent"}, open(f, "w"))
PY
  # 47 PreToolUse: Agent mega-sdd:bolt-implementer (gated as execute-bolts, in-run)
  cap 47-pretooluse-agent-bolt-implementer "$WEB" "$W/ptu-agent.json" CLAUDE_PLUGIN_ROOT="$P" -- /bin/sh -c "$PTU_CMD"
  cap 47b-gate-view-after-agent "$Q" - -- python3 "$H/gate_view.py" "$Q"
  # 50 sync lane hop 1 + hop 3 (lite) on its own copy: GROUND -> derive-changed-paths -> rebind-units
  local YQ="$W/sync"
  cap 50a-sync-ground "$YQ" - -- bash "$S/ground.sh" --cwd="$YQ"
  cap 50b-derive-changed-paths-web "$YQ" - -- bash "$S/derive-changed-paths.sh" --cwd="$YQ" --vault="$YQ/.mega-sdd/vaults/web"
  cap 50c-sync-changed-paths-web "$YQ" - -- cat "$YQ/.mega-sdd/vaults/web/.sync-changed-paths.txt"
  cap 50d-rebind-units-web "$YQ" - -- bash "$S/rebind-units.sh" --cwd="$YQ" --vault="$YQ/.mega-sdd/vaults/web" --paths=@"$YQ/.mega-sdd/vaults/web/.sync-changed-paths.txt"
  cap 50e-derive-changed-paths-api "$YQ" - -- bash "$S/derive-changed-paths.sh" --cwd="$YQ" --vault="$YQ/.mega-sdd/vaults/api"
  cap 50f-sync-changed-paths-api "$YQ" - -- cat "$YQ/.mega-sdd/vaults/api/.sync-changed-paths.txt"
}

# ═════════════════════════════════════════════════════════════════════════════
# MAIN CHAIN (cumulative): A → B → C1 → C2 → D → E
# ═════════════════════════════════════════════════════════════════════════════
battery A "$PG"
do_B "$PG";  label B "$PG";  pin_mtimes "$PG" 202609210905; battery B "$PG"
do_C1 "$PG"; label C1 "$PG"; pin_mtimes "$PG" 202609211005; battery C1 "$PG"
do_C2 "$PG"; label C2 "$PG"; pin_mtimes "$PG" 202609211105; battery C2 "$PG"
do_D "$PG";                  pin_mtimes "$PG" 202609211205; battery D "$PG"
cp -a "$PG" "$WORK/pgD"
do_E "$PG";  label E "$PG";  pin_mtimes "$PG" 202609220905; battery E "$PG"

# ═════════════════════════════════════════════════════════════════════════════
# CONTROLS: each checkpoint ALONE on top of A (isolates what B masks in the cumulative chain)
# ═════════════════════════════════════════════════════════════════════════════
for ctl in B C1 C2 D; do
  d="$WORK/ctl-$ctl-pg"; rm -rf "$d"; cp -a "$WORK/pgA" "$d"
  "do_$ctl" "$d"; [ "$ctl" = D ] || label "ctl-$ctl" "$d"; pin_mtimes "$d" 202609230900
  battery "ctl-$ctl" "$d"
done
# GREEN-SUITE controls: B / C2 alone on A, then the sanctioned full-suite writer re-certifies B2 at the new
# HEAD — removes the scope-blind batch-suite-gate so the remaining gate effect of the commit is isolated.
for ctl in B C2; do
  d="$WORK/ctl-$ctl-green-pg"; rm -rf "$d"; cp -a "$WORK/pgA" "$d"; "do_$ctl" "$d"
  C="$CAP/ctl-$ctl-green"; mkdir -p "$C"
  cap 00-run-full-suite "$d" - -- bash "$S/run-full-suite.sh" --cwd="$d"
  pin_mtimes "$d" 202609230930
  battery "ctl-$ctl-green" "$d"
done

# ═════════════════════════════════════════════════════════════════════════════
# VARIANTS (targeted, fewer probes)
# ═════════════════════════════════════════════════════════════════════════════
vss() { # <name> <dir> [gw] — session-start body0 (+ body1 when gw) for an FE session in <dir>/apps/web
  mkstdin "$C/.ss.json" "{\"session_id\":\"fe-session-0001\",\"transcript_path\":\"/dev/null\",\"cwd\":\"$2/apps/web\",\"hook_event_name\":\"SessionStart\",\"source\":\"startup\"}"
  cap "$1-session-start" "$2/apps/web" "$C/.ss.json" CLAUDE_PLUGIN_ROOT="$P" -- /bin/sh -c "$SS_CMD0"
  if [ "${3:-}" = gw ]; then cap "$1-session-note" "$2/apps/web" "$C/.ss.json" CLAUDE_PLUGIN_ROOT="$P" ANTHROPIC_BASE_URL="$GW_URL" -- /bin/sh -c "$SS_CMD1"; fi
}
vground() { # <name> <dir>
  cap "$1-ground" "$2" - -- bash "$S/ground.sh" --cwd="$2"
  cap "$1-state-view" "$2" - -- python3 "$H/state_view.py" "$2/.mega-sdd/state.json"
}
# V-idx: index-only substrate (no codebase-map.md) — at A, at A+B, at A+C1, and A+C1 with no binding at all
C="$CAP/V-idx"; mkdir -p "$C"; log "variant V-idx"
for base in pgA ctl-B-pg ctl-C1-pg; do
  d="$WORK/V-idx-$base"; rm -rf "$d"; cp -a "$WORK/$base" "$d"; rm -f "$d/.mega-sdd/codebase/codebase-map.md"
  vss "$base-1-before-ground" "$d"; vground "$base-2" "$d"; vss "$base-3-after-ground" "$d"
done
d="$WORK/V-idx-nobind"; rm -rf "$d"; cp -a "$WORK/ctl-C1-pg" "$d"
rm -f "$d/.mega-sdd/codebase/codebase-map.md" "$d"/.mega-sdd/vaults/*/binding.md "$d"/.mega-sdd/vaults/*/binding.json "$d"/.mega-sdd/vaults/*/bolts/*/binding.json
rm -rf "$d"/.mega-sdd/vaults/*/bound
vss "nobind-1-before-ground" "$d"; vground "nobind-2" "$d"; vss "nobind-3-after-ground" "$d"
# V-872: the LITERAL 8.7.2 .gitignore (codebase/ + state.json tracked) — commit the scan artifacts at A
C="$CAP/V-872"; mkdir -p "$C"; log "variant V-872"
d="$WORK/V-872"; rm -rf "$d"; cp -a "$WORK/pgA" "$d"
python3 - "$d/.gitignore" <<'PY'
import sys; p=sys.argv[1]; s=open(p).read(); s=s.split("# --- X2 audit deviation")[0]; open(p,"w").write(s)
PY
vss "1-A-before-commit" "$d"
git -C "$d" add -A .gitignore .mega-sdd; commit_as "$d" fe "2026-09-20T10:25:00+07:00" -m "chore(sdd): track scan artifacts (8.7.2 recommended .gitignore)"
label V872 "$d"; pin_mtimes "$d" 202609201035
vss "2-after-committing-map-and-index" "$d"; vground "3" "$d"; vss "4-after-ground" "$d"
cap 5-git-status "$d" - -- git status --porcelain=v1
# V-up: behind upstream (bare origin in scratch; a teammate pushes an FE commit; fetch, no merge)
C="$CAP/V-up"; mkdir -p "$C"; log "variant V-up"
d="$WORK/V-up"; rm -rf "$d" "$WORK/origin.git" "$WORK/upstream-clone"; cp -a "$WORK/pgA" "$d"
git init -q --bare -b main "$WORK/origin.git"
git -C "$d" remote add origin "$WORK/origin.git"; git -C "$d" push -q -u origin main 2>/dev/null
git clone -q "$WORK/origin.git" "$WORK/upstream-clone"
do_C1 "$WORK/upstream-clone"; git -C "$WORK/upstream-clone" push -q origin main 2>/dev/null
label UP "$WORK/upstream-clone"
git -C "$d" fetch -q origin
cap 0-git-status-sb "$d" - -- git status -sb
vss "1" "$d" gw; vground "2" "$d"; vss "3-after-ground" "$d"
mkstdin "$C/.ptu.json" "{\"session_id\":\"fe-session-0001\",\"transcript_path\":\"/dev/null\",\"cwd\":\"$d/apps/web\",\"hook_event_name\":\"PreToolUse\",\"tool_name\":\"Skill\",\"tool_input\":{\"skill\":\"mega-sdd:execute-bolts\",\"args\":\"--units=U-002\"}}"
cap 4-pretooluse-skill "$d/apps/web" "$C/.ptu.json" CLAUDE_PLUGIN_ROOT="$P" -- /bin/sh -c "$PTU_CMD"
cap 5-check-anchor-freshness "$d" - -- bash "$S/check-anchor-freshness.sh" --cwd="$d" --units=U-001,U-002
# V-par: two teams' sessions in parallel on the ONE root .mega-sdd (state at C2+D)
C="$CAP/V-par"; mkdir -p "$C"; log "variant V-par"
d="$WORK/V-par"; rm -rf "$d"; cp -a "$WORK/pgD" "$d"
echo "// BE WIP via Claude Edit" >> "$d/apps/api/src/services/ApprovalService.php"
mkstdin "$C/.post-be.json" "{\"session_id\":\"be-session-0002\",\"transcript_path\":\"/dev/null\",\"cwd\":\"$d/apps/api\",\"hook_event_name\":\"PostToolUse\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$d/apps/api/src/services/ApprovalService.php\",\"old_string\":\"x\",\"new_string\":\"y\"},\"tool_response\":{\"success\":true}}"
cap 1-posttooluse-BE-edit "$d/apps/api" "$C/.post-be.json" CLAUDE_PLUGIN_ROOT="$P" -- /bin/sh -c "$POST_CMD"
cap 2-dirty-journal "$d" - -- cat "$d/.mega-sdd/codebase/.dirty-paths.jsonl"
vss "3-FE" "$d"
mkstdin "$C/.ups.json" "{\"session_id\":\"fe-session-0001\",\"transcript_path\":\"/dev/null\",\"cwd\":\"$d/apps/web\",\"hook_event_name\":\"UserPromptSubmit\",\"prompt\":\"udah, lanjut U-002\"}"
cap 4-FE-userpromptsubmit "$d/apps/web" "$C/.ups.json" CLAUDE_PLUGIN_ROOT="$P" -- /bin/sh -c "$UPS_CMD"
mkstdin "$C/.fe.json" "{\"session_id\":\"fe-session-0001\",\"transcript_path\":\"/dev/null\",\"cwd\":\"$d/apps/web\",\"hook_event_name\":\"PreToolUse\",\"tool_name\":\"Skill\",\"tool_input\":{\"skill\":\"mega-sdd:execute-bolts\",\"args\":\"--units=U-002\"}}"
mkstdin "$C/.be.json" "{\"session_id\":\"be-session-0002\",\"transcript_path\":\"/dev/null\",\"cwd\":\"$d/apps/api\",\"hook_event_name\":\"PreToolUse\",\"tool_name\":\"Skill\",\"tool_input\":{\"skill\":\"mega-sdd:execute-bolts\",\"args\":\"--units=U-010\"}}"
cap 5-FE-pretooluse-skill "$d/apps/web" "$C/.fe.json" CLAUDE_PLUGIN_ROOT="$P" -- /bin/sh -c "$PTU_CMD"
cap 6-BE-pretooluse-skill "$d/apps/api" "$C/.be.json" CLAUDE_PLUGIN_ROOT="$P" -- /bin/sh -c "$PTU_CMD"
cap 7-gate-view-after-both "$d" - -- python3 "$H/gate_view.py" "$d"
cap 8-FE-ground "$d" - -- bash "$S/ground.sh" --cwd="$d"
cap 9-FE-derive-changed-paths-web "$d" - -- bash "$S/derive-changed-paths.sh" --cwd="$d" --vault="$d/.mega-sdd/vaults/web"
cap 9b-web-changed-set "$d" - -- cat "$d/.mega-sdd/vaults/web/.sync-changed-paths.txt"
cap 10-journal-after-FE-sync "$d" - -- bash -c "ls -1a '$d/.mega-sdd/codebase/' | grep dirty; cat '$d/.mega-sdd/codebase/.dirty-paths.jsonl' 2>/dev/null || echo '(live journal gone — rotated by the FE sync)'"
vss "11-any-session-after-FE-sync" "$d"
cap 12-BE-derive-changed-paths-api "$d" - -- bash "$S/derive-changed-paths.sh" --cwd="$d" --vault="$d/.mega-sdd/vaults/api"
cap 12b-api-changed-set "$d" - -- cat "$d/.mega-sdd/vaults/api/.sync-changed-paths.txt"
# V-col: unit-ID collision across the two vaults (both teams numbered from U-001)
C="$CAP/V-col"; mkdir -p "$C"; log "variant V-col"
d="$WORK/V-col"; rm -rf "$d"; cp -a "$WORK/pgA" "$d"
mv "$d/.mega-sdd/vaults/api/units/U-010.md" "$d/.mega-sdd/vaults/api/units/U-001.md"
sed -i.bak 's/^id: U-010$/id: U-001/' "$d/.mega-sdd/vaults/api/units/U-001.md"; rm -f "$d/.mega-sdd/vaults/api/units/U-001.md.bak"
mv "$d/.mega-sdd/vaults/api/bolts/U-010" "$d/.mega-sdd/vaults/api/bolts/U-001"
cap 1-check-anchor-freshness-U-001 "$d" - -- bash "$S/check-anchor-freshness.sh" --cwd="$d" --units=U-001
cap 2-find_unit_file-U-001 "$d" - -- env MEGA_SDD_LIB_DIR="$S/_lib" python3 -c 'import os,sys; sys.path.insert(0,os.environ["MEGA_SDD_LIB_DIR"]); import vault_layouts as v; print(v.find_unit_file(sys.argv[1],"U-001")); print(v.find_bolt_artifact(sys.argv[1],"U-001","bolt-report.md"))' "$d"

# V-exp: the UserPromptExpansion gate reads the CACHED moat state (no recompute) — stale FAIL / stale PASS
C="$CAP/V-exp"; mkdir -p "$C"; log "variant V-exp"
EXP_CMD="$(hook_cmd UserPromptExpansion 0)"
for pair in "D:E" "A:B"; do
  from="${pair%%:*}"; step="${pair##*:}"
  d="$WORK/V-exp-$from-then-$step"; rm -rf "$d"; cp -a "$WORK/$from/sess" "$d"   # carries the gate state written at <from>
  "do_$step" "$d"; pin_mtimes "$d" 202609240900
  mkstdin "$C/.exp.json" "{\"session_id\":\"fe-session-0001\",\"transcript_path\":\"/dev/null\",\"cwd\":\"$d/apps/web\",\"hook_event_name\":\"UserPromptExpansion\",\"expansion_type\":\"slash_command\",\"command_name\":\"mega-sdd\",\"command_args\":\"\",\"prompt\":\"/mega-sdd\"}"
  cap "$from-then-$step-1-cached-moat-status" "$d" - -- python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("status"))' "$d/.mega-sdd/.validation-blockers.json"
  cap "$from-then-$step-2-userpromptexpansion" "$d/apps/web" "$C/.exp.json" CLAUDE_PLUGIN_ROOT="$P" -- /bin/sh -c "$EXP_CMD"
  mkstdin "$C/.ptu.json" "{\"session_id\":\"fe-session-0001\",\"transcript_path\":\"/dev/null\",\"cwd\":\"$d/apps/web\",\"hook_event_name\":\"PreToolUse\",\"tool_name\":\"Skill\",\"tool_input\":{\"skill\":\"mega-sdd:execute-bolts\",\"args\":\"--units=U-002\"}}"
  cap "$from-then-$step-3-pretooluse-skill-recomputed" "$d/apps/web" "$C/.ptu.json" CLAUDE_PLUGIN_ROOT="$P" -- /bin/sh -c "$PTU_CMD"
  cap "$from-then-$step-4-moat-status-after-recompute" "$d" - -- python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("status"))' "$d/.mega-sdd/.validation-blockers.json"
done

# ═════════════════════════════════════════════════════════════════════════════
# normalize + rail self-check (R untouched)
# ═════════════════════════════════════════════════════════════════════════════
python3 "$H/normalize.py" "$OUT" "$CAP"
{
  echo "R status unchanged: $([ "$(git -C "$R" status --porcelain 2>/dev/null)" = "$R_STATUS_BEFORE" ] && echo yes || echo NO)"
  echo "files under R newer than the run marker (excluding .git):"
  /usr/bin/find "$R" -path "$R/.git" -prune -o -newer "$MARK" -type f -print 2>/dev/null | head -50
} > "$CAP/_rail-check.txt"
cat "$CAP/_rail-check.txt" >&2
log "done: $OUT"
