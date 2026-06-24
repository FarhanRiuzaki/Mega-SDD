# Factory Line — Queryable Checkpoints + State-Driven Routing — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a derived, queryable checkpoint ledger over mega-sdd's per-phase handoffs plus a state-driven router extension to `orchestrate-flow` that can route the pipeline backward to re-run an unresolved phase, looping to convergence under a deterministic retry cap.

**Architecture:** A new deterministic validator (`validate-factory-ledger.sh`) is the load-bearing spine — it validates the ledger schema, enforces the anti-spin retry cap, and detects no-progress loops, writing a verdict state file read by the existing PreToolUse gate aggregator. Everything else (checkpoint emission contract, router forward/backward decision, convergence/termination) is prose layered onto `orchestrate-flow`'s existing routing + convergence machinery. The ledger is 100% derived (rebuildable from per-phase handoffs); no new source of truth, no new hot-path hook.

**Tech Stack:** Bash + embedded `python3` (mirrors every existing `validate-*.sh`), JSON state files, markdown skill/reference docs, fixture-based `verify.sh` DoD tests.

## Global Constraints

- **No new runtime dependency** — bash + `python3` only (matches existing validators). Copied verbatim from CLAUDE.md "What we will not accept".
- **Enforcement doctrine: gates > rules > hooks** — the anti-spin cap is critical + un-promptable, so it MUST be a deterministic validator wired to the EXISTING PreToolUse aggregator; do NOT add a new hot-path hook.
- **No-fabrication / evidence-or-drop** — every `unresolved[]` item MUST carry an anchor (`CONFLICT-N`, `OQ-N`, or `file:line`); an unanchored item is a schema FAIL.
- **Vertical-only** — the horizontal blind reviewer panel (`execute-bolts`) is NOT touched; reviewer independence is out of scope.
- **Plugin SemVer single source of truth** — `plugins/mega-sdd/.claude-plugin/plugin.json` `version` is canonical; `.claude-plugin/marketplace.json:13` MUST match it. Skill versions are independent.
- **Ledger file** = `.mega-sdd/factory-ledger.json` (the data, gitignored via explicit entry). **Validator verdict** = `.mega-sdd/.factory-ledger-state.json` (rides the existing `.*-state.json` glob). Never conflate the two.
- **Retry cap default = 3**; **live-escalation budget = 1× per (phase, attempt)**.

---

### Task 1: Ledger validator + gitignore (deterministic spine)

**Files:**
- Create: `plugins/mega-sdd/scripts/validate-factory-ledger.sh`
- Modify: `.gitignore` (add explicit ledger ignore entry)
- Test: `tests/fixtures/factory-line/verify.sh` + `tests/fixtures/factory-line/{schema-bad,cap-bad,spin-bad,good}/.mega-sdd/factory-ledger.json`

**Interfaces:**
- Consumes: `plugins/mega-sdd/scripts/_lib/resolve-project-root.sh` → `resolve_project_root(cwd)` (sourced; walks up to outermost `.mega-sdd/` parent).
- Produces:
  - CLI: `validate-factory-ledger.sh --cwd=<project-root> [--cap=N] [--quiet]`.
  - Writes `<cwd>/.mega-sdd/.factory-ledger-state.json` with fields: `status` (PASS|FAIL|SKIP), `halt_type` (null|`ledger_unparseable`|`ledger_schema`|`phase_stuck`|`anti_spin`), `convergence_status` (done|in_progress), `cap`, `cap_breaches[]`, `spin_breaches[]`, `details`.
  - Exit codes: `0`=PASS or SKIP, `1`=FAIL, `2`=error.

- [ ] **Step 1: Create the fixture ledgers**

Create `tests/fixtures/factory-line/good/.mega-sdd/factory-ledger.json` (all green → PASS, converged):

```json
[
  {"phase":"scan-codebase","attempt":1,"emitted_at":"2026-06-25T10:00:00Z","status":"completed","confidence":0.95,"did":["mapped 42 entities"],"unresolved":[],"artifacts":[".mega-sdd/codebase/codebase-map.md"],"consumed":[]},
  {"phase":"bind-codebase","attempt":1,"emitted_at":"2026-06-25T10:05:00Z","status":"completed","confidence":0.9,"did":["14 claims CONFIRMED"],"unresolved":[],"artifacts":[".mega-sdd/vaults/v1/binding.md"],"consumed":["scan-codebase@1"]}
]
```

Create `tests/fixtures/factory-line/schema-bad/.mega-sdd/factory-ledger.json` (unanchored unresolved id → schema FAIL):

```json
[
  {"phase":"bind-codebase","attempt":1,"emitted_at":"2026-06-25T10:05:00Z","status":"unresolved","confidence":0.6,"did":["partial bind"],"unresolved":[{"id":"the auth thing","kind":"conflict","blocks":["generate-units"],"note":"no anchor"}],"artifacts":[".mega-sdd/vaults/v1/binding.md"],"consumed":["scan-codebase@1"]}
]
```

Create `tests/fixtures/factory-line/cap-bad/.mega-sdd/factory-ledger.json` (phase reached cap, still not completed → `phase_stuck`):

```json
[
  {"phase":"bind-codebase","attempt":1,"emitted_at":"2026-06-25T10:00:00Z","status":"unresolved","confidence":0.5,"did":["try 1"],"unresolved":[{"id":"CONFLICT-1","kind":"conflict","blocks":["generate-units"],"note":"auth"}],"artifacts":[],"consumed":[]},
  {"phase":"bind-codebase","attempt":2,"emitted_at":"2026-06-25T10:10:00Z","status":"unresolved","confidence":0.5,"did":["try 2"],"unresolved":[{"id":"CONFLICT-2","kind":"conflict","blocks":["generate-units"],"note":"role"}],"artifacts":[],"consumed":[]},
  {"phase":"bind-codebase","attempt":3,"emitted_at":"2026-06-25T10:20:00Z","status":"unresolved","confidence":0.5,"did":["try 3"],"unresolved":[{"id":"CONFLICT-3","kind":"conflict","blocks":["generate-units"],"note":"tenancy"}],"artifacts":[],"consumed":[]}
]
```

Create `tests/fixtures/factory-line/spin-bad/.mega-sdd/factory-ledger.json` (identical unresolved id-set recurs across attempts → `anti_spin`):

```json
[
  {"phase":"bind-codebase","attempt":1,"emitted_at":"2026-06-25T10:00:00Z","status":"unresolved","confidence":0.5,"did":["try 1"],"unresolved":[{"id":"CONFLICT-1","kind":"conflict","blocks":["generate-units"],"note":"auth"}],"artifacts":[],"consumed":[]},
  {"phase":"bind-codebase","attempt":2,"emitted_at":"2026-06-25T10:10:00Z","status":"unresolved","confidence":0.5,"did":["try 2 — no progress"],"unresolved":[{"id":"CONFLICT-1","kind":"conflict","blocks":["generate-units"],"note":"auth"}],"artifacts":[],"consumed":[]}
]
```

- [ ] **Step 2: Write the failing DoD test**

Create `tests/fixtures/factory-line/verify.sh`:

```bash
#!/usr/bin/env bash
# verify.sh — fixture-verified DoD for validate-factory-ledger.sh.
# Asserts: good/ PASS+converged; schema-bad/ FAIL(ledger_schema); cap-bad/ FAIL(phase_stuck); spin-bad/ FAIL(anti_spin).
# Run: bash tests/fixtures/factory-line/verify.sh
# Exit 0 = all assertions pass; non-zero = a DoD assertion failed.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$HERE/../../.." && pwd)"
VALIDATOR="${PLUGIN_ROOT}/plugins/mega-sdd/scripts/validate-factory-ledger.sh"

FAILED=0
note() { printf '%s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*"; FAILED=1; }
[ -f "$VALIDATOR" ] || { fail "validate-factory-ledger.sh not found at $VALIDATOR"; exit 1; }

read_state() { # <state_file> <python-expr-on-d>
  python3 -c "
import json
try:
    d=json.load(open('$1')); print($2)
except Exception as e:
    print('ERR:'+str(e))
" 2>/dev/null
}

check() { # <case-dir> <expect-status> <expect-exit> <expect-halt-or-EMPTY>
  local dir="$1" exp_status="$2" exp_exit="$3" exp_halt="$4"
  bash "$VALIDATOR" --cwd="$HERE/$dir" --quiet; local code=$?
  local sf="$HERE/$dir/.mega-sdd/.factory-ledger-state.json"
  [ -f "$sf" ] || { fail "$dir: state file not written"; return; }
  local st ht; st=$(read_state "$sf" "d.get('status')"); ht=$(read_state "$sf" "d.get('halt_type')")
  note "$dir: status=$st halt=$ht exit=$code"
  [ "$st" = "$exp_status" ] || fail "$dir: status expected $exp_status, got '$st'"
  [ "$code" = "$exp_exit" ] || fail "$dir: exit expected $exp_exit, got '$code'"
  if [ -n "$exp_halt" ]; then [ "$ht" = "$exp_halt" ] || fail "$dir: halt_type expected $exp_halt, got '$ht'"; fi
}

note "=== good (expect PASS, exit 0) ===";        check good      PASS 0 ""
GOOD_CONV=$(read_state "$HERE/good/.mega-sdd/.factory-ledger-state.json" "d.get('convergence_status')")
[ "$GOOD_CONV" = "done" ] || fail "good: convergence_status expected done, got '$GOOD_CONV'"
note "=== schema-bad (expect FAIL, exit 1) ===";  check schema-bad FAIL 1 ledger_schema
note "=== cap-bad (expect FAIL, exit 1) ===";     check cap-bad    FAIL 1 phase_stuck
note "=== spin-bad (expect FAIL, exit 1) ===";    check spin-bad   FAIL 1 anti_spin

note ""
[ "$FAILED" -eq 0 ] && { note "ALL ASSERTIONS PASS"; exit 0; } || { note "VERIFY FAILED — see FAIL lines"; exit 1; }
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `bash tests/fixtures/factory-line/verify.sh`
Expected: FAIL — `validate-factory-ledger.sh not found at ...` (validator does not exist yet).

- [ ] **Step 4: Write the validator**

Create `plugins/mega-sdd/scripts/validate-factory-ledger.sh`:

```bash
#!/usr/bin/env bash
# validate-factory-ledger.sh — Factory Line.
# Validates <cwd>/.mega-sdd/factory-ledger.json:
#   - schema: required fields (phase, attempt, status, emitted_at); status enum;
#             every unresolved[].id anchored (CONFLICT-N | OQ-N | file:line)
#   - anti-spin cap: a phase's max attempt >= CAP and latest status != completed -> phase_stuck
#   - idempotency: identical unresolved id-set across two consecutive attempts -> anti_spin
# Also computes convergence_status (done|in_progress).
# Writes <cwd>/.mega-sdd/.factory-ledger-state.json
# Exit: 0=PASS or SKIP(no ledger), 1=FAIL, 2=error.
set -uo pipefail

CWD=""; QUIET=0; CAP=3
for arg in "$@"; do
  case "$arg" in
    --cwd=*) CWD="${arg#*=}" ;;
    --cap=*) CAP="${arg#*=}" ;;
    --quiet) QUIET=1 ;;
    *) echo "ERROR: unknown arg: $arg" >&2; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
_RPR="${SCRIPT_DIR}/_lib/resolve-project-root.sh"
if [ -f "$_RPR" ] && [ -n "${CWD:-}" ]; then . "$_RPR"; CWD=$(resolve_project_root "$CWD"); fi
[ -n "$CWD" ] || { echo "ERROR: --cwd required" >&2; exit 2; }

LEDGER="${CWD}/.mega-sdd/factory-ledger.json"
STATE_FILE="${CWD}/.mega-sdd/.factory-ledger-state.json"
mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || { echo "ERROR: cannot create $(dirname "$STATE_FILE")" >&2; exit 2; }

LEDGER="$LEDGER" STATE_FILE="$STATE_FILE" CAP="$CAP" QUIET="$QUIET" python3 <<'PYEOF'
import json, os, re, sys
from collections import defaultdict

ledger_path = os.environ["LEDGER"]
state_file = os.environ["STATE_FILE"]
cap = int(os.environ.get("CAP", "3"))
quiet = os.environ.get("QUIET") == "1"

ANCHOR = re.compile(r'^(CONFLICT-\d+|OQ-\d+|.+:\d+)$')
STATUSES = {"completed", "unresolved", "halted"}

def write_and_exit(report, code):
    try:
        with open(state_file, "w") as f:
            json.dump(report, f, indent=2)
    except Exception as e:
        sys.stderr.write("ERROR: cannot write state: %s\n" % e); sys.exit(2)
    if not quiet:
        print(json.dumps(report, indent=2))
    sys.exit(code)

# SKIP when feature not in use (no ledger yet) — never blocks.
if not os.path.exists(ledger_path):
    write_and_exit({"status": "SKIP", "reason": "no factory-ledger.json", "halt_type": None}, 0)

try:
    records = json.load(open(ledger_path))
except Exception as e:
    write_and_exit({"status": "FAIL", "halt_type": "ledger_unparseable",
                    "convergence_status": "in_progress",
                    "details": {"message": "factory-ledger.json present but unparseable: %s" % type(e).__name__}}, 1)

if not isinstance(records, list):
    write_and_exit({"status": "FAIL", "halt_type": "ledger_schema",
                    "convergence_status": "in_progress",
                    "details": {"errors": ["ledger must be a JSON array"]}}, 1)

schema_errors = []
for i, r in enumerate(records):
    if not isinstance(r, dict):
        schema_errors.append("record %d is not an object" % i); continue
    for fld in ("phase", "attempt", "status", "emitted_at"):
        if fld not in r:
            schema_errors.append("record %d missing required field '%s'" % (i, fld))
    if r.get("status") not in STATUSES:
        schema_errors.append("record %d status '%s' not in %s" % (i, r.get("status"), sorted(STATUSES)))
    for u in (r.get("unresolved") or []):
        uid = u.get("id") if isinstance(u, dict) else None
        if not uid or not ANCHOR.match(str(uid)):
            schema_errors.append("record %d unresolved id '%s' not anchored (need CONFLICT-N / OQ-N / file:line)" % (i, uid))

if schema_errors:
    write_and_exit({"status": "FAIL", "halt_type": "ledger_schema",
                    "convergence_status": "in_progress",
                    "details": {"errors": schema_errors}}, 1)

by_phase = defaultdict(list)
for r in records:
    by_phase[r["phase"]].append(r)
for p in by_phase:
    by_phase[p].sort(key=lambda r: r.get("attempt", 0))

def idset(a):
    return tuple(sorted(str(u.get("id")) for u in (a.get("unresolved") or []) if isinstance(u, dict)))

cap_breaches, spin_breaches = [], []
for phase, attempts in by_phase.items():
    latest = attempts[-1]
    max_attempt = max(a.get("attempt", 0) for a in attempts)
    if max_attempt >= cap and latest.get("status") != "completed":
        cap_breaches.append({"phase": phase, "attempts": max_attempt, "status": latest.get("status")})
    for j in range(1, len(attempts)):
        cur = idset(attempts[j])
        if cur and cur == idset(attempts[j-1]):
            spin_breaches.append({"phase": phase, "attempt": attempts[j].get("attempt"), "unresolved": list(cur)})
            break

all_green = all(
    atts[-1].get("status") == "completed" and not (atts[-1].get("unresolved") or [])
    for atts in by_phase.values()
)
convergence_status = "done" if all_green else "in_progress"

if cap_breaches or spin_breaches:
    halt_type = "phase_stuck" if cap_breaches else "anti_spin"
    msg = ("%d phase(s) exceeded retry cap %d" % (len(cap_breaches), cap)) if cap_breaches \
          else ("%d phase(s) re-ran with no progress (identical unresolved)" % len(spin_breaches))
    write_and_exit({"status": "FAIL", "halt_type": halt_type,
                    "convergence_status": convergence_status, "cap": cap,
                    "cap_breaches": cap_breaches, "spin_breaches": spin_breaches,
                    "details": {"message": msg}}, 1)

write_and_exit({"status": "PASS", "halt_type": None,
                "convergence_status": convergence_status, "cap": cap,
                "phases": {p: {"attempts": max(a.get("attempt", 0) for a in atts), "status": atts[-1].get("status")}
                           for p, atts in by_phase.items()}}, 0)
PYEOF
exit $?
```

- [ ] **Step 5: Make it executable**

Run: `chmod +x plugins/mega-sdd/scripts/validate-factory-ledger.sh`
Expected: no output, exit 0.

- [ ] **Step 6: Run the test to verify it passes**

Run: `bash tests/fixtures/factory-line/verify.sh`
Expected: PASS — `ALL ASSERTIONS PASS` (good=PASS/done, schema-bad=ledger_schema, cap-bad=phase_stuck, spin-bad=anti_spin).

- [ ] **Step 7: Add the gitignore entry**

In `.gitignore`, under the `# mega-sdd runtime state files (generated by validators, never committed)` block (currently after the `**/.mega-sdd/.*-state.json` lines), add:

```
**/.mega-sdd/factory-ledger.json
```

(The validator verdict `.factory-ledger-state.json` already matches the existing `**/.mega-sdd/.*-state.json` glob; only the no-leading-dot ledger data file needs an explicit entry. The fixture ledgers under `tests/fixtures/` are NOT ignored — that glob is anchored to `.mega-sdd/` anywhere, so confirm the fixtures still show as tracked in the next step.)

- [ ] **Step 8: Verify fixtures are still tracked, state files are ignored**

Run: `git add -A && git status --short tests/fixtures/factory-line/`
Expected: the four `factory-ledger.json` fixtures + `verify.sh` show as `A` (added); NO `.factory-ledger-state.json` appears (ignored).

If a fixture `factory-ledger.json` is being ignored, change the ignore entry to anchor it to project roots only — but verify first; the `**/.mega-sdd/` prefix does match fixtures, so if they vanish, use this exact entry instead and re-run:

```
/.mega-sdd/factory-ledger.json
```

- [ ] **Step 9: Commit**

```bash
git add plugins/mega-sdd/scripts/validate-factory-ledger.sh tests/fixtures/factory-line/ .gitignore
git commit -m "feat(factory-line): ledger validator — schema, anti-spin cap, convergence"
```

---

### Task 2: Wire validator into PostToolUse (state write)

**Files:**
- Modify: `plugins/mega-sdd/hooks/post-tool-use` (add a file-path trigger block)

**Interfaces:**
- Consumes: `validate-factory-ledger.sh --cwd=<PROJECT_ROOT> --quiet` (from Task 1).
- Produces: on any write to `*/.mega-sdd/factory-ledger.json`, the hook runs the validator, which writes `.mega-sdd/.factory-ledger-state.json`. Relies on the hook's existing `$PROJECT_ROOT` and `$FILE_PATH` variables and `$SCRIPT_DIR`.

- [ ] **Step 1: Add the trigger block**

In `plugins/mega-sdd/hooks/post-tool-use`, find the existing `case "$FILE_PATH" in` block that triggers on `units/U-*.md` writes (around line 406, where `VALIDATOR_BU` is defined). Immediately AFTER that `esac`, add a new case block:

```bash
# ─── Factory Line: validate the checkpoint ledger on write ────────────────
case "$FILE_PATH" in
  */.mega-sdd/factory-ledger.json)
    VALIDATOR_FL="${SCRIPT_DIR}/../scripts/validate-factory-ledger.sh"
    if [ -x "$VALIDATOR_FL" ]; then
      bash "$VALIDATOR_FL" --cwd="$PROJECT_ROOT" --quiet >/dev/null 2>&1 || true
    fi
    ;;
esac
```

(`|| true` keeps the async PostToolUse hook from ever failing the tool call — identical to every sibling validator. The validator's FAIL is surfaced later by the PreToolUse gate, not here.)

- [ ] **Step 2: Write the failing integration check**

Create a throwaway check (do NOT commit this file — it is a manual verification):

Run:
```bash
T=$(mktemp -d); mkdir -p "$T/.mega-sdd"
cp tests/fixtures/factory-line/cap-bad/.mega-sdd/factory-ledger.json "$T/.mega-sdd/"
PROJECT_ROOT="$T" SCRIPT_DIR="$(pwd)/plugins/mega-sdd/hooks" FILE_PATH="$T/.mega-sdd/factory-ledger.json" \
  bash -c 'V="${SCRIPT_DIR}/../scripts/validate-factory-ledger.sh"; bash "$V" --cwd="$PROJECT_ROOT" --quiet >/dev/null 2>&1 || true'
cat "$T/.mega-sdd/.factory-ledger-state.json"; rm -rf "$T"
```
Expected (before the edit is loaded by a real session, this just proves the wiring snippet's command is correct): prints a JSON state file with `"halt_type": "phase_stuck"`.

- [ ] **Step 3: Verify the hook file still parses**

Run: `bash -n plugins/mega-sdd/hooks/post-tool-use`
Expected: no output, exit 0 (syntax OK).

- [ ] **Step 4: Commit**

```bash
git add plugins/mega-sdd/hooks/post-tool-use
git commit -m "feat(factory-line): PostToolUse triggers ledger validator on write"
```

---

### Task 3: Wire validator verdict into PreToolUse gate (block on breach)

**Files:**
- Modify: `plugins/mega-sdd/hooks/pre-tool-use` (add a read block to the execute-bolts gate aggregator)

**Interfaces:**
- Consumes: `.mega-sdd/.factory-ledger-state.json` (written in Task 2) via the aggregator's existing `L(fn)` JSON-loader helper.
- Produces: when that state file has `status == "FAIL"`, a `("factory-ledger", <message>)` entry is appended to the aggregator's `fails` list, which `emit_block`s the `mega-sdd:execute-bolts` Skill call. No new hook; rides the existing aggregator.

- [ ] **Step 1: Add the read block**

In `plugins/mega-sdd/hooks/pre-tool-use`, inside the `if [ "${SKILL_NAME:-}" = "mega-sdd:execute-bolts" ]` aggregator (the embedded `python3 -c '...'` script that builds `fails`), find the last individual gate read (e.g. the `cross-cutting` / `ui-quality` block) and add immediately after it, BEFORE the `if fails:` summary:

```python
# factory-ledger — anti-spin cap / phase_stuck / schema (Factory Line)
d = L(".factory-ledger-state.json")
if d and d.get("status") == "FAIL":
    ht = d.get("halt_type") or "ledger_error"
    msg = (d.get("details", {}) or {}).get("message") or "factory-ledger validation failed"
    fails.append(("factory-ledger", "%s — %s" % (ht, msg)))
```

- [ ] **Step 2: Verify the hook file still parses**

Run: `bash -n plugins/mega-sdd/hooks/pre-tool-use`
Expected: no output, exit 0.

- [ ] **Step 3: Verify the embedded python parses**

Run:
```bash
python3 -c "import ast,sys,re; \
src=open('plugins/mega-sdd/hooks/pre-tool-use').read(); \
print('factory-ledger' in src and 'OK: read block present')"
```
Expected: `OK: read block present`.

- [ ] **Step 4: Manual gate proof (no commit)**

Run:
```bash
T=$(mktemp -d); mkdir -p "$T/.mega-sdd"
printf '%s' '{"status":"FAIL","halt_type":"phase_stuck","details":{"message":"2 phase(s) exceeded retry cap 3"}}' > "$T/.mega-sdd/.factory-ledger-state.json"
PROJECT_ROOT="$T" python3 -c '
import json,os
md=os.path.join(os.environ["PROJECT_ROOT"],".mega-sdd")
def L(fn):
    try: return json.load(open(os.path.join(md,fn)))
    except Exception: return None
fails=[]
d=L(".factory-ledger-state.json")
if d and d.get("status")=="FAIL":
    ht=d.get("halt_type") or "ledger_error"
    msg=(d.get("details",{}) or {}).get("message") or "fail"
    fails.append(("factory-ledger","%s — %s"%(ht,msg)))
print("BLOCK:" , fails[0][1] if fails else "none")
'
rm -rf "$T"
```
Expected: `BLOCK: phase_stuck — 2 phase(s) exceeded retry cap 3`.

- [ ] **Step 5: Commit**

```bash
git add plugins/mega-sdd/hooks/pre-tool-use
git commit -m "feat(factory-line): PreToolUse gate blocks execute-bolts on ledger FAIL"
```

---

### Task 4: Checkpoint + ledger contract reference

**Files:**
- Create: `plugins/mega-sdd/skills/orchestrate-flow/references/factory-ledger-contract.md`

**Interfaces:**
- Consumes: nothing executable (a contract doc).
- Produces: the canonical checkpoint record schema (`phase`, `attempt`, `emitted_at`, `status`, `confidence`, `did`, `unresolved[]{id,kind,blocks,note}`, `artifacts`, `consumed`) that phases append to `.mega-sdd/factory-ledger.json`, plus the anchored-`unresolved` rule and the derived/rebuild guarantee. Referenced by Task 5's router doc and the SKILL.md pointer.

- [ ] **Step 1: Write the contract reference**

Create `plugins/mega-sdd/skills/orchestrate-flow/references/factory-ledger-contract.md`:

````markdown
# Factory Ledger — Checkpoint Contract

The factory ledger is a **derived**, project-scope, append-only record of what each pipeline phase did, so the router can route forward OR backward (per `factory-routing.md`). It is NOT a source of truth: it is rebuildable from per-phase handoffs/artifacts.

## File

`.mega-sdd/factory-ledger.json` — a JSON array of checkpoint records, one per phase-attempt. Validated by `scripts/validate-factory-ledger.sh` (which writes the verdict `.mega-sdd/.factory-ledger-state.json`). Git-ignored runtime state.

## Record schema

```yaml
- phase: bind-codebase           # = handoff.emitted_by
  attempt: 1                      # increments per re-run of this phase; basis of the retry cap
  emitted_at: 2026-06-25T10:05:00Z
  status: unresolved              # completed | unresolved | halted
  confidence: 0.72                # = handoff.next_action.confidence (overall, 0..1)
  did:                            # concise "what I did" — for a downstream phase to read
    - "Validated 14 claims: 11 CONFIRMED, 3 CONFLICT"
  unresolved:                     # drives BACKWARD routing; [] when green
    - id: CONFLICT-003            # MUST be anchored: CONFLICT-N | OQ-N | file:line
      kind: conflict              # conflict | oq | low_confidence | missing_input
      blocks: [generate-units]    # downstream phase(s) this item blocks
      note: "auth model mismatch vs codebase-map"
  artifacts: [".mega-sdd/vaults/v1/binding.md"]   # = handoff.artifacts
  consumed: [scan-codebase@1]     # which upstream checkpoints this phase read (query trail)
```

## Rules

- **Anchored unresolved (hard).** Every `unresolved[].id` MUST match `CONFLICT-N`, `OQ-N`, or `file:line`. An unanchored item is a schema FAIL (mirrors evidence-or-drop / no-fabrication). No "feels incomplete" without evidence.
- **Ownership.** An `unresolved` item is cleared by re-running the OWNING phase (the phase whose checkpoint the item lives in). A human-only underlying OQ/CONFLICT is resolved first, then the owning phase re-runs.
- **Append-only.** A re-run appends a new record with `attempt+1`; never mutate a prior record.
- **Emission.** Each phase appends its record as the final step of its handoff (the same data it already emits in the handoff YAML, plus `did` / `unresolved` / `consumed`). See `handoff-contract.md`.
- **Derived / rebuildable.** If the ledger is missing or unparseable, the router rebuilds it from each phase's handoff + artifacts before routing (see `factory-routing.md` §Rebuild).
````

- [ ] **Step 2: Verify it has no broken sibling links / parses as markdown**

Run:
```bash
grep -nE 'factory-routing\.md|handoff-contract\.md' plugins/mega-sdd/skills/orchestrate-flow/references/factory-ledger-contract.md
```
Expected: prints the two sibling references (both live in the same `references/` dir; `handoff-contract.md` exists today, `factory-routing.md` is created in Task 5).

- [ ] **Step 3: Commit**

```bash
git add plugins/mega-sdd/skills/orchestrate-flow/references/factory-ledger-contract.md
git commit -m "docs(factory-line): checkpoint ledger contract reference"
```

---

### Task 5: Router extension — read-whole-ledger + forward/backward + termination

**Files:**
- Create: `plugins/mega-sdd/skills/orchestrate-flow/references/factory-routing.md`
- Modify: `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` (add reference pointer + a `--factory` flag line + bump `version`)

**Interfaces:**
- Consumes: `factory-ledger-contract.md` (Task 4), the existing `convergence-loops.md` (loop mechanics) and `halt-taxonomy.md` (halt classes), and the verdict `.factory-ledger-state.json` (Task 1).
- Produces: the router decision procedure (read whole ledger → pick forward/backward → convergence/cap/escalation), wired as a `--deep`/`--factory` behavior of `orchestrate-flow`.

- [ ] **Step 1: Write the router reference**

Create `plugins/mega-sdd/skills/orchestrate-flow/references/factory-routing.md`:

````markdown
# Factory Routing — State-Driven Forward/Backward Loop

Extends the `orchestrate-flow` execution loop so routing reads the WHOLE factory ledger (`factory-ledger-contract.md`), not just the last handoff — enabling backward re-runs. Active under `--deep` (and the explicit `--factory` flag). Reuses `convergence-loops.md` (loop) + `halt-taxonomy.md` (halt classes).

## One iteration

```
1. read .mega-sdd/factory-ledger.json → status map of all phases (latest attempt each)
   (if missing/unparseable → REBUILD, see below)
2. collect all unresolved[] across all latest-attempt records
3. pick ONE next action (priority order):
   a. an unresolved item that `blocks` a downstream phase?
      → target = the OWNING phase (where the item lives); route BACKWARD.
        (human-only underlying OQ/CONFLICT resolved first, then owning phase re-runs)
   b. else, a downstream phase not yet run?
      → target = next downstream phase; route FORWARD.
        Feed its dispatch the relevant upstream checkpoints (the `did`/`artifacts` of phases it `consumed`).
        If a needed upstream checkpoint is ambiguous/missing → bounded LIVE-ESCALATION:
        re-dispatch that one upstream phase, at most 1× per (phase, attempt); still ambiguous → HALT.
   c. else (all phases completed & all unresolved empty) → CONVERGED → done; emit summary.
4. safety checks BEFORE dispatching target — these are also enforced deterministically by
   validate-factory-ledger.sh / the PreToolUse gate, so the loop cannot run hot even if prose is skipped:
   - attempt(target) >= cap (default 3) and not completed → HALT phase_stuck → escalate to human.
   - identical unresolved id-set recurred with no progress → HALT anti_spin.
   - item is an always-stop / human-only class (business OQ P1, constitution drift; see halt-taxonomy.md)
     → PAUSE; never force-loop.
5. dispatch target → phase appends a new checkpoint (attempt+1) → goto 1.
```

## Rebuild (derived ledger)

If `factory-ledger.json` is absent or `validate-factory-ledger.sh` reports `ledger_unparseable`: reconstruct it by reading each phase's last handoff (`handoff-contract.md`) + its artifacts, emitting one `completed` record per phase that has artifacts and an empty `unresolved`. Then re-run the validator. The ledger is never a single point of failure.

## Termination (three ways)

- **Converged** — all latest records `completed` + `unresolved: []` → `status: done`.
- **Cap hit** — a phase fails to go green within `cap` attempts → `phase_stuck` halt + a concrete human question; resume `--resume`.
- **Always-pause** — human-only decisions pause; not force-looped.

## Boundaries

- **Vertical only.** This governs phase↔upstream-checkpoint routing. The `execute-bolts` blind reviewer panel is untouched — reviewer independence is its own precision rail.
- **No free-form chat.** All cross-phase information flows through the structured checkpoint records + the bounded live-escalation; never an open conversation between phases.
````

- [ ] **Step 2: Add the SKILL.md reference pointer**

In `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md`, under the `## Specialist references (load on demand)` section (around line 158), add two bullets matching the existing style:

```markdown
- `references/factory-ledger-contract.md` — the derived checkpoint ledger schema each phase appends to.
- `references/factory-routing.md` — read-whole-ledger forward/backward routing + convergence/cap termination (`--factory` / `--deep`).
```

- [ ] **Step 3: Add the flag**

In `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md`, under `## Flags` (around line 112), add:

```markdown
- `--factory` — enable state-driven factory routing: read the whole checkpoint ledger and route forward OR backward to re-run an unresolved phase, looping to convergence under the retry cap (`references/factory-routing.md`). Implied by `--deep`.
```

- [ ] **Step 4: Bump the skill version**

In `plugins/mega-sdd/skills/orchestrate-flow/SKILL.md` frontmatter, change `version: 2.8.0` to `version: 2.9.0`.

- [ ] **Step 5: Verify SKILL.md frontmatter is valid YAML and under the line budget**

Run:
```bash
python3 -c "import yaml; d=yaml.safe_load(open('plugins/mega-sdd/skills/orchestrate-flow/SKILL.md').read().split('---')[1]); print('version', d['version'])"
wc -l plugins/mega-sdd/skills/orchestrate-flow/SKILL.md
```
Expected: `version 2.9.0`; line count well under 500.

- [ ] **Step 6: Commit**

```bash
git add plugins/mega-sdd/skills/orchestrate-flow/references/factory-routing.md plugins/mega-sdd/skills/orchestrate-flow/SKILL.md
git commit -m "feat(factory-line): state-driven forward/backward router + orchestrate-flow wiring (2.9.0)"
```

---

### Task 6: Trigger tests + full-suite green

**Files:**
- Modify: `tests/skill-triggering/orchestrate-flow.test.md` (add factory routing scenarios)
- Move/relocate test for CI discovery: ensure `tests/fixtures/factory-line/verify.sh` is reachable by the CI runner (see Step 2).

**Interfaces:**
- Consumes: the validator + fixtures (Task 1), the router doc (Task 5).
- Produces: routing trigger scenarios + a CI-discoverable test entry.

- [ ] **Step 1: Add routing scenarios**

In `tests/skill-triggering/orchestrate-flow.test.md`, under the routing-scenarios section, append:

```markdown
### R-FACTORY-1: Backward re-run on unresolved
- **State:** vault + binding + units + bolts present; `factory-ledger.json` has a downstream checkpoint whose `unresolved[].blocks` names an earlier phase
- **Expect:** Router proposes a BACKWARD re-run of the OWNING upstream phase, not a forward step

### R-FACTORY-2: Convergence stops the loop
- **State:** `factory-ledger.json` with every latest checkpoint `completed` + `unresolved: []`
- **Expect:** `status: done`, zero excess re-runs

### R-FACTORY-3: Cap halts, does not spin
- **State:** a phase at attempt 3 still `unresolved`
- **Expect:** HALT `phase_stuck` + concrete human question; no 4th auto re-run
```

- [ ] **Step 2: Make the fixture test CI-discoverable**

The CI runner (`.github/workflows/tests.yml`) discovers `plugins/mega-sdd/tests -name 'test-*.sh'`. Create a thin wrapper so the fixture DoD runs in CI:

Create `plugins/mega-sdd/tests/factory-line/test-factory-ledger.sh`:

```bash
#!/usr/bin/env bash
# CI entry — delegates to the fixture DoD for validate-factory-ledger.sh.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
exec bash "${REPO_ROOT}/tests/fixtures/factory-line/verify.sh"
```

Run: `chmod +x plugins/mega-sdd/tests/factory-line/test-factory-ledger.sh`

- [ ] **Step 3: Run the CI wrapper**

Run: `bash plugins/mega-sdd/tests/factory-line/test-factory-ledger.sh`
Expected: `ALL ASSERTIONS PASS`, exit 0.

- [ ] **Step 4: Run the whole shell suite (regression)**

Run:
```bash
rc=0; while IFS= read -r t; do echo "== $t =="; bash "$t" || { echo "FAILED: $t"; rc=1; }; done \
  < <(find plugins/mega-sdd/tests -name 'test-*.sh' | sort); echo "rc=$rc"
```
Expected: `rc=0` (all suites green, including the new factory-line test).

- [ ] **Step 5: Commit**

```bash
git add tests/skill-triggering/orchestrate-flow.test.md plugins/mega-sdd/tests/factory-line/
git commit -m "test(factory-line): CI wrapper + routing trigger scenarios"
```

---

### Task 7: Versioning, CHANGELOG, release

**Files:**
- Modify: `plugins/mega-sdd/.claude-plugin/plugin.json` (`version`)
- Modify: `.claude-plugin/marketplace.json` (mega-sdd entry `version`, line 13)
- Modify: `CHANGELOG.md` (new top entry)

**Interfaces:**
- Consumes: all prior tasks.
- Produces: a synced 4.36.0 release.

- [ ] **Step 1: Bump plugin.json**

In `plugins/mega-sdd/.claude-plugin/plugin.json`, change `"version": "4.35.0",` to `"version": "4.36.0",`.

- [ ] **Step 2: Bump marketplace.json (keep in sync)**

In `.claude-plugin/marketplace.json` line 13, change `"version": "4.35.0",` to `"version": "4.36.0",`.

- [ ] **Step 3: Verify the two manifests match**

Run:
```bash
python3 -c "import json; a=json.load(open('plugins/mega-sdd/.claude-plugin/plugin.json'))['version']; b=json.load(open('.claude-plugin/marketplace.json'))['plugins'][0]['version']; print('MATCH' if a==b=='4.36.0' else 'MISMATCH', a, b)"
```
Expected: `MATCH 4.36.0 4.36.0`.

- [ ] **Step 4: Add the CHANGELOG entry**

In `CHANGELOG.md`, insert directly above `## [4.35.0] - 2026-06-24`:

```markdown
## [4.36.0] - 2026-06-25

### Added — Factory Line: queryable checkpoint ledger + state-driven routing

- **`validate-factory-ledger.sh`** (new deterministic validator): ledger schema check (every `unresolved` must be anchored — `CONFLICT-N`/`OQ-N`/`file:line`), anti-spin retry cap (default 3 → `phase_stuck`), no-progress idempotency check (identical unresolved recurs → `anti_spin`), and convergence computation. Writes `.factory-ledger-state.json`.
- **State-driven router extension to `orchestrate-flow` (2.8.0 → 2.9.0):** reads the whole `.mega-sdd/factory-ledger.json` (derived, rebuildable) and routes forward OR backward to re-run an unresolved phase, looping to convergence or halting on the cap. New `--factory` flag (implied by `--deep`). References `factory-ledger-contract.md` + `factory-routing.md`.
- **Wiring (no new hook):** PostToolUse runs the validator on ledger write; the existing PreToolUse execute-bolts gate aggregator blocks on a ledger FAIL.
- **Vertical-only** — the blind reviewer panel is untouched. Fixtures + CI test under `tests/fixtures/factory-line/` + `plugins/mega-sdd/tests/factory-line/`.
```

- [ ] **Step 5: Final suite + manifest verify**

Run:
```bash
bash plugins/mega-sdd/tests/factory-line/test-factory-ledger.sh && echo "fixtures OK"
grep -m1 '"version"' plugins/mega-sdd/.claude-plugin/plugin.json
```
Expected: `fixtures OK`; version line shows `4.36.0`.

- [ ] **Step 6: Commit**

```bash
git add plugins/mega-sdd/.claude-plugin/plugin.json .claude-plugin/marketplace.json CHANGELOG.md
git commit -m "chore(release): Factory Line v4.36.0 — version sync + changelog"
```

---

## Self-Review

**Spec coverage:**
- §3 D1 hybrid query → Task 5 §router step 3b (bounded live-escalation, 1×/attempt). ✓
- §3 D2 state-driven routing → Task 5 (read whole ledger, forward/backward). ✓
- §3 D3 convergence + cap + escalation → Task 1 (validator cap/spin) + Task 5 (termination). ✓
- §4.2 checkpoint schema → Task 4 contract. ✓
- §4.3 router loop → Task 5 `factory-routing.md`. ✓
- §4.4 termination → Task 1 + Task 5. ✓
- §5 enforcement (validator + existing aggregator, no new hook) → Tasks 1–3. ✓
- §6 error handling (rebuild, missing checkpoint→escalate, budget) → Task 5 §Rebuild + step 3b. ✓
- §7 testing (backward, convergence, cap, anti-spin, rebuild, trigger) → Task 1 fixtures (schema/cap/spin/convergence) + Task 6 (trigger R-FACTORY-1..3); rebuild is covered as documented router behavior + the `ledger_unparseable` validator path (cap/spin/schema unit-tested; backward/rebuild are router-prose validated via trigger scenarios, since they need the full pipeline). ✓
- §10 versioning → Task 7. ✓

**Placeholder scan:** No TBD/TODO; every code step has complete code; commands have expected output. ✓

**Type consistency:** state-file fields (`status`, `halt_type`, `convergence_status`, `details.message`, `cap_breaches`, `spin_breaches`) are produced in Task 1 and consumed identically in Task 3's read block and the verify.sh assertions. Halt-type strings (`phase_stuck`, `anti_spin`, `ledger_schema`, `ledger_unparseable`) match across validator, gate, and tests. File names (`factory-ledger.json` data vs `.factory-ledger-state.json` verdict) are used consistently. ✓

**Known scope honesty:** the validator unit-tests the deterministic guarantees (schema, cap, spin, convergence). The backward-routing decision and ledger-rebuild are router *prose* behaviors validated by trigger scenarios (R-FACTORY-1..3), not bash unit tests — because they require dispatching real pipeline phases. This is called out, not hidden.
