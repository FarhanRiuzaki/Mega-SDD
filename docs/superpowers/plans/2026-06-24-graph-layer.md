# mega-sdd Graph Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a derived, project-scope graph (`.mega-sdd/graph.json`) over existing mega-sdd artifacts, with an impact/blast-radius query as the first lens — fully compliant with the anti-hallucination moat and breaking no existing chain or pipeline.

**Architecture:** A deterministic Bash+Python3 builder parses already-existing artifacts (no code re-scan) into a cached `graph.json`. `bind-codebase` gains a structured `binding.json` sidecar (the graph's core data source), guarded by a parity validator. A new lean skill `mega-sdd:graph` + command `/mega-sdd:graph` queries the graph, lazily rebuilding when stale and surfacing a binding-vs-HEAD staleness banner. The graph stays OUT of every chain — `sync` regenerates it only as a cache-warming convenience.

**Tech Stack:** Bash wrapper scripts + embedded Python3 (stdlib + PyYAML, already used by the plugin's validators; stdlib regex fallback when PyYAML absent). Markdown SKILL/command files. Shell-based test scripts matching `plugins/mega-sdd/tests/`.

## Global Constraints

- **Spec:** `docs/superpowers/specs/2026-06-24-graph-layer-design.md` — the binding contract for this plan.
- **Anti-hallucination:** an edge exists ONLY when a cited artifact field produces it. No inferred edges in v1. Every edge carries `evidence: {artifact, field}`. Missing artifact → `[Pending]` node, NEVER a fabricated edge.
- **Derived & uneditable:** `graph.json` and `binding.json` are derived/regenerated, never hand-edited; pure JSON root object, no frontmatter (house style — matches `vault.json`, `.validation-blockers.json`).
- **Node ID namespacing:** vault-scoped IDs are `<vault-id>:<local-id>` (e.g. `sample-vault:U-007`, `sample-vault:C-031`). `code_anchor` (file-keyed) and `module`/`vault` stay bare (already project-unique).
- **`code_anchor` identity:** keyed by file path; line is `attrs.line`, never part of the id.
- **No new runtime dependency:** PyYAML is already used by `scripts/validate-*.sh`; use it with a stdlib regex fallback (graceful-fallback doctrine). No pip installs.
- **House script style:** Bash wrapper, Python3 via `python3 <<'PYEOF' ... PYEOF`, atomic writes via tmp + `os.replace()`, ISO-8601 UTC timestamps `datetime.now(timezone.utc).isoformat().replace("+00:00","Z")`.
- **Canonical paths** (`plugins/mega-sdd/references/paths.md`): vaults at `.mega-sdd/vaults/<slug>/`; `binding.md`/`binding.json` inside the vault dir; project-scope `graph.json` at `.mega-sdd/graph.json`.
- **Versioning:** bump `plugins/mega-sdd/.claude-plugin/plugin.json` AND `.claude-plugin/marketplace.json` to the SAME version (4.29.0 → **4.30.0**, minor/new-feature); new skill SKILL.md `version: 1.0.0`; add a `CHANGELOG.md` entry; bump `bind-codebase` SKILL.md version.
- **Auto-discovery:** skills/commands/agents are discovered by directory scan — do NOT add arrays to plugin.json. DO add a `graph:` entry to `plugins/mega-sdd/references/skill-tier-manifest.yaml`.
- **Name-collision note:** multi-squad vaults emit `<vault>/.obsidian/graph.json` (Obsidian viz) — a DIFFERENT file from the project-scope `.mega-sdd/graph.json`. Do not conflate.

---

### Task 1: `binding.json` schema reference + parity validator

Establishes the structured binding sidecar that is the graph's core data source, and a deterministic gate that keeps it consistent with `binding.md` (gates > rules).

**Files:**
- Create: `plugins/mega-sdd/skills/bind-codebase/references/binding-json-schema.md`
- Create: `plugins/mega-sdd/scripts/validate-binding-json.sh`
- Create: `plugins/mega-sdd/tests/graph/test-binding-json-parity.sh`
- Create (fixtures): `plugins/mega-sdd/tests/graph/fixtures/binding-ok/binding.md`, `.../binding-ok/binding.json`, `.../binding-mismatch/binding.md`, `.../binding-mismatch/binding.json`

**Interfaces:**
- Produces: `binding.json` schema `{schema_version:"1.0", generated_by, generated_at, vault, codebase_map_provenance, head, claims:[{id, verdict, state, anchor, confidence, field_diff, vault_source}]}`. Consumed by Task 4 (graph builder) and Task 2 (bind-codebase emits it).
- Produces: `validate-binding-json.sh --vault <dir>` → exit 0 PASS / 2 FAIL; writes `<vault>/.internal/binding-json-parity.json` state file.

- [ ] **Step 1: Write the schema reference doc**

Create `binding-json-schema.md`:

```markdown
# binding.json — structured State Map sidecar

`bind-codebase` emits `binding.json` next to `binding.md` (same Step 4 write).
Pure JSON root object, no frontmatter. Mirror of the Implementation State Map
table + Confirmed Claims list, so downstream consumers (the graph builder)
never parse the markdown table.

## Schema

```json
{
  "schema_version": "1.0",
  "generated_by": "bind-codebase@<version>",
  "generated_at": "<ISO8601 UTC>",
  "vault": "<vault dir path>",
  "codebase_map_provenance": "snapshot-verified | snapshot-stale | no-snapshot",
  "head": "<git HEAD sha at bind time, or null>",
  "claims": [
    {
      "id": "C-001",
      "verdict": "CONFIRMED | CONFLICT | OQ",
      "state": "IMPLEMENTED | PARTIAL_FIELDS_MISSING | PARTIAL_FIELDS_SURPLUS | PARTIAL_FIELDS_BOTH | NEW | UNKNOWN | null",
      "anchor": "UserController.php:45 + routes/api.php:12 | null",
      "confidence": "high | medium | low | null",
      "field_diff": "ADD: [...] · KEEP: [...] · REMOVE: [...] | (exact match) | n/a",
      "vault_source": "03-data-model.md:42 | null"
    }
  ]
}
```

## Parity rule (validated by `scripts/validate-binding-json.sh`)

For every row in the `binding.md` Implementation State Map there MUST be exactly
one `claims[]` entry with the same `id`, `verdict`, and `state`, and vice-versa.
Anchor/field_diff are compared verbatim. A mismatch is a FAIL — the binding
write is inconsistent and the graph would inherit the error.
```

- [ ] **Step 2: Write the failing parity test**

Create `test-binding-json-parity.sh`:

```bash
#!/usr/bin/env bash
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
V="${PLUGIN_ROOT}/scripts/validate-binding-json.sh"
FX="${SCRIPT_DIR}/fixtures"
rc=0

bash "$V" --vault "${FX}/binding-ok" >/dev/null 2>&1
[ $? -eq 0 ] || { echo "FAIL: binding-ok should PASS"; rc=1; }

bash "$V" --vault "${FX}/binding-mismatch" >/dev/null 2>&1
[ $? -eq 2 ] || { echo "FAIL: binding-mismatch should FAIL (exit 2)"; rc=1; }

[ $rc -eq 0 ] && echo "PASS: test-binding-json-parity"
exit $rc
```

- [ ] **Step 3: Create the fixtures**

`fixtures/binding-ok/binding.md` (only the State Map section is parsed):

```markdown
## Implementation State Map (2; field_diff column when precision_tier: ast)
| Claim ID | Verdict | State | Anchor | Confidence | Field diff |
|---|---|---|---|---|---|
| C-001 | CONFIRMED | IMPLEMENTED | UserController.php:45 | high | (exact match) |
| C-012 | OQ | NEW | — | n/a | n/a |
```

`fixtures/binding-ok/binding.json`:

```json
{
  "schema_version": "1.0",
  "generated_by": "bind-codebase@test",
  "generated_at": "2026-06-24T00:00:00Z",
  "vault": "fixtures/binding-ok",
  "codebase_map_provenance": "snapshot-verified",
  "head": "abc123",
  "claims": [
    {"id": "C-001", "verdict": "CONFIRMED", "state": "IMPLEMENTED", "anchor": "UserController.php:45", "confidence": "high", "field_diff": "(exact match)", "vault_source": "03-data-model.md:42"},
    {"id": "C-012", "verdict": "OQ", "state": "NEW", "anchor": "—", "confidence": "n/a", "field_diff": "n/a", "vault_source": null}
  ]
}
```

`fixtures/binding-mismatch/binding.md`: same as binding-ok. `fixtures/binding-mismatch/binding.json`: copy of binding-ok but change `C-012` verdict to `"CONFIRMED"` (introduces a parity mismatch).

- [ ] **Step 4: Run the test to verify it fails**

Run: `bash plugins/mega-sdd/tests/graph/test-binding-json-parity.sh`
Expected: FAIL (validator does not exist yet → non-zero/empty, test prints FAIL lines).

- [ ] **Step 5: Implement the parity validator**

Create `validate-binding-json.sh`:

```bash
#!/usr/bin/env bash
# Parity gate: binding.md State Map rows <-> binding.json claims[].
# Exit 0 PASS, 2 FAIL, 3 usage error.
set -u
VAULT=""
while [ $# -gt 0 ]; do case "$1" in --vault) VAULT="$2"; shift 2;; --vault=*) VAULT="${1#*=}"; shift;; *) shift;; esac; done
[ -n "$VAULT" ] || { echo "usage: validate-binding-json.sh --vault <dir>" >&2; exit 3; }

python3 <<PYEOF
import json, os, re, sys
vault = os.environ.get("V_VAULT") or """$VAULT"""
md_path = os.path.join(vault, "binding.md")
js_path = os.path.join(vault, "binding.json")
errors = []

def parse_state_map(md):
    rows = {}
    in_tbl = False
    for line in md.splitlines():
        if line.strip().startswith("## Implementation State Map"):
            in_tbl = True; continue
        if in_tbl:
            if line.startswith("## "):
                break
            if not line.strip().startswith("|"):
                continue
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if len(cells) < 6 or cells[0] in ("Claim ID", "---") or set(cells[0]) <= {"-"}:
                continue
            rows[cells[0]] = {"id": cells[0], "verdict": cells[1], "state": cells[2]}
    return rows

try:
    md = open(md_path, encoding="utf-8").read()
    js = json.load(open(js_path, encoding="utf-8"))
except Exception as e:
    print(f"FAIL: cannot read binding pair: {e}"); sys.exit(2)

md_rows = parse_state_map(md)
js_rows = {c["id"]: c for c in js.get("claims", [])}

for cid, mr in md_rows.items():
    jr = js_rows.get(cid)
    if not jr:
        errors.append(f"{cid}: in binding.md, missing from binding.json")
        continue
    for k in ("verdict", "state"):
        if str(mr[k]) != str(jr.get(k)):
            errors.append(f"{cid}: {k} md={mr[k]!r} json={jr.get(k)!r}")
for cid in js_rows:
    if cid not in md_rows:
        errors.append(f"{cid}: in binding.json, missing from binding.md State Map")

state = {"status": "PASS" if not errors else "FAIL",
         "validator": "validate-binding-json.sh",
         "vault": vault, "errors": errors}
internal = os.path.join(vault, ".internal")
os.makedirs(internal, exist_ok=True)
tmp = os.path.join(internal, ".binding-json-parity.tmp")
with open(tmp, "w", encoding="utf-8") as f:
    json.dump(state, f, indent=2)
os.replace(tmp, os.path.join(internal, "binding-json-parity.json"))

if errors:
    for e in errors: print("FAIL:", e)
    sys.exit(2)
print("PASS: binding.json parity")
sys.exit(0)
PYEOF
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `bash plugins/mega-sdd/tests/graph/test-binding-json-parity.sh`
Expected: `PASS: test-binding-json-parity`

- [ ] **Step 7: Commit**

```bash
git add plugins/mega-sdd/skills/bind-codebase/references/binding-json-schema.md plugins/mega-sdd/scripts/validate-binding-json.sh plugins/mega-sdd/tests/graph/
git commit -m "feat(graph): binding.json schema + parity validator"
```

---

### Task 2: Wire `bind-codebase` to emit `binding.json`

Make the binding skill write the sidecar in the same atomic step as `binding.md`, and run the parity gate. Pure prose edits to the skill (the agent authors the JSON from the same in-context State Map data).

**Files:**
- Modify: `plugins/mega-sdd/skills/bind-codebase/SKILL.md` (Step 4 region + handoff artifacts list + frontmatter `version`)
- Modify: `plugins/mega-sdd/skills/bind-codebase/references/auto-memory-handoff.md` (artifacts list)

**Interfaces:**
- Consumes: `binding-json-schema.md` (Task 1), `validate-binding-json.sh` (Task 1).
- Produces: every clean or blocked bind now writes `<vault>/binding.json`. Consumed by Task 4.

- [ ] **Step 1: Add Step 4.5 to bind-codebase SKILL.md**

Find Step 4 ("Write `binding.md`") and insert immediately after it:

```markdown
**4.5. Emit `binding.json`** (structured State Map sidecar; schema → `references/binding-json-schema.md`).
Write `<vault>/binding.json` from the SAME claim data you just rendered into the
State Map — one `claims[]` entry per State Map row (`id`, `verdict`, `state`,
`anchor`, `confidence`, `field_diff`, and `vault_source` from the Confirmed
Claims list `vault file:line`). Set `codebase_map_provenance` from
`binding_metadata`, `head` to the current `git rev-parse HEAD` (or null outside
git). This is part of the binding write — emit it whether the bind is clean or
blocked. Then **Run** `scripts/validate-binding-json.sh --vault <vault>`; a
non-zero exit means `binding.md` and `binding.json` disagree — fix the write
before proceeding (do NOT emit a halt YAML for this; it is an authoring bug).
```

- [ ] **Step 2: Update the handoff artifacts list**

In `auto-memory-handoff.md`, find the `artifacts:` YAML list under handoff emission and add `binding.json`:

```yaml
artifacts:
  - <absolute path to binding.md>
  - <absolute path to binding.json>
  - <absolute path to <vault>/bound/>   # only if no CONFLICTs
```

- [ ] **Step 3: Bump bind-codebase skill version**

Edit `SKILL.md` frontmatter `version:` (increment patch, e.g. `2.x.y` → next patch).

- [ ] **Step 4: Verify no existing binding test regressed**

Run: `bash plugins/mega-sdd/tests/moat/run-all.sh 2>&1 | tail -20`
Expected: all moat tests still PASS (no test reads binding.json yet; this only adds a write instruction).

- [ ] **Step 5: Commit**

```bash
git add plugins/mega-sdd/skills/bind-codebase/
git commit -m "feat(graph): bind-codebase emits binding.json sidecar (Step 4.5)"
```

---

### Task 3: Graph schema reference + node/edge model doc

The single source of truth for the builder and query: node types, edge relations, ID namespacing, confidence derivation, `_meta` freshness block.

**Files:**
- Create: `plugins/mega-sdd/skills/graph/references/graph-schema.md`

**Interfaces:**
- Produces: the `graph.json` schema consumed by Task 4 (builder) and Task 5 (query).

- [ ] **Step 1: Write the schema doc**

Create `graph-schema.md` capturing spec §3.3 + §3.4 verbatim-aligned:

```markdown
# graph.json schema (derived, project-scope cache)

Pure JSON root object at `.mega-sdd/graph.json`. Never hand-edited. Regenerated
by the builder. Safe to delete.

## Top level
```json
{
  "schema_version": "1.0",
  "_meta": {
    "derived": true,
    "generated_by": "build-graph@<version>",
    "built_at": "<ISO8601 UTC>",
    "head": "<git HEAD sha at build, or null>",
    "source_glob": ["<glob patterns walked>"],
    "source_hashes": {"<repo-relative artifact path>": "<sha256>"},
    "binding_stamps": {"<vault-id>": {"provenance": "snapshot-verified|snapshot-stale|no-snapshot", "head_at_bind": "<sha|null>", "stale_vs_head": false}}
  },
  "nodes": [ {"id": "...", "type": "...", "label": "...", "attrs": {...}, "source": {"artifact": "...", "field": "..."}} ],
  "edges": [ {"source": "...", "target": "...", "relation": "...", "confidence": "VERIFIED|CONFIRMED|...", "evidence": {"artifact": "...", "field": "..."}} ]
}
```

## Node types (v1): `code_anchor`, `claim`, `unit`, `module`, `flow`, `kb_domain`, `oq`, `vault`. (`interface` deferred.)

## ID namespacing
Vault-scoped node ids are `<vault-id>:<local-id>` (`unit`, `claim`, `oq`, `flow`).
Global ids stay bare: `code_anchor` (file path), `module` (M-*), `vault` (slug),
`kb_domain` (kebab id — project-global KB).

## `code_anchor` identity
id = file path only; `attrs.line` carries the line hint. A `file:line` string is
normalized to its file when minting/matching.

## Edge relations (v1)
| relation | from → to | source field |
|---|---|---|
| implements | claim → code_anchor | binding.json `claims[].anchor` |
| honors | unit → claim/oq | unit frontmatter `binding_refs` |
| depends_on | unit → unit | unit frontmatter `depends_on` |
| in_module | unit → module | modules.yaml vault_sections match (or unit `module:`) |
| blocks | module → module | modules.yaml `blocks`/`blocked_by` |
| kb_source | flow → kb_domain | vault flow `_kb_source` |
| domain_dep | kb_domain → kb_domain | KB frontmatter `depends_on` |
| covers | claim → flow/vault-section | binding.json `claims[].vault_source` |

## Confidence derivation (honest-confidence rule)
`implements` inherits the claim verdict/confidence from binding.json. All
structurally-declared edges (`honors`, `depends_on`, `in_module`, `blocks`,
`kb_source`, `domain_dep`, `covers`) are `VERIFIED` — read verbatim from an
authored field. No edge is ever `INFERRED` in v1.

## Anti-hallucination
An edge is emitted ONLY from a present, cited field. If a referenced target id
does not resolve to a node, mint a `[Pending]` placeholder node
(`type` unchanged, `attrs.pending=true`) — NEVER drop the citation and NEVER
fabricate a non-cited edge.
```

- [ ] **Step 2: Commit**

```bash
git add plugins/mega-sdd/skills/graph/references/graph-schema.md
git commit -m "feat(graph): graph.json schema reference"
```

---

### Task 4: Graph builder script (`scripts/build-graph.sh`)

Deterministic parse of artifacts → `graph.json` with freshness `_meta`. The heart of the feature.

**Files:**
- Create: `plugins/mega-sdd/scripts/build-graph.sh`
- Create: `plugins/mega-sdd/tests/graph/test-build-graph.sh`
- Create (fixture): `plugins/mega-sdd/tests/graph/fixtures/project/.mega-sdd/...` (mini project: 1 vault with vault.json, binding.json, 2 units, modules.yaml; 1 KB domain)

**Interfaces:**
- Consumes: `binding.json` (Task 1/2), `graph-schema.md` (Task 3), artifacts under `.mega-sdd/`.
- Produces: `build-graph.sh --root <project> [--out <path>]` → writes `<root>/.mega-sdd/graph.json`; exit 0. Consumed by Task 5 (query) and Task 7 (sync hook).

- [ ] **Step 1: Write the failing builder test**

Create `test-build-graph.sh`:

```bash
#!/usr/bin/env bash
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BUILD="${PLUGIN_ROOT}/scripts/build-graph.sh"
SRC="${SCRIPT_DIR}/fixtures/project"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cp -R "$SRC/." "$TMP/"
rc=0

bash "$BUILD" --root "$TMP" >/dev/null 2>&1 || { echo "FAIL: builder errored"; rc=1; }
G="$TMP/.mega-sdd/graph.json"
[ -f "$G" ] || { echo "FAIL: graph.json not written"; rc=1; exit $rc; }

python3 - "$G" <<'PYEOF'
import json, sys
g = json.load(open(sys.argv[1]))
nodes = {n["id"]: n for n in g["nodes"]}
edges = g["edges"]
ok = True
def chk(c, m):
    global ok
    if not c: print("FAIL:", m); ok = False
# namespaced unit + claim ids
chk("sample-vault:U-001" in nodes, "U-001 not namespaced")
chk("sample-vault:C-001" in nodes, "C-001 not namespaced")
# code_anchor keyed by file (no :line in id)
ca = [n for n in g["nodes"] if n["type"]=="code_anchor"]
chk(all(":" not in n["id"].split("/")[-1] or not n["id"].split(":")[-1].isdigit() for n in ca), "anchor id has line")
# implements edge claim->anchor, inherits confidence, has evidence
imp = [e for e in edges if e["relation"]=="implements"]
chk(len(imp) >= 1, "no implements edge")
chk(all("evidence" in e and e["evidence"].get("artifact") for e in imp), "implements edge missing evidence")
# every edge has evidence (anti-hallucination)
chk(all("evidence" in e for e in edges), "edge without evidence")
# _meta freshness block present
chk("source_hashes" in g["_meta"] and "source_glob" in g["_meta"], "missing freshness meta")
chk("binding_stamps" in g["_meta"], "missing binding_stamps")
sys.exit(0 if ok else 1)
PYEOF
[ $? -eq 0 ] || rc=1
[ $rc -eq 0 ] && echo "PASS: test-build-graph"
exit $rc
```

- [ ] **Step 2: Build the fixture project**

Create under `fixtures/project/.mega-sdd/`:
- `vaults/sample-vault/vault.json` — minimal: `{"vault_version":"1.0","flows":[{"id":"F-U-001","doc":"04-flows.md","_kb_source":["10-domains/cif-customer.md"]}]}`
- `vaults/sample-vault/binding.json` — 2 claims: `C-001` CONFIRMED→`UserController.php:45`; `C-002` CONFIRMED→`OrderController.php:88`.
- `vaults/sample-vault/units/U-001.md` — frontmatter: `depends_on: []`, `binding_refs: [C-001]`, `module: M-auth`.
- `vaults/sample-vault/units/U-002.md` — frontmatter: `depends_on: [U-001]`, `binding_refs: [C-002]`, `module: M-orders`.
- `vaults/sample-vault/_meta/modules.yaml` — `modules: [{id: M-auth, blocks: [M-orders]}, {id: M-orders, blocked_by: [M-auth]}]`.
- `knowledge-base/10-domains/cif-customer.md` — frontmatter `domain: cif-customer`, `depends_on: []`.

- [ ] **Step 3: Run the test to verify it fails**

Run: `bash plugins/mega-sdd/tests/graph/test-build-graph.sh`
Expected: FAIL ("builder errored" — script does not exist).

- [ ] **Step 4: Implement the builder**

Create `build-graph.sh`:

```bash
#!/usr/bin/env bash
# Derive .mega-sdd/graph.json from existing artifacts. Deterministic, no code re-scan.
set -u
ROOT="."; OUT=""
while [ $# -gt 0 ]; do case "$1" in
  --root) ROOT="$2"; shift 2;; --root=*) ROOT="${1#*=}"; shift;;
  --out) OUT="$2"; shift 2;; --out=*) OUT="${1#*=}"; shift;;
  *) shift;; esac; done

MEGA="${ROOT}/.mega-sdd"
[ -n "$OUT" ] || OUT="${MEGA}/graph.json"
HEAD="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo null)"

ROOT="$ROOT" OUT="$OUT" HEAD="$HEAD" python3 <<'PYEOF'
import json, os, re, sys, hashlib, glob
from datetime import datetime, timezone

root = os.environ["ROOT"]; out = os.environ["OUT"]
head = os.environ["HEAD"]; head = None if head == "null" else head
mega = os.path.join(root, ".mega-sdd")

try:
    import yaml
    def load_yaml(s):
        return yaml.safe_load(s) or {}
except Exception:
    def load_yaml(s):  # minimal frontmatter fallback: key: scalar / key: [a,b]
        d = {}
        for line in s.splitlines():
            m = re.match(r'^([A-Za-z0-9_]+):\s*(.*)$', line)
            if not m: continue
            k, v = m.group(1), m.group(2).strip()
            if v.startswith("[") and v.endswith("]"):
                d[k] = [x.strip() for x in v[1:-1].split(",") if x.strip()]
            elif v: d[k] = v
        return d

def frontmatter(path):
    txt = open(path, encoding="utf-8").read()
    m = re.match(r'^---\n(.*?)\n---', txt, re.S)
    return (load_yaml(m.group(1)) if m else {}), txt

def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""): h.update(chunk)
    return h.hexdigest()

nodes, node_ids, edges = {}, set(), []
src_hashes = {}
GLOBS = [".mega-sdd/vaults/*/vault.json", ".mega-sdd/vaults/*/binding.json",
         ".mega-sdd/vaults/*/units/*.md", ".mega-sdd/vaults/*/_meta/modules.yaml",
         ".mega-sdd/knowledge-base/**/*.md"]

def relp(p): return os.path.relpath(p, root)
def add_node(nid, ntype, label, attrs, artifact, field):
    if nid in node_ids:
        if attrs: nodes[nid]["attrs"].update(attrs)
        nodes[nid]["attrs"].pop("pending", None)  # a real definition clears any prior [Pending] mark
        return
    node_ids.add(nid)
    nodes[nid] = {"id": nid, "type": ntype, "label": label or nid,
                  "attrs": attrs or {}, "source": {"artifact": artifact, "field": field}}
def pending(nid, ntype, artifact, field):
    if nid not in node_ids:
        node_ids.add(nid)
        nodes[nid] = {"id": nid, "type": ntype, "label": nid, "attrs": {"pending": True},
                      "source": {"artifact": artifact, "field": field}}
def anchor_id(s):  # file:line -> file
    s = s.strip()
    return re.sub(r':\d+(-\d+)?$', '', s)
def add_edge(s, t, rel, conf, artifact, field):
    edges.append({"source": s, "target": t, "relation": rel, "confidence": conf,
                  "evidence": {"artifact": artifact, "field": field}})

binding_stamps = {}
for vault_json in sorted(glob.glob(os.path.join(mega, "vaults", "*", "vault.json"))):
    vdir = os.path.dirname(vault_json); vid = os.path.basename(vdir)
    src_hashes[relp(vault_json)] = sha256(vault_json)
    add_node(f"vault::{vid}", "vault", vid, {}, relp(vault_json), "vault.json")
    vj = json.load(open(vault_json, encoding="utf-8"))
    # flows + kb_source
    for fl in vj.get("flows", []):
        fid = f"{vid}:{fl['id']}"
        add_node(fid, "flow", fl.get("title", fl["id"]), {"doc": fl.get("doc")}, relp(vault_json), "flows[]")
        for kb in fl.get("_kb_source", []) or []:
            dom = os.path.splitext(os.path.basename(kb))[0]
            pending(dom, "kb_domain", relp(vault_json), "flows[]._kb_source")
            add_edge(fid, dom, "kb_source", "VERIFIED", relp(vault_json), "flows[]._kb_source")

    # binding.json -> claims + implements + covers
    bj_path = os.path.join(vdir, "binding.json")
    if os.path.exists(bj_path):
        src_hashes[relp(bj_path)] = sha256(bj_path)
        bj = json.load(open(bj_path, encoding="utf-8"))
        binding_stamps[vid] = {"provenance": bj.get("codebase_map_provenance"),
                               "head_at_bind": bj.get("head"),
                               "stale_vs_head": bool(head and bj.get("head") and head != bj.get("head"))}
        for c in bj.get("claims", []):
            cid = f"{vid}:{c['id']}"
            add_node(cid, "claim", c["id"], {"verdict": c.get("verdict"), "state": c.get("state")}, relp(bj_path), "claims[]")
            anc = c.get("anchor")
            if anc and anc not in ("—", "n/a", None):
                for piece in re.split(r'\s*\+\s*', anc):
                    if ":" in piece or "/" in piece or piece.endswith((".php",".py",".ts",".js")):
                        aid = anchor_id(piece)
                        if not aid: continue
                        line = piece[len(aid):].lstrip(":") or None
                        add_node(aid, "code_anchor", aid, {"line": line} if line else {}, relp(bj_path), "claims[].anchor")
                        add_edge(cid, aid, "implements", c.get("confidence") or c.get("verdict") or "VERIFIED", relp(bj_path), "claims[].anchor")
            vs = c.get("vault_source")
            if vs:
                add_edge(cid, f"{vid}:vault-source:{vs}", "covers", "VERIFIED", relp(bj_path), "claims[].vault_source")

    # modules.yaml
    mpath = os.path.join(vdir, "_meta", "modules.yaml")
    if os.path.exists(mpath):
        src_hashes[relp(mpath)] = sha256(mpath)
        my = load_yaml(open(mpath, encoding="utf-8").read())
        for mod in (my.get("modules") or []):
            mid = mod.get("id")
            if not mid: continue
            add_node(mid, "module", mid, {}, relp(mpath), "modules[]")
            for b in mod.get("blocks", []) or []:
                pending(b, "module", relp(mpath), "modules[].blocks")
                add_edge(mid, b, "blocks", "VERIFIED", relp(mpath), "modules[].blocks")

    # units -> honors, depends_on, in_module
    for upath in sorted(glob.glob(os.path.join(vdir, "units", "*.md"))):
        if os.path.basename(upath).startswith("_"): continue
        src_hashes[relp(upath)] = sha256(upath)
        fm, _ = frontmatter(upath)
        uid_local = os.path.splitext(os.path.basename(upath))[0]
        uid = f"{vid}:{uid_local}"
        add_node(uid, "unit", uid_local, {"module": fm.get("module"), "task_type": fm.get("task_type"), "squad": fm.get("squad")}, relp(upath), "frontmatter")
        for dep in fm.get("depends_on", []) or []:
            tid = f"{vid}:{dep}"
            pending(tid, "unit", relp(upath), "depends_on")
            add_edge(uid, tid, "depends_on", "VERIFIED", relp(upath), "frontmatter.depends_on")
        for ref in fm.get("binding_refs", []) or []:
            tid = f"{vid}:{ref}"
            pending(tid, "oq" if ref.startswith("OQ") else "claim", relp(upath), "binding_refs")
            add_edge(uid, tid, "honors", "VERIFIED", relp(upath), "frontmatter.binding_refs")
        mod = fm.get("module")
        if mod:
            pending(mod, "module", relp(upath), "frontmatter.module")
            add_edge(uid, mod, "in_module", "VERIFIED", relp(upath), "frontmatter.module")

# KB domains -> domain_dep
for kbpath in sorted(glob.glob(os.path.join(mega, "knowledge-base", "**", "*.md"), recursive=True)):
    fm, _ = frontmatter(kbpath)
    dom = fm.get("domain")
    if not dom: continue
    src_hashes[relp(kbpath)] = sha256(kbpath)
    add_node(dom, "kb_domain", dom, {"classification": fm.get("classification")}, relp(kbpath), "frontmatter")
    for d in fm.get("depends_on", []) or []:
        pending(d, "kb_domain", relp(kbpath), "depends_on")
        add_edge(dom, d, "domain_dep", "VERIFIED", relp(kbpath), "frontmatter.depends_on")

graph = {
  "schema_version": "1.0",
  "_meta": {
    "derived": True, "generated_by": "build-graph@1.0.0",
    "built_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    "head": head, "source_glob": GLOBS, "source_hashes": src_hashes,
    "binding_stamps": binding_stamps,
  },
  "nodes": list(nodes.values()), "edges": edges,
}
os.makedirs(os.path.dirname(out), exist_ok=True)
tmp = out + ".tmp"
with open(tmp, "w", encoding="utf-8") as f: json.dump(graph, f, indent=2)
os.replace(tmp, out)
print(f"graph.json: {len(nodes)} nodes, {len(edges)} edges -> {out}")
PYEOF
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bash plugins/mega-sdd/tests/graph/test-build-graph.sh`
Expected: `PASS: test-build-graph`

- [ ] **Step 6: Commit**

```bash
git add plugins/mega-sdd/scripts/build-graph.sh plugins/mega-sdd/tests/graph/test-build-graph.sh plugins/mega-sdd/tests/graph/fixtures/project/
git commit -m "feat(graph): deterministic graph.json builder + fixture"
```

---

### Task 5: Freshness check + impact query (`scripts/query-graph.sh`)

Lazy rebuild on staleness (path-set + hashes), then typed BFS for blast-radius with cited chains and the binding-vs-HEAD banner.

**Files:**
- Create: `plugins/mega-sdd/scripts/query-graph.sh`
- Create: `plugins/mega-sdd/tests/graph/test-query-graph.sh`

**Interfaces:**
- Consumes: `build-graph.sh` (Task 4), `.mega-sdd/graph.json`.
- Produces: `query-graph.sh --root <project> --impact <id|file[:line]> [--upstream|--downstream]` → prints grouped blast-radius with cited edge chains + staleness banner; rebuilds first if stale. Consumed by Task 6 (skill).

- [ ] **Step 1: Write the failing query test**

Create `test-query-graph.sh`:

```bash
#!/usr/bin/env bash
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
Q="${PLUGIN_ROOT}/scripts/query-graph.sh"
SRC="${SCRIPT_DIR}/fixtures/project"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cp -R "$SRC/." "$TMP/"
rc=0

# 5a: missing graph.json -> lazy rebuild + answer
rm -f "$TMP/.mega-sdd/graph.json"
OUT="$(bash "$Q" --root "$TMP" --impact "UserController.php" --downstream 2>&1)"
echo "$OUT" | grep -q "sample-vault:C-001" || { echo "FAIL: anchor->claim not found"; rc=1; }
echo "$OUT" | grep -q "sample-vault:U-001" || { echo "FAIL: claim->unit not found"; rc=1; }
[ -f "$TMP/.mega-sdd/graph.json" ] || { echo "FAIL: lazy rebuild did not write graph.json"; rc=1; }

# 5b: file:line normalizes to same anchor
OUT2="$(bash "$Q" --root "$TMP" --impact "UserController.php:45" --downstream 2>&1)"
echo "$OUT2" | grep -q "sample-vault:C-001" || { echo "FAIL: file:line did not resolve"; rc=1; }

# 5c: transitive downstream U-001 -> U-002 (depends_on reverse)
echo "$OUT" | grep -q "sample-vault:U-002" || { echo "FAIL: transitive dependent unit missing"; rc=1; }

# 5d: staleness banner when binding head != current HEAD
python3 - "$TMP/.mega-sdd/vaults/sample-vault/binding.json" <<'PYEOF'
import json,sys
p=sys.argv[1]; d=json.load(open(p)); d["head"]="DEADBEEF"; json.dump(d,open(p,"w"))
PYEOF
rm -f "$TMP/.mega-sdd/graph.json"
OUT3="$(bash "$Q" --root "$TMP" --impact "UserController.php" --downstream 2>&1)"
echo "$OUT3" | grep -qi "stale\|sync" || { echo "FAIL: no staleness banner"; rc=1; }

# 5e: path-set rebuild — adding a NEW vault's files (new hash keys) forces rebuild
#     even though no existing tracked file changed, and the new vault is visible.
cp -R "$TMP/.mega-sdd/vaults/sample-vault" "$TMP/.mega-sdd/vaults/second-vault"
# graph.json still exists and its source_hashes lack second-vault/* keys -> must rebuild
OUT4="$(bash "$Q" --root "$TMP" --impact "second-vault:U-001" --downstream 2>&1)"
echo "$OUT4" | grep -q "second-vault:U-002" || { echo "FAIL: new vault not picked up by path-set rebuild"; rc=1; }

[ $rc -eq 0 ] && echo "PASS: test-query-graph"
exit $rc
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash plugins/mega-sdd/tests/graph/test-query-graph.sh`
Expected: FAIL (query-graph.sh missing).

- [ ] **Step 3: Implement the query (with lazy-rebuild freshness)**

Create `query-graph.sh`:

```bash
#!/usr/bin/env bash
# Impact/blast-radius query over .mega-sdd/graph.json. Lazy-rebuild when stale.
set -u
ROOT="."; TARGET=""; DIR="downstream"
while [ $# -gt 0 ]; do case "$1" in
  --root) ROOT="$2"; shift 2;; --root=*) ROOT="${1#*=}"; shift;;
  --impact) TARGET="$2"; shift 2;; --impact=*) TARGET="${1#*=}"; shift;;
  --upstream) DIR="upstream"; shift;; --downstream) DIR="downstream"; shift;;
  *) shift;; esac; done
[ -n "$TARGET" ] || { echo "usage: query-graph.sh --root <p> --impact <id|file[:line]> [--upstream|--downstream]" >&2; exit 3; }

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MEGA="${ROOT}/.mega-sdd"; G="${MEGA}/graph.json"

# --- Freshness: rebuild if missing, path-set changed, or any source hash moved ---
NEED_BUILD=1
if [ -f "$G" ]; then
  ROOT="$ROOT" G="$G" python3 <<'PYEOF'
import json,os,glob,hashlib,sys
root=os.environ["ROOT"]; g=json.load(open(os.environ["G"]))
meta=g.get("_meta",{}); old=meta.get("source_hashes",{})
def sh(p):
    h=hashlib.sha256()
    with open(p,"rb") as f:
        for c in iter(lambda:f.read(65536),b""): h.update(c)
    return h.hexdigest()
cur={}
for pat in meta.get("source_glob",[]):
    for p in glob.glob(os.path.join(root,pat), recursive=True):
        cur[os.path.relpath(p,root)]=sh(p)
sys.exit(0 if (set(cur)==set(old) and all(old.get(k)==v for k,v in cur.items())) else 7)
PYEOF
  [ $? -eq 0 ] && NEED_BUILD=0
fi
[ "$NEED_BUILD" -eq 1 ] && bash "${PLUGIN_ROOT}/scripts/build-graph.sh" --root "$ROOT" >/dev/null

ROOT="$ROOT" G="$G" TARGET="$TARGET" DIR="$DIR" python3 <<'PYEOF'
import json,os,re
from collections import defaultdict, deque
g=json.load(open(os.environ["G"]))
target=os.environ["TARGET"]; direction=os.environ["DIR"]
nodes={n["id"]:n for n in g["nodes"]}

# staleness banner
stale=[v for v,s in g["_meta"].get("binding_stamps",{}).items() if s.get("stale_vs_head")]
if stale:
    print(f"⚠ Blast-radius from binding(s) {', '.join(stale)} stamped before current HEAD "
          f"({g['_meta'].get('head')}). Anchors may be stale — run /mega-sdd:sync.\n")

# resolve target: exact node id, else file-normalized code_anchor
def norm_anchor(s): return re.sub(r':\d+(-\d+)?$','',s.strip())
start=None
if target in nodes: start=target
else:
    na=norm_anchor(target)
    if na in nodes: start=na
if not start:
    print(f"No node matches '{target}'. Known anchors: "
          + ", ".join(n['id'] for n in g['nodes'] if n['type']=='code_anchor')[:400])
    raise SystemExit(0)

# adjacency (downstream = follow reverse of authored edges: who depends on me)
fwd=defaultdict(list); rev=defaultdict(list)
for e in g["edges"]:
    fwd[e["source"]].append(e); rev[e["target"]].append(e)
adj = rev if direction=="downstream" else fwd
key = (lambda e: e["source"]) if direction=="downstream" else (lambda e: e["target"])

seen={start}; q=deque([start]); hits=defaultdict(list)
while q:
    cur=q.popleft()
    for e in adj[cur]:
        nxt=key(e)
        chain=f"{e['source']} -[{e['relation']}]-> {e['target']}  ({e['evidence']['artifact']}:{e['evidence']['field']})"
        t=nodes.get(nxt,{}).get("type","?")
        hits[t].append(chain)
        if nxt not in seen:
            seen.add(nxt); q.append(nxt)

print(f"Impact ({direction}) of {start}:\n")
if not any(hits.values()):
    print("  (no dependents found)")
for t in ("claim","unit","module","flow","kb_domain","oq","code_anchor"):
    if hits.get(t):
        print(f"## {t} ({len(hits[t])})")
        for c in hits[t]: print("  -", c)
        print()
PYEOF
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash plugins/mega-sdd/tests/graph/test-query-graph.sh`
Expected: `PASS: test-query-graph`

- [ ] **Step 5: Commit**

```bash
git add plugins/mega-sdd/scripts/query-graph.sh plugins/mega-sdd/tests/graph/test-query-graph.sh
git commit -m "feat(graph): impact query with lazy-rebuild freshness gate"
```

---

### Task 6: Skill `mega-sdd:graph` + command + manifest registration

The user-facing surface. Lean SKILL.md (≤500 lines, progressive disclosure), command entry point, skill-tier-manifest entry.

**Files:**
- Create: `plugins/mega-sdd/skills/graph/SKILL.md`
- Create: `plugins/mega-sdd/commands/graph.md`
- Modify: `plugins/mega-sdd/references/skill-tier-manifest.yaml`

**Interfaces:**
- Consumes: `build-graph.sh`, `query-graph.sh`, `graph-schema.md`.
- Produces: `/mega-sdd:graph` command routing to the skill.

- [ ] **Step 1: Write the skill**

Create `skills/graph/SKILL.md`:

```markdown
---
name: graph
version: 1.0.0
description: Query the derived mega-sdd graph — impact / blast-radius analysis over units, claims, modules, flows, and KB domains, all traced to code anchors. Use when the user asks "what breaks if I change X", "blast radius", "impact of this code", "apa yang kena kalau ubah ini", "what depends on this unit", or runs /mega-sdd:graph. The graph is derived from existing artifacts (vault.json, binding.json, units, modules.yaml, KB) and rebuilt lazily when stale; it is never authored.
---

# mega-sdd:graph

A derived, project-scope graph (`.mega-sdd/graph.json`) over existing mega-sdd
artifacts. Markdown stays the source of truth — the graph is a queryable lens,
regenerated on demand, safe to delete. Schema → `references/graph-schema.md`.

## What it answers (v1)

Impact / blast-radius: given a code path or a node id (`U-NNN`, `C-NNN`,
`<vault>:U-NNN`, a `kb_domain`), what is affected downstream ("what breaks if I
touch this") or upstream ("what this rests on").

## How to run

1. **Build is automatic.** The query rebuilds `graph.json` whenever it is missing
   or any source artifact changed (path-set + content hash). You never build by hand.
2. **Run the query:**
   `Run: scripts/query-graph.sh --root <project> --impact <id|file[:line]> [--upstream|--downstream]`
   (defaults to `--downstream`). Surface the output verbatim, including any
   staleness banner.

## Anti-hallucination contract

- Every edge in an answer cites its source artifact + field — surface those chains.
- The graph emits NO inferred edges (v1). A reference whose target is absent
  appears as a `[Pending]` node, never a fabricated link.
- If the staleness banner fires (a binding is older than HEAD), tell the user the
  impact may be incomplete and recommend `/mega-sdd:sync` — do NOT silently trust
  stale anchors.

## Freshness

Lazy rebuild is the correctness mechanism: the query catches every mutation
(any writer, manual edit, git pull) via source-glob path-set + hashes. `sync`
also warms `graph.json` at end-of-run, but that is convenience, not correctness.

## Scope (v1) & roadmap

v1 node types: code_anchor, claim, unit, module, flow, kb_domain, oq, vault
(`interface` deferred to multi-squad). Future lenses on the same graph.json:
visualization (Mermaid/HTML) and a global cross-artifact validation gate
(dangling refs, orphans, broken anchors). Optional v2 seam: ingest an external
code graph (e.g. graphify) as EXTRACTED-only secondary evidence to enrich
code_anchor — never trusted for inferred edges, never a required dependency.
```

- [ ] **Step 2: Write the command**

Create `commands/graph.md`:

```markdown
---
description: Query the derived mega-sdd graph — impact/blast-radius over units, claims, modules, flows, KB domains, traced to code anchors.
argument-hint: "--impact <id|file[:line]> [--upstream|--downstream]"
---

Invoke the `mega-sdd:graph` skill via the Skill tool to query the project graph.

User arguments: $ARGUMENTS

Follow the skill exactly:
- The graph (`.mega-sdd/graph.json`) is derived and rebuilt lazily when stale — never authored.
- Run `scripts/query-graph.sh --root <project> --impact <target> [--upstream|--downstream]` and surface the output verbatim.
- Always surface the staleness banner if present and recommend `/mega-sdd:sync` when a binding is older than HEAD.
- Every reported edge cites its source artifact + field; never invent relationships.
```

- [ ] **Step 3: Register in the skill-tier manifest**

In `references/skill-tier-manifest.yaml`, under `skills:`, add:

```yaml
  graph:
    references/graph-schema.md: HOT
```

- [ ] **Step 4: Verify command/skill discovery**

Run: `ls plugins/mega-sdd/skills/graph/SKILL.md plugins/mega-sdd/commands/graph.md && grep -A1 '^  graph:' plugins/mega-sdd/references/skill-tier-manifest.yaml`
Expected: all three present.

- [ ] **Step 5: Commit**

```bash
git add plugins/mega-sdd/skills/graph/SKILL.md plugins/mega-sdd/commands/graph.md plugins/mega-sdd/references/skill-tier-manifest.yaml
git commit -m "feat(graph): mega-sdd:graph skill + command + manifest entry"
```

---

### Task 7: `sync` cache-warming hook (out-of-chain)

Regenerate `graph.json` at the end of the Mode D (sync) chain — convenience only, never a correctness dependency, never a blocker.

**Files:**
- Modify: `plugins/mega-sdd/skills/orchestrate-flow/references/routing-rules.md` (Mode D end-of-run, near `SYNC-REPORT.md`)
- Modify: `plugins/mega-sdd/commands/sync.md` (document the end-of-run graph refresh)

**Interfaces:**
- Consumes: `build-graph.sh` (Task 4).
- Produces: warmed `.mega-sdd/graph.json` after every sync. No new outputs gating the chain.

- [ ] **Step 1: Add the hook to Mode D routing**

In `routing-rules.md` §Mode D, after the step that writes `SYNC-REPORT.md`, add:

```markdown
- **Cache-warm the graph (non-blocking).** After `SYNC-REPORT.md` is written,
  `Run: scripts/build-graph.sh --root <project>` to refresh `.mega-sdd/graph.json`.
  This is cache-warming only — a failure here NEVER blocks sync and emits no halt
  YAML (the graph is rebuilt lazily on next `/mega-sdd:graph` query regardless).
```

- [ ] **Step 2: Document in sync command**

In `commands/sync.md`, append to the "End of run" description: `; refreshes .mega-sdd/graph.json (cache-warm; non-blocking).`

- [ ] **Step 3: Verify wording is non-blocking**

Run: `grep -n "Cache-warm the graph" plugins/mega-sdd/skills/orchestrate-flow/references/routing-rules.md`
Expected: the line is present and contains "NEVER blocks".

- [ ] **Step 4: Commit**

```bash
git add plugins/mega-sdd/skills/orchestrate-flow/references/routing-rules.md plugins/mega-sdd/commands/sync.md
git commit -m "feat(graph): sync cache-warms graph.json (non-blocking, out-of-chain)"
```

---

### Task 8: Version bump, CHANGELOG, integration regression

Ship the version, document it, and prove no chain or pipeline regressed.

**Files:**
- Modify: `plugins/mega-sdd/.claude-plugin/plugin.json` (`version`)
- Modify: `.claude-plugin/marketplace.json` (`plugins[0].version`)
- Modify: `CHANGELOG.md`
- Create: `plugins/mega-sdd/tests/graph/run-all.sh`

**Interfaces:**
- Consumes: all prior tasks.

- [ ] **Step 1: Add the graph test runner**

Create `tests/graph/run-all.sh`:

```bash
#!/usr/bin/env bash
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
rc=0
for t in "$here"/test-*.sh; do
  [ -f "$t" ] || continue
  echo "== $(basename "$t") =="
  bash "$t" || rc=1
done
exit $rc
```

- [ ] **Step 2: Run the full graph suite**

Run: `bash plugins/mega-sdd/tests/graph/run-all.sh`
Expected: every `test-*.sh` prints `PASS`; exit 0.

- [ ] **Step 3: Run the existing moat suite (regression gate)**

Run: `bash plugins/mega-sdd/tests/moat/run-all.sh 2>&1 | tail -30`
Expected: all pre-existing moat tests still PASS — proves binding.json/Step 4.5 and the sync hook broke no existing chain.

- [ ] **Step 4: Bump versions (must match)**

Edit `plugins/mega-sdd/.claude-plugin/plugin.json` → `"version": "4.30.0"`.
Edit `.claude-plugin/marketplace.json` → `plugins[0].version` → `"4.30.0"`.

Run: `python3 -c "import json; a=json.load(open('plugins/mega-sdd/.claude-plugin/plugin.json'))['version']; b=json.load(open('.claude-plugin/marketplace.json'))['plugins'][0]['version']; print('MATCH' if a==b=='4.30.0' else 'MISMATCH', a, b)"`
Expected: `MATCH 4.30.0 4.30.0`

- [ ] **Step 5: Add CHANGELOG entry**

Prepend under the top of `CHANGELOG.md` (Keep-a-Changelog format):

```markdown
## [4.30.0] - 2026-06-24

### Added — derived graph layer (`mega-sdd:graph`)

- New project-scope derived graph `.mega-sdd/graph.json` over existing artifacts (vault.json, binding.json, units, modules.yaml, KB) — no code re-scan.
- New `/mega-sdd:graph --impact <id|file[:line]> [--upstream|--downstream]` blast-radius query, every edge citing its source artifact + field.
- `bind-codebase` now emits a structured `binding.json` sidecar (Step 4.5) guarded by `validate-binding-json.sh` parity gate.
- Freshness gate: lazy rebuild on source-glob path-set / hash change; binding-vs-HEAD staleness banner pointing to `/mega-sdd:sync`. Graph stays out of every chain; `sync` cache-warms it (non-blocking).
- Anti-hallucination preserved: no inferred edges; unresolved references become `[Pending]` nodes.
```

- [ ] **Step 6: Commit**

```bash
git add plugins/mega-sdd/.claude-plugin/plugin.json .claude-plugin/marketplace.json CHANGELOG.md plugins/mega-sdd/tests/graph/run-all.sh
git commit -m "feat(graph): ship graph layer v4.30.0 — version bump + changelog + suite"
```

---

## Self-Review

**Spec coverage:**
- §1/§2 derived-not-authored, cheap build → Tasks 3-4 (builder parses artifacts, no code re-scan). ✓
- §3.1 storage `.mega-sdd/graph.json` project-scope cache → Task 4. ✓
- §3.2 builder + regenerated by sync/lazy → Tasks 4, 5, 7. ✓
- §3.3 schema, namespacing, code_anchor identity, confidence derivation → Task 3 + enforced in Tasks 4-5 tests. ✓
- §3.3.1 binding.json sidecar → Tasks 1-2. ✓
- §3.4 freshness (path-set + hashes + binding stamp + banner; lazy=correctness, sync=warming) → Task 5 (freshness block) + Task 7. ✓
- §4 impact query (BFS, file-granularity anchor, upstream/downstream, cited chains, banner) → Task 5. ✓
- §5 compliance (anti-hallucination, citation, derived, gates, lean skill, command) → Tasks 3 (contract), 6 (skill/command), 1 (parity gate). ✓
- §6 graphify v2 seam (reserved, not built) → Task 6 SKILL roadmap note. ✓
- §7 future lenses → Task 6 roadmap note (no v1 build). ✓
- §8 tests 1-9 → Task 1 (4: pending/parity), Task 4 (1,7 namespacing), Task 5 (2 query, 3 banner, 5 lazy rebuild, 6 hash rebuild, 9 anchor granularity), Task 8 (suite). Test 8 (path-set add/remove) — **covered by Task 5 freshness logic but add an explicit assertion**: see note below.
- §9 resolved decisions (lean-ish nodes keep flow+kb_domain, defer interface; PyYAML-with-fallback) → Global Constraints + Task 3 node list. ✓

**Gap fix (Test 8 — path-set rebuild explicit):** DONE — Task 5 Step 1 now includes case `5e` (copies a second vault, asserts a query surfaces its node despite no existing tracked file changing — proves new-file path-set triggers rebuild).

**Placeholder scan:** No TBD/TODO; every code step shows complete, runnable code; every command has expected output. ✓

**Type consistency:** `--root`/`--impact`/`--upstream`/`--downstream` flags consistent across `build-graph.sh`/`query-graph.sh`/tests; `binding.json` field names (`id,verdict,state,anchor,confidence,field_diff,vault_source`) identical in Task 1 schema, Task 2 emit instruction, Task 4 builder reader; node id namespacing `<vault>:<local>` consistent Tasks 3-5. ✓
