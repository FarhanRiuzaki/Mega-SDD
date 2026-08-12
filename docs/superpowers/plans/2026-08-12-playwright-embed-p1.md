# Playwright Embed P1 (v6.8.0) Implementation Plan — D0 packaging + D1 /slice

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship v6.8.0 — bundle the Playwright MCP server so every mega-sdd install gets browser tooling automatically (D0), and add the `/mega-sdd:slice` standalone slicing verb (D1), per `docs/superpowers/specs/2026-08-12-playwright-embed-design.md`.

**Architecture:** A plugin-root `.mcp.json` auto-registers `@playwright/mcp` (pinned 0.0.79) on plugin enable. `/mega-sdd:slice` = thin command (`commands/slice.md`) dispatching a new `skills/slice-design/` skill; containment = command-invocation only (no census keywords, no anchor-core growth). The exactly-7 command-surface pins are amended ON-RECORD in the same commit as the new command file.

**Tech Stack:** Bash test suites (repo convention), JSON manifest, markdown skills/commands. No new runtime dependencies.

## Global Constraints

- Spec of record: `docs/superpowers/specs/2026-08-12-playwright-embed-design.md` (P1 = D0 + D1 only; D2/D3 are LATER releases — do not touch emit-uat or review-panel).
- MCP pin: `@playwright/mcp@0.0.79` EXACT (verified 2026-08-12 via registry.npmjs.org; Node >=18; flags `--headless`, `--isolated` verified via github.com/microsoft/playwright-mcp). NEVER `@latest` or a floating tag.
- `/slice` containment: NO free-text census keywords in any description; NO text above the `ANCHOR-CORE ends` marker in `skills/using-mega-sdd/SKILL.md`; NO auto-routing from `orchestrate-flow` or `commands/mega-sdd.md`.
- `/slice` never writes vault/binding, never starts/installs/backgrounds a dev server, compare loop caps at 3 rounds, report goes to `.mega-sdd/slices/<slug>/slice-report.md`.
- Surface growth is deliberate: CLAUDE.md sentences + test-p6 §C2 amendments land in the SAME commit as `commands/slice.md` — never a test loosened after the fact.
- Repo rules: NEVER `git add -A` (untracked `.mega-sdd/` trees are live field state); tests run with `</dev/null`; state reads via `rtk proxy git`; full suite runs BOTH test trees AFTER all edits; commit trailers `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>` + `Claude-Session: https://claude.ai/code/session_01JRFsor81mkZxbmivABixCy`.
- All paths below are relative to the repo root; `$P` = `plugins/mega-sdd` in test snippets (the suite convention).

---

### Task 1: `.mcp.json` manifest + contract-test scaffold + release-checklist hook

**Files:**
- Create: `plugins/mega-sdd/.mcp.json`
- Create: `tests/playwright-embed/test-playwright-embed-contracts.sh`
- Modify: `plugins/mega-sdd/CLAUDE.md` (§Versioning & release — one added line)
- Modify: `docs/superpowers/specs/2026-08-12-playwright-embed-design.md` (D0 JSON block — fill the verified pin + add `--isolated`)

**Interfaces:**
- Produces: `tests/playwright-embed/test-playwright-embed-contracts.sh` with `ok()`/`fail()` helpers and a running arm counter — Tasks 2, 4, 5 APPEND arms to this same file.
- Produces: `plugins/mega-sdd/.mcp.json` with exactly one server key `playwright`.

- [ ] **Step 1: Write the failing contract test**

Create `tests/playwright-embed/test-playwright-embed-contracts.sh` (mirror the header style of `tests/delta-lane/test-delta-lane-contracts.sh` — set -u, repo-root resolution, PASS/FAIL counters):

```bash
#!/usr/bin/env bash
# test-playwright-embed-contracts.sh — P1 contract pins for the Playwright embed
# (spec: docs/superpowers/specs/2026-08-12-playwright-embed-design.md).
# Every arm greps SHIPPED surfaces; run </dev/null like the sibling suites.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
P="$ROOT/plugins/mega-sdd"
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ok: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }
has()  { grep -qF "$2" "$1"; }

echo "── A: .mcp.json shape (D0) ──"
MCP="$P/.mcp.json"
# A1: file exists and is valid JSON
if [ -f "$MCP" ] && python3 -c "import json;json.load(open('$MCP'))" 2>/dev/null; then
  ok "A1 .mcp.json exists + valid JSON"
else
  fail "A1 .mcp.json missing or invalid JSON"
fi
# A2: exactly one server, named playwright, stdio via npx
python3 - "$MCP" <<'PY' && ok "A2 exactly one stdio server 'playwright' via npx" || fail "A2 server shape wrong"
import json,sys
d=json.load(open(sys.argv[1]))
s=d.get("mcpServers",{})
assert list(s.keys())==["playwright"], s.keys()
pw=s["playwright"]
assert pw.get("type")=="stdio" and pw.get("command")=="npx", pw
assert "env" not in pw and "alwaysLoad" not in pw
PY
# A3: version pinned EXACT — a floating tag is the registry-rot class
if grep -qE '@playwright/mcp@[0-9]+\.[0-9]+\.[0-9]+"' "$MCP" && ! grep -qE '@(latest|next|beta|alpha)"' "$MCP"; then
  ok "A3 @playwright/mcp pinned to an exact version (no floating tag)"
else
  fail "A3 pin is floating or malformed"
fi
# A4: the release checklist reviews the pin at each bump
has "$P/CLAUDE.md" ".mcp.json" \
  && ok "A4 CLAUDE.md §Versioning names the .mcp.json pin" \
  || fail "A4 release checklist missing the .mcp.json pin review"

echo; echo "playwright-embed contracts: $PASS ok, $FAIL fail"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/playwright-embed/test-playwright-embed-contracts.sh </dev/null`
Expected: FAIL on A1–A4 (`.mcp.json` doesn't exist yet).

- [ ] **Step 3: Create `plugins/mega-sdd/.mcp.json`**

```json
{
  "mcpServers": {
    "playwright": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@playwright/mcp@0.0.79", "--headless", "--isolated"]
    }
  }
}
```

`--isolated` (in-memory browser profile) is a deliberate addition beyond the spec's draft JSON: the user runs parallel sessions on the same tree, and the Playwright MCP docs state persistent profiles cannot be shared between concurrent instances. Update the spec's D0 JSON block to match (pin `0.0.79` + `--isolated`, one-line rationale).

- [ ] **Step 4: Add the release-checklist line**

In `plugins/mega-sdd/CLAUDE.md`, §Versioning & release, after the `- **Release:** …` bullet, add:

```markdown
- **MCP pin:** `.mcp.json` pins `@playwright/mcp` to an exact version — review the pin (registry-rot check) at each plugin version bump, like the marketplace.json parity check. Never a floating tag.
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bash tests/playwright-embed/test-playwright-embed-contracts.sh </dev/null`
Expected: PASS (A1–A4 ok, exit 0). Also run `bash tests/surface/test-p6-front-door.sh </dev/null` — must still PASS (nothing here touches commands/).

- [ ] **Step 6: Commit**

```bash
git add plugins/mega-sdd/.mcp.json tests/playwright-embed/test-playwright-embed-contracts.sh plugins/mega-sdd/CLAUDE.md docs/superpowers/specs/2026-08-12-playwright-embed-design.md
git commit -m "feat(mcp): bundle @playwright/mcp 0.0.79 via plugin-root .mcp.json (D0) + shape pins"
```

---

### Task 2: `skills/slice-design/` — the skill + its reference

**Files:**
- Create: `plugins/mega-sdd/skills/slice-design/SKILL.md`
- Create: `plugins/mega-sdd/skills/slice-design/references/slice-procedure.md`
- Modify: `tests/playwright-embed/test-playwright-embed-contracts.sh` (append section B)

**Interfaces:**
- Consumes: nothing (inert until Task 3's command dispatches it).
- Produces: skill name `mega-sdd:slice-design`; announce tag `mega-sdd-trace:slice-design`; report path contract `.mega-sdd/slices/<slug>/slice-report.md`.

- [ ] **Step 1: Append failing section-B arms to the contract test**

Append before the final summary block of `tests/playwright-embed/test-playwright-embed-contracts.sh`:

```bash
echo "── B: slice-design containment (D1) ──"
SD="$P/skills/slice-design/SKILL.md"
# B1: skill exists with valid one-line description frontmatter
[ -f "$SD" ] && ok "B1 slice-design SKILL.md exists" || fail "B1 slice-design SKILL.md missing"
# B2: description declares command-invocation-only and carries NO census list
DESC=$(grep '^description:' "$SD" | head -1)
echo "$DESC" | grep -qF "Command-invocation only" && ok "B2a description declares command-invocation only" || fail "B2a missing command-only declaration"
echo "$DESC" | grep -qF "never auto-triggers" && ok "B2b description disclaims auto-trigger" || fail "B2b missing auto-trigger disclaimer"
echo "$DESC" | grep -qF 'Triggers —' && fail "B2c description carries a trigger census (census leak)" || ok "B2c no trigger census in description"
# B3: the binding containment sentences exist in the body
has "$SD" "NEVER writes the vault" && ok "B3a no-vault-write pin" || fail "B3a no-vault-write sentence missing"
has "$SD" "NEVER starts, installs, or backgrounds a dev server" && ok "B3b server-ownership pin" || fail "B3b server-ownership sentence missing"
has "$SD" "cap: 3 compare rounds" && ok "B3c compare-round cap pin" || fail "B3c round-cap sentence missing"
has "$SD" "render was NOT verified" && ok "B3d honest-skip wording pin" || fail "B3d honest-skip sentence missing"
has "$SD" ".mega-sdd/slices/" && ok "B3e report-location pin" || fail "B3e report location missing"
# B4: reference routed one level deep
has "$SD" "references/slice-procedure.md" && ok "B4 slice-procedure routed from SKILL" || fail "B4 reference unrouted"
```

- [ ] **Step 2: Run to verify the new arms fail**

Run: `bash tests/playwright-embed/test-playwright-embed-contracts.sh </dev/null`
Expected: section A PASS, section B FAIL (skill absent).

- [ ] **Step 3: Create `plugins/mega-sdd/skills/slice-design/SKILL.md`**

```markdown
---
name: slice-design
version: 1.0.0
description: Standalone UI slicing — implement components from a design reference (Figma export, reference URL, or image file) and verify the render via the bundled Playwright MCP; works with or without a vault. Command-invocation only (/mega-sdd:slice) — this skill never auto-triggers off free text.
---

# Slice-Design — reference → UI code → verified render

**Announce at start:** "I'm using the slice-design skill to slice this reference into UI code. `mega-sdd-trace:slice-design`"

> **Instruction language:** this skill reasons in English. Narrate (announce, clarifying questions, the report summary) in **Indonesian + English technical terms by default**; precedence = explicit request > the language the user writes in > Indonesian for short/ambiguous input. Tier-1 structural tokens stay English (→ `plugins/mega-sdd/references/output-language.md`). *(Greenfield-reachable: /mega-sdd:slice runs with no `.mega-sdd/` signal, so it carries the policy itself.)*

## When to use

ONLY via `/mega-sdd:slice` (or an explicit user request naming this skill). This skill is deliberately OUTSIDE the free-text census: a bare "slicing" sentence routes nowhere — the surface-cull containment decision (spec 2026-08-12, on record).

## Inputs (at least one reference required)

- `--figma=<url>` — consumed via the user's own Figma MCP when its tools are present; when absent, ASK for an exported image instead (never scrape the URL).
- `--url=<web>` — reference site, captured via the bundled Playwright MCP.
- `--image=<path>` — exported design file (PNG/JPG/WebP).
- `--rounds=<n>` — compare-round override, hard cap 3.

## Procedure (full loop → `references/slice-procedure.md`)

1. **Reference intake** → component inventory. At most 3 clarifying questions (where in the repo, which route, which framework), each with keterangan per the OQ interaction rule.
2. **Implement** following the ACTIVE framework pack + the design-intelligence corpus (`plugins/mega-sdd/references/ui-design-heuristics.md`, `references/design-intelligence/{style-principles,ux-rules}.md`) — REUSE, never author new design knowledge. If a vault exists, its `design_system` tokens are optional enrichment; this skill **NEVER writes the vault or binding** — it is a code-emission verb only.
3. **Render-compare** (cap: 3 compare rounds): open the dev-server URL (`.mega-sdd/config.yaml` `preview_url:` or operator-supplied) via Playwright MCP → screenshot → model-judged compare vs the reference → iterate. NO pixel-diff tooling.
4. **Report** → `.mega-sdd/slices/<slug>/slice-report.md` (slug = kebab-case of the primary component/route): files created, reference mapping, remaining deltas (honest). When MCP/browser/server was absent, the report states literally that the render was NOT verified.

## Dev-server ownership (binding)

The dev server is OPERATOR-owned. This skill **NEVER starts, installs, or backgrounds a dev server** (unbounded-spawn + zombie class under Git Bash/EDR). Unreachable `preview_url` → compare rounds = 0 + the honest-skip statement — mirror of `capture-views.sh`'s "start it, then re-run" contract.

## Degradation

Playwright MCP absent/disabled/failed → code generation still happens from the reference; only the compare loop degrades (SKIP with the stated reason). A browser is NEVER load-bearing; nothing here gates.

## Outputs

```
<repo>/<framework-conventional component paths>   # the sliced UI code
<project>/.mega-sdd/slices/<slug>/slice-report.md # the honest report
```
```

- [ ] **Step 4: Create `plugins/mega-sdd/skills/slice-design/references/slice-procedure.md`**

```markdown
# Slice procedure — the detailed loop

## 1. Reference intake

- `--image` / Figma-export image: Read the image directly (multimodal) — extract layout regions, component types, typography scale, spacing rhythm, color roles.
- `--url`: navigate via Playwright MCP (tabs/navigate + screenshot tools loaded on demand through ToolSearch), capture at 1280 and 390 widths, then treat the captures as the reference images.
- `--figma=<url>`: if the user's session has Figma MCP tools (`mcp__figma__get_design_context` / `get_screenshot`), use them for the design context; otherwise ASK for an exported image (never scrape figma.com).

## 2. Component inventory + clarifying questions

Derive the component list (e.g. navbar, hero, card grid, form). Ask AT MOST 3 questions via AskUserQuestion, each with keterangan (Indonesian, per the OQ rule): target location in the repo, target route/page, framework confirmation when detection is ambiguous. Sensible defaults over questions — an existing framework pack + obvious component dir needs zero questions.

## 3. Implementation rules

- Follow the ACTIVE framework pack conventions (file locations, naming, idioms) exactly as a bolt would.
- Design floor comes from the corpus: tokens/spacing/typography per `ui-design-heuristics.md`; interaction + a11y floor per `design-intelligence/ux-rules.md`; composition per `style-principles.md`.
- Vault `design_system` tokens (when a vault exists): prefer them over invented values — enrichment only, no vault read is required to proceed.
- Reuse-first: check the symbol index / existing components before authoring a new one (never rebuild an existing button).

## 4. Render-compare rounds (≤3)

Per round: screenshot the implemented route at 1280 + 390 via Playwright MCP → compare against the reference (layout fidelity, spacing, typography, color roles, states) → apply the deltas. Stop early when the render matches; after round 3, STOP and report the remaining deltas honestly. Never claim a match that was not rendered.

## 5. The report (always emitted)

`.mega-sdd/slices/<slug>/slice-report.md`:

```markdown
# Slice report — <slug> (<date>)

**Reference:** <figma url | web url | image path>
**Files created/modified:** <list>
**Compare rounds run:** <0-3> (<why 0 if 0 — e.g. "preview_url unreachable — render NOT verified">)
**Reference mapping:** <component → file table>
**Remaining deltas:** <honest list, or "none observed at 1280/390">
```

The report is a plugin artifact — it never lands in the user's source tree.
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bash tests/playwright-embed/test-playwright-embed-contracts.sh </dev/null`
Expected: sections A + B PASS, exit 0.

- [ ] **Step 6: Commit**

```bash
git add plugins/mega-sdd/skills/slice-design tests/playwright-embed/test-playwright-embed-contracts.sh
git commit -m "feat(slice): slice-design skill 1.0.0 — reference → UI code → verified render (D1, command-only containment)"
```

---

### Task 3: `commands/slice.md` + the on-record surface-growth amendments (ONE commit)

**Files:**
- Create: `plugins/mega-sdd/commands/slice.md`
- Modify: `plugins/mega-sdd/CLAUDE.md` (the two "exactly 7 files" / "NOTHING else" sentences)
- Modify: `tests/surface/test-p6-front-door.sh` (§C2 count + roster; §D first-class loop; §C header text)
- Modify: `plugins/mega-sdd/commands/mega-sdd.md` (the "three public verbs" blockquote, line 6)
- Modify: `README.md` + `plugins/mega-sdd/README.md` (every surface-count mention)

**Interfaces:**
- Consumes: `mega-sdd:slice-design` skill (Task 2).
- Produces: the 8-file command surface; `/mega-sdd:slice` public entry.

- [ ] **Step 1: Create `plugins/mega-sdd/commands/slice.md`**

```markdown
---
description: "Standalone UI slicing — implement components from a design reference (Figma export / reference URL / image file) and verify the render via the bundled Playwright MCP. Works with or without a vault; never writes vault or binding; never starts a dev server."
argument-hint: "[--figma=<url>] [--url=<web>] [--image=<path>] [--rounds=<n≤3>]"
---

Invoke the `mega-sdd:slice-design` skill via the Skill tool.

User arguments: $ARGUMENTS

Argument parsing:
- `--figma=<url>`: design reference in Figma — used via the user's own Figma MCP when present; otherwise the skill asks for an exported image (never scrapes)
- `--url=<web>`: a reference site to slice from (captured via Playwright MCP)
- `--image=<path>`: an exported design image (PNG/JPG/WebP)
- `--rounds=<n>`: compare-round override; hard cap 3
- No reference argument at all → the skill asks for ONE (with keterangan), then proceeds

Hard rails:
- This verb NEVER writes the vault or binding — it is a code-emission surface only (adding it to a bound project never touches `.mega-sdd/` state beyond its own `slices/` report dir).
- The dev server is OPERATOR-owned — the skill never starts, installs, or backgrounds one; unreachable `preview_url` → code still generated, render honestly reported as NOT verified.
- A browser is never load-bearing: Playwright MCP absent/disabled → the compare loop SKIPs with a stated reason; nothing gates.
- Command-invocation only: free-text "slicing" phrases do NOT auto-route here (surface-cull containment, spec 2026-08-12).
```

- [ ] **Step 2: Amend `plugins/mega-sdd/CLAUDE.md` — both surface sentences**

Sentence 1 (§Architecture, the Commands bullet — currently "…the public surface is THREE verbs: `/mega-sdd` (front door), `/mega-sdd:sync`, `/mega-sdd:emit <prd|fsd|sit|uat>`, plus the four maintenance one-timers (`migrate-paths`, `install-deps`, `update-plugin`, `memory`) — exactly 7 files, nothing else."). Replace that clause with:

```
the public surface is FOUR verbs: `/mega-sdd` (front door), `/mega-sdd:sync`, `/mega-sdd:emit <prd|fsd|sit|uat>`, `/mega-sdd:slice` (standalone UI slicing — ADDED 6.8.0 by user decision, spec 2026-08-12; command-invocation only, no census), plus the four maintenance one-timers (`migrate-paths`, `install-deps`, `update-plugin`, `memory`) — exactly 8 files, nothing else.
```

Sentence 2 (§Authoring standards **Commands** paragraph — currently "three public verbs + four maintenance one-timers, and NOTHING else"). Replace that clause with:

```
four public verbs + four maintenance one-timers, and NOTHING else (the 5.x aliases were removed at 6.0.0 after telemetry review; `/mega-sdd:slice` was ADDED 6.8.0 as a deliberate on-record surface expansion — verb ADDITION sits outside the demotion ladder, which governs alias/removal only).
```

- [ ] **Step 3: Amend `tests/surface/test-p6-front-door.sh`**

Three edits:
1. §C header echo `"── C: 6.0.0 alias cull — zero aliases, kept-7 exact, relocations intact ──"` → `kept-8 exact`.
2. §C2:

```bash
# C2: the kept-8 enumerate exactly (slice.md ADDED 6.8.0 — deliberate on-record
# surface growth, spec 2026-08-12-playwright-embed-design.md; never re-shrink
# this count without its own recorded decision)
n_cmd=$(ls "$C"/*.md | wc -l | tr -d ' ')
[ "$n_cmd" -eq 8 ] && ok "exactly 8 command files (4 verbs + 4 one-timers)" || fail "command count wrong: $n_cmd (expected 8)"
for f in mega-sdd.md sync.md emit.md slice.md install-deps.md memory.md migrate-paths.md update-plugin.md; do
  [ -f "$C/$f" ] || fail "kept command MISSING: $f"
done
```

3. §D first-class loop: `for f in memory install-deps migrate-paths update-plugin sync; do` → add `slice`: `for f in memory install-deps migrate-paths update-plugin sync slice; do`.

- [ ] **Step 4: Amend `plugins/mega-sdd/commands/mega-sdd.md` blockquote (line 6)**

`> **The command surface** — three public verbs: …` → replace the verb list portion:

```
> **The command surface** — four public verbs: `/mega-sdd` (this front door), `/mega-sdd:sync` (reconcile with moved code), `/mega-sdd:emit <prd|fsd|sit|uat>` (the four team documents), `/mega-sdd:slice` (standalone UI slicing from a design reference — command-only, never auto-routed).
```

Keep the rest of the blockquote sentence ("Everything else is either auto-invoked…") unchanged.

- [ ] **Step 5: Update both READMEs**

Run `grep -n "3 verbs\|three public verbs\|exactly 7\|7 command\|3 public verbs" README.md plugins/mega-sdd/README.md` and update EVERY hit (mermaid node labels, legend lines, the repo-tree comment "exactly 7: 3 public verbs + 4 maintenance one-timers" → "exactly 8: 4 public verbs + 4 maintenance one-timers", adding `/mega-sdd:slice` where the verbs are enumerated).

- [ ] **Step 6: Run the surface tests**

Run: `bash tests/surface/test-p6-front-door.sh </dev/null` — Expected: PASS (8 files, roster includes slice.md, D-loop passes, phantom sweep clean — `slice` is not in `DEAD_RX`).
Run: `bash tests/playwright-embed/test-playwright-embed-contracts.sh </dev/null` — Expected: PASS.

- [ ] **Step 7: Commit (the on-record single commit)**

```bash
git add plugins/mega-sdd/commands/slice.md plugins/mega-sdd/CLAUDE.md tests/surface/test-p6-front-door.sh plugins/mega-sdd/commands/mega-sdd.md README.md plugins/mega-sdd/README.md
git commit -m "feat(surface): /mega-sdd:slice — 4th public verb (deliberate on-record growth, spec 2026-08-12; pins amended same-commit)"
```

---

### Task 4: using-mega-sdd body bullet + the anchor-budget guard

**Files:**
- Modify: `plugins/mega-sdd/skills/using-mega-sdd/SKILL.md` (one bullet BELOW the ANCHOR-CORE marker; version bump)
- Modify: `tests/playwright-embed/test-playwright-embed-contracts.sh` (append section C)

**Interfaces:**
- Consumes: the `ANCHOR-CORE ends` marker (line ~35) + the session-start awk extraction (hooks/session-start:159-163).
- Produces: the anchor-core byte BASELINE constant used by the guard arm.

- [ ] **Step 1: Append failing section-C arms**

The baseline constant: measure it FIRST on the UNMODIFIED file with the exact session-start awk, record the number, then write the arms:

```bash
awk 'BEGIN{dash=0;body=0}
  /^---[[:space:]]*$/{dash++; if(dash==2)body=1; next}
  body==0{next}
  /ANCHOR-CORE ends/{exit}
  {print}' plugins/mega-sdd/skills/using-mega-sdd/SKILL.md | wc -c
```

Append to the contract test (replace `<BASELINE>` with the measured number):

```bash
echo "── C: anchor-core budget guard (D1 containment) ──"
UMS="$P/skills/using-mega-sdd/SKILL.md"
CORE=$(awk 'BEGIN{dash=0;body=0}
  /^---[[:space:]]*$/{dash++; if(dash==2)body=1; next}
  body==0{next}
  /ANCHOR-CORE ends/{exit}
  {print}' "$UMS")
# C1: the anchor core does NOT grow for /slice — byte baseline captured at 6.8.0
# with the SAME awk hooks/session-start uses for the full-core injection.
# Re-baseline ONLY with a recorded decision (this is the census-budget moat).
n=$(printf '%s' "$CORE" | wc -c | tr -d ' ')
[ "$n" -eq <BASELINE> ] && ok "C1 anchor-core byte length unchanged ($n)" || fail "C1 anchor core changed: $n bytes (baseline <BASELINE>)"
# C2: no slice mention above the marker
printf '%s' "$CORE" | grep -qi "slice" && fail "C2 'slice' leaked into the anchor core" || ok "C2 anchor core slice-free"
# C3: the body mention exists (below the marker)
grep -qF "/mega-sdd:slice" "$UMS" && ok "C3 body mentions /mega-sdd:slice" || fail "C3 body mention missing"
```

- [ ] **Step 2: Run to verify C3 fails (C1/C2 pass on the untouched file)**

Run: `bash tests/playwright-embed/test-playwright-embed-contracts.sh </dev/null`
Expected: C1 ok, C2 ok, C3 FAIL.

- [ ] **Step 3: Add the body bullet**

In `plugins/mega-sdd/skills/using-mega-sdd/SKILL.md`, in the "Side lanes" paragraph region of `## The pipeline` (BELOW the ANCHOR-CORE marker — the delta-bullet precedent), append one line after the "Diagnostic & output lanes" paragraph:

```markdown
Standalone slicing lane (command-only): `/mega-sdd:slice` — implement UI from a design reference (Figma export / URL / image) with a Playwright-MCP render check; never auto-routed from free text, never writes the vault (spec 2026-08-12).
```

Bump the skill's frontmatter `version:` by a patch (e.g. `3.3.2` → `3.3.3` — read the current value first).

- [ ] **Step 4: Run the tests**

Run: `bash tests/playwright-embed/test-playwright-embed-contracts.sh </dev/null` — Expected: all C arms PASS (bullet is below the marker so C1's byte count is unchanged).
Also: `bash tests/surface/test-p6-front-door.sh </dev/null` — PASS (census/description pins untouched).

- [ ] **Step 5: Commit**

```bash
git add plugins/mega-sdd/skills/using-mega-sdd/SKILL.md tests/playwright-embed/test-playwright-embed-contracts.sh
git commit -m "docs(anchor): /slice body-only mention + anchor-core byte-baseline guard (containment moat)"
```

---

### Task 5: install-deps detect-and-offer (Chrome notes-line precedent, NO matrix row)

**Files:**
- Modify: `plugins/mega-sdd/skills/install-deps/SKILL.md` (new subsection; version 1.8.1 → 1.9.0)
- Modify: `tests/playwright-embed/test-playwright-embed-contracts.sh` (append section D)

**Interfaces:**
- Consumes: the Chrome detect-only precedent (tool-matrix.yaml mmdc `notes:` line).
- Produces: the offer wording other docs reference.

- [ ] **Step 1: Append failing section-D arms**

```bash
echo "── D: install-deps Playwright detect-and-offer (D0) ──"
ID="$P/skills/install-deps/SKILL.md"
has "$ID" "npx playwright install chromium" && ok "D1 offer command present" || fail "D1 offer command missing"
has "$ID" "never auto-run" && ok "D2 offer-only wording present" || fail "D2 offer-only wording missing"
has "$ID" "ms-playwright" && ok "D3 cache-path probe documented" || fail "D3 browser cache probe missing"
# D4: NO tool-matrix row for playwright — the Chrome notes-line precedent holds
grep -qE '^  - id: *playwright' "$P/skills/install-deps/references/tool-matrix.yaml" \
  && fail "D4 a playwright tool-matrix row appeared (spec forbids it — ==10 pins + verify_cmd registry-fetch hazard)" \
  || ok "D4 no playwright tool-matrix row"
```

- [ ] **Step 2: Run to verify D1–D3 fail** (`bash tests/playwright-embed/test-playwright-embed-contracts.sh </dev/null`)

- [ ] **Step 3: Add the subsection to `install-deps/SKILL.md`**

After the Pre-flight checks section (or the nearest natural seam — read the file), add:

```markdown
## Playwright browser (detect-and-offer — deliberately NO tool-matrix row)

The plugin bundles the Playwright MCP server (`plugins/mega-sdd/.mcp.json`, pinned); the ~130MB Chromium binary is NOT bundled and is never auto-installed. This lane follows the Chrome detect-only precedent (a matrix row would need an exec `verify_cmd`, and `npx playwright --version` auto-fetches from the npm registry when absent — the unbounded-network-probe class; spec 2026-08-12):

1. **Detect** (filesystem-only, offline, bounded): the browser cache dir exists and is non-empty —
   - macOS: `~/Library/Caches/ms-playwright/`
   - Linux: `~/.cache/ms-playwright/`
   - Windows: `%USERPROFILE%\AppData\Local\ms-playwright\`
2. **Offer** (never auto-run): print `npx playwright install chromium` with the size estimate (~130MB) and let the human run it — on gov/office networks the download may be blocked; absence is ALWAYS graceful (every Playwright consumer SKIPs with a reason; nothing gates).
3. Record the outcome in the install memory like any other tool (detected / offered / declined) — never "installed" without the cache dir appearing.

The MCP server itself can also fail to start (npx cold-cache package fetch on a blocked registry) — that is a DISTINCT rung; the mitigation is the `/mcp` per-server disable, documented in the README.
```

Bump frontmatter `version: 1.8.1` → `1.9.0`.

- [ ] **Step 4: Run the tests** (`bash tests/playwright-embed/test-playwright-embed-contracts.sh </dev/null` — all sections PASS). Also run `bash tests/derived-artifacts/test-tool-matrix.sh </dev/null` — PASS (matrix untouched).

- [ ] **Step 5: Commit**

```bash
git add plugins/mega-sdd/skills/install-deps/SKILL.md tests/playwright-embed/test-playwright-embed-contracts.sh
git commit -m "feat(install-deps): Playwright browser detect-and-offer 1.9.0 — Chrome notes-line precedent, no matrix row"
```

---

### Task 6: trigger fixture `tests/skill-triggering/slice.test.md`

**Files:**
- Create: `tests/skill-triggering/slice.test.md`

**Interfaces:** none (manual-run fixture, the diff-vault.test.md format).

- [ ] **Step 1: Create the fixture**

```markdown
# slice Trigger + Containment Test

Manual-run fixture for the `/mega-sdd:slice` → `slice-design` lane.

## Trigger cases

### SL1: Explicit command with a URL reference
- **Prompt:** `/mega-sdd:slice --url=https://example.com/pricing`
- **Expect:** `slice-design` skill invocation; announce carries `mega-sdd-trace:slice-design`; capture via Playwright MCP; report at `.mega-sdd/slices/<slug>/slice-report.md`

### SL2: Explicit command with an image
- **Prompt:** `/mega-sdd:slice --image=./design/dashboard.png`
- **Expect:** skill invocation; image read directly; ≤3 clarifying questions with keterangan

### SL3: Explicit command, no reference argument
- **Prompt:** `/mega-sdd:slice`
- **Expect:** skill invocation; ONE ask for a reference (figma export / URL / image) with keterangan — then proceeds

## Containment cases (MUST NOT auto-route)

### SL4: Free-text slicing request (Indonesian)
- **Prompt:** `tolong slicing figma ini jadi komponen React`
- **Expect:** NO automatic slice-design invocation — the census carries no slicing keywords; normal assistant behavior (it MAY mention `/mega-sdd:slice` as an offer, never silently invoke)

### SL5: Free-text slicing request (English)
- **Prompt:** `please slice this design into components`
- **Expect:** NO automatic slice-design invocation (same rule as SL4)

### SL6: Vault-bearing project — slice never touches vault state
- **Setup:** project with a BOUND vault
- **Prompt:** `/mega-sdd:slice --image=./ref.png`
- **Expect:** skill invocation; vault `design_system` MAY be read as enrichment; NOTHING under `<vault>/` is written; no bind/units/bolts state changes

### SL7: No dev server running
- **Setup:** `preview_url` unset or unreachable
- **Prompt:** `/mega-sdd:slice --image=./ref.png`
- **Expect:** code generated; compare rounds = 0; report literally states the render was NOT verified; the skill does NOT start any server
```

- [ ] **Step 2: Verify the fixture is discovered like its siblings**

Run: `ls tests/skill-triggering/*.test.md | grep slice` — Expected: the file lists.

- [ ] **Step 3: Commit**

```bash
git add tests/skill-triggering/slice.test.md
git commit -m "test(slice): trigger + containment fixture (SL1-SL7)"
```

---

### Task 7: README notes + CHANGELOG + manifest bumps to 6.8.0

**Files:**
- Modify: `plugins/mega-sdd/README.md` + `README.md` (bundled-MCP note; the count edits happened in Task 3)
- Modify: `CHANGELOG.md`
- Modify: `plugins/mega-sdd/.claude-plugin/plugin.json` (6.7.1 → 6.8.0)
- Modify: `.claude-plugin/marketplace.json` (6.7.1 → 6.8.0 — MUST match plugin.json)

**Interfaces:** none downstream.

- [ ] **Step 1: README note (both files, near the install/requirements section)**

```markdown
> **Bundled MCP (6.8.0):** installing mega-sdd auto-registers the Playwright MCP server (`@playwright/mcp`, pinned, headless + isolated). First browser use offers `npx playwright install chromium` (~130MB — via `/mega-sdd:install-deps`, never auto-run). Disable anytime per-server via `/mcp` without uninstalling the plugin. A browser is never load-bearing: every consumer degrades gracefully without it.
```

- [ ] **Step 2: CHANGELOG entry**

```markdown
## [6.8.0] - 2026-08-12

Playwright embed P1 (spec `docs/superpowers/specs/2026-08-12-playwright-embed-design.md`, D0+D1):

- **D0 — bundled Playwright MCP**: NEW `plugins/mega-sdd/.mcp.json` auto-registers `@playwright/mcp@0.0.79` (pinned exact; `--headless --isolated`) on plugin enable. Pin joins the CLAUDE.md §Versioning release checklist. install-deps 1.9.0 gains the browser detect-and-offer (Chrome notes-line precedent — deliberately NO tool-matrix row).
- **D1 — `/mega-sdd:slice`**: 4th public verb (deliberate on-record surface growth; user decision). NEW `skills/slice-design` 1.0.0 — design reference (Figma export / URL / image) → UI code per framework pack + design-intelligence corpus → Playwright-MCP render-compare (cap 3) → honest `slice-report.md` under `.mega-sdd/slices/`. Containment: command-invocation only, zero census keywords, anchor-core byte-baseline guard; never writes vault/binding; never starts a dev server.
- Surface pins amended same-commit: test-p6 §C2 7→8 + roster, CLAUDE.md ×2, mega-sdd.md blockquote, READMEs.
- NEW `tests/playwright-embed/test-playwright-embed-contracts.sh` (A–D sections) + `tests/skill-triggering/slice.test.md` (SL1–SL7).
```

- [ ] **Step 3: Bump both manifests** — edit `"version"` in `plugins/mega-sdd/.claude-plugin/plugin.json` and the matching field in `.claude-plugin/marketplace.json` to `6.8.0`. Verify: `grep -h '"version"' plugins/mega-sdd/.claude-plugin/plugin.json .claude-plugin/marketplace.json` → both `6.8.0`.

- [ ] **Step 4: Commit**

```bash
git add README.md plugins/mega-sdd/README.md CHANGELOG.md plugins/mega-sdd/.claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "release: v6.8.0 — Playwright embed P1 (bundled MCP + /slice)"
```

---

### Task 8: cadence close-out — blind round, both-tree suite, ship

**Files:** (folds may touch any Task 1–7 file; the spec gets the SHIPPED stamp last)

- [ ] **Step 1: Blind adversarial round** — dispatch read-only blind reviewer(s) (mktemp scratch, no session context) against the diff of Tasks 1–7 with the spec as the contract; grade findings BLOCKER/MAJOR/minor.
- [ ] **Step 2: Fold ALL findings** (spec-first for any behavior change; re-run the touched tests per fold).
- [ ] **Step 3: Full suite, BOTH trees, background** — run the scratchpad `run-suite.sh` (top-level `tests/` + `plugins/mega-sdd/tests/`) `</dev/null`; expected: 0 fail, count grows from 220 by the new suites.
- [ ] **Step 4: Push + CI watch** — `rtk proxy git push https://github.com/FarhanRiuzaki/Mega-SDD.git main`; poll `gh run list --repo FarhanRiuzaki/Mega-SDD` until the head-sha run concludes; expected `success` (remember: CI runs BOTH trees).
- [ ] **Step 5: Stamp the spec** — spec §Status gains `P1 SHIPPED v6.8.0 (<sha>, CI green, suite <n>)`; commit + push the stamp.
- [ ] **Step 6: User-action ship-gate items (hand off, do NOT fake):** registration smoke check (`/mcp` shows `playwright` after the user's plugin update) + the office-machine verification (npx cold/warm cache under Git Bash) — both PENDING USER per the spec's §Shared degradation rung 2; record them in the wrap-up message.

---

## Self-review (done at authoring)

- **Spec coverage:** D0 → Tasks 1, 5, 7 (pin+shape ✓, checklist hook ✓, detect-and-offer ✓, README/`/mcp` docs ✓, smoke check → Task 8 step 6). D1 → Tasks 2, 3, 4, 6 (command+skill ✓, surface amendments same-commit ✓, containment pins ✓, anchor guard with DEFINED method ✓, trigger fixture ✓, dev-server ownership ✓, report location ✓). Degradation doctrine → Task 5 subsection + slice SKILL §Degradation. P1 proof tests from the spec all present (shape pin A, detect-offer doc pin D, p6 §C2 same-commit, trigger fixture, census-free B2, no-vault-write B3a, cap-3 B3c, honest-skip B3d, never-starts-server B3b, report-location B3e, anchor baseline C1).
- **Placeholder scan:** one deliberate token — `<BASELINE>` in Task 4, which MUST be measured from the real file at execution (the plan states the exact command); everything else is literal content.
- **Type consistency:** skill name `slice-design` used identically in Tasks 2, 3, 6; report path `.mega-sdd/slices/<slug>/slice-report.md` identical in Tasks 2, 3, 6; pin string `@playwright/mcp@0.0.79` identical in Tasks 1, 7.
