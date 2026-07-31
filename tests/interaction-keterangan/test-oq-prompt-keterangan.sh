#!/usr/bin/env bash
# test-oq-prompt-keterangan.sh — the keterangan contract (user-mandated 2026-07-08).
#
# A human-facing OQ/halt prompt the human cannot answer from the prompt alone is
# a defect: every interactive surface must carry the actual question text, source
# context, per-option keterangan (enum codes stay English labels; descriptions
# explain what choosing them DOES), and a single recommended default when one
# exists. Root fix pinned here: the halt displayer renders a plain-language
# keterangan block BEFORE the envelope YAML.
#
# Run: bash tests/interaction-keterangan/test-oq-prompt-keterangan.sh
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
P="$ROOT/plugins/mega-sdd"
FAILED=0
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }
has()  { grep -qF "$2" "$1"; }

echo "== keterangan contract pins =="

# ── the canonical contract (output-language.md) ──
OL="$P/references/output-language.md"
has "$OL" "## Prompt surfaces (AskUserQuestion / halt menus)" && ok "contract section exists in output-language.md" || fail "contract section missing"
has "$OL" "an ID/tag" && has "$OL" "never a question" && ok "contract: ID alone is never a question" || fail "contract: question-text mandate missing"
has "$OL" "MANDATORY Tier-2 description" && ok "contract: per-option keterangan mandatory" || fail "contract: option-description mandate missing"
has "$OL" "exactly ONE option is marked recommended" && ok "contract: single recommended default" || fail "contract: default-uniqueness rule missing"

# ── the root fix: halt displayer step 0 ──
HP="$P/references/halt-protocol.md"
has "$HP" "Keterangan block FIRST" && ok "halt displayer: keterangan block mandated BEFORE the YAML" || fail "halt displayer: step 0 missing"
has "$HP" "quote the OQ question / CONFLICT claim pair / decision at stake verbatim" && ok "halt displayer: tag resolved to actual text" || fail "halt displayer: tag-resolution mandate missing"
has "$HP" "suggested_action_rationale" && ok "bind_conflict schema: rationale field added" || fail "bind_conflict: rationale missing"
grep -qF '{code, keterangan}' "$HP" && ok "diff_conflict options: code+keterangan pairs" || fail "diff_conflict: options still bare strings"

# ── resolve-oq family ──
IW="$P/skills/resolve-oq/references/interactive-walk.md"
has "$IW" "recommended — idempotent per the Atomicity rule" && ok "resume prompt: options glossed + Continue recommended" || fail "resume prompt: keterangan missing"
# single scope default: all-priorities recommended; p1-only must NOT carry 'Recommended'
grep -qF '**`all-priorities`** **(recommended)**' "$IW" && ok "scope prompt: all-priorities is the single recommended default" || fail "scope prompt: default not unified"
if grep -qF 'p1-only`** — only Priority 1 OQs (sprint-0 blockers). Recommended' "$IW"; then fail "scope prompt: p1-only still marked Recommended (contradictory default)"; else ok "scope prompt: p1-only no longer claims the default"; fi
# (the letters became slots when the walk collapsed to ONE prompt — the rail is the same)
has "$IW" "Defer is ALWAYS visible" && ok "action menu: stakeholder Defer reachable in every context (greenfield gap closed)" || fail "action menu: Defer still binding-only/conditional"
has "$IW" "defer_to: stakeholder" && ok "action menu: stakeholder-defer state transition defined" || fail "action menu: stakeholder transition missing"
SK="$P/skills/resolve-oq/SKILL.md"
grep -qF '`Defer` (slot `[3]`) is ALWAYS visible' "$SK" && ok "SKILL.md conditional-display synced" || fail "SKILL.md: old binding-only conditional survives"
BM="$P/skills/resolve-oq/references/binding-mode.md"
has "$BM" "evidence anchor file:line" && ok "CONFLICT menu: evidence anchor mandated" || fail "CONFLICT menu: anchor missing"
has "$BM" "Prior call (suggestion only" && ok "CONFLICT menu: prior-call slot present" || fail "CONFLICT menu: prior-call slot missing"
RC="$P/skills/resolve-oq/references/recommendation-context.md"
has "$RC" "NEVER left blank" && ok "recommend-mode: alternative descriptions mandatory + grounded" || fail "recommend-mode: alternatives still 'description: ...'"

# ── chain surfaces ──
OF="$P/skills/orchestrate-flow/SKILL.md"
has "$OF" "jalankan semua N fase end-to-end" && ok "chain proposal: Run/Edit/Cancel glossed" || fail "chain proposal: options bare"
has "$OF" "CWD signals are ground truth per halt-protocol" && ok "mode_migrate: recommended default + consequences" || fail "mode_migrate: keterangan missing"
CE="$P/skills/orchestrate-flow/references/chain-execution.md"
has "$CE" "never surface counts alone" && ok "drift gate: per-finding keterangan mandated on CRITICAL/HIGH" || fail "drift gate: counts-only surface survives"
has "$CE" "tanpa Plan phase tidak ada review rencana" && ok "MAJOR-without-plan confirm: risk context + glossed options" || fail "plan/act confirm: bare question survives"
SF="$P/skills/generate-intent/references/setup-flow.md"
has "$SF" "Memilih satu scope memfilter PRD" && ok "scope picker: lead line + per-scope summary" || fail "scope picker: gloss missing"
has "$SF" "Options keterangan (rendered by the halt displayer" && ok "scope halts: options glossed" || fail "scope halts: bare codes survive"

# ── other surfaces ──
DV="$P/skills/diff-vault/SKILL.md"
has "$DV" "tanpa commit, tidak ada rollback point" && ok "diff-vault git-safety: situation + consequence + default" || fail "diff-vault git-safety: bare options"
has "$P/skills/diff-vault/references/report-format.md" "P1 = blocking" && ok "diff-vault OQ priority: P1/P2 tier gloss" || fail "diff-vault: bare P1/P2 codes"
has "$P/skills/diff-vault/references/diff-procedure.md" "STATES the suggested bump" && ok "diff-vault version bump: rationale + glossed options" || fail "diff-vault bump: shape unmandated"
BT="$P/skills/bind-codebase/references/binding-md-template.md"
SB="$P/scripts/stamp-binding-boilerplate.sh"
has "$BT" "Enum legend (keterangan contract" && ok "binding.md template: enum-legend note (single source named)" || fail "binding template: legend note missing"
# P2b: the 4-code gloss text single-sources in the stamp script (stamped into every emitted binding.md)
has "$SB" "Enum legend (keterangan contract" && ok "stamp script: legend blockquote carried (stamped post-write)" || fail "stamp script: legend blockquote missing"
has "$SB" "the vault is right; code must change to match" && ok "stamp script: KEEP_VAULT gloss" || fail "stamp script: KEEP_VAULT gloss missing"
has "$SB" "the vault is wrong; the vault is updated to match code reality" && ok "stamp script: KEEP_CODE gloss" || fail "stamp script: KEEP_CODE gloss missing"
has "$SB" "downgraded to an OQ; the binding gate OPENS" && ok "stamp script: DEFER gloss (truthful — gate opens)" || fail "stamp script: DEFER gloss missing"
has "$SB" "split into sub-claims, each re-bound separately" && ok "stamp script: SPLIT gloss" || fail "stamp script: SPLIT gloss missing"
has "$BT" "1-line rationale citing the evidence anchor" && ok "binding.md template: Suggested action carries rationale" || fail "binding template: bare suggested action"
TT="$P/skills/generate-units/references/task-typing.md"
has "$TT" "Apa status surplus ini?" && ok "PARTIAL_FIELDS_SURPLUS review: template authored (was unwritten)" || fail "surplus review: template still missing"
has "$TT" "never a default" && ok "surplus review: destructive branch never defaulted" || fail "surplus review: deletion-default guard missing"
LR="$P/skills/memory/references/learning-rules.md"
has "$LR" "berlaku mulai run berikutnya" && ok "memory review: ACCEPT/REJECT/DEFER consequences" || fail "memory review: bare enum options"
EI="$P/skills/extract-intelligence/SKILL.md"
has "$EI" "Lanjut wave N+1" && ok "extract per-wave confirm: shape defined" || fail "extract: per-wave confirm undefined"
has "$EI" "Re-scope" && has "$EI" "KB partial disimpan" && ok "extract twice-failed gate: glossed menu" || fail "extract: gate menu undefined"

# ── review-round fixes (2 reviewers, 17 findings) ──
# no fabricated UX: keterangan must state mechanics the plugin actually implements
has "$OL" "fabricated UX" && ok "contract: fabricated-UX clause (keterangan must match real mechanics)" || fail "contract: fabricated-UX clause missing"
has "$IW" "the QUEUE is identical" && ok "resume prompt: Start-fresh gloss truthful (no invented skip-tracking)" || fail "resume prompt: fabricated gloss survives"
has "$BM" "gate binding TERBUKA" && ok "DEFER gloss truthful (gate opens; units carry the OQ) — binding-mode" || fail "DEFER gloss: 'terblokir' fabrication survives in binding-mode"
if grep -qF 'tetap terblokir' "$BM" "$HP" "$BT" "$OL" "$SB" 2>/dev/null; then fail "DEFER 'terblokir' fabrication survives somewhere"; else ok "DEFER 'terblokir' fabrication purged from all 5 surfaces (incl. stamp script)"; fi
has "$TT" "BUKAN oleh generate-units" && ok "surplus review: vault updates routed to resolve-oq/diff-vault (no invented vault write)" || fail "surplus review: vault-mutation claim survives"
has "$EI" "tidak ada auto-resume" && ok "extract Abort gloss truthful (no invented _meta/resume)" || fail "extract: _meta fabrication survives"
# coverage misses closed
has "$P/skills/resolve-oq/references/auto-memory-handoff.md" "DELIBERATE chain-context divergence" && ok "--auto scope default: p1-only divergence annotated with rationale" || fail "--auto default: unannotated contradiction survives"
has "$P/skills/execute-bolts/references/halts-and-handoff.md" "render the keterangan block per" && ok "standalone execute-bolts halts mirror displayer step 0" || fail "execute-bolts: standalone halts still bare YAML"
has "$HP" "ANY halt-displaying surface" && ok "displayer step 0 scoped to every halt surface, not just the orchestrator" || fail "displayer: orchestrate-flow-only scope survives"
EA="$P/skills/emit-agents-md/SKILL.md"
has "$EA" "safe default per the Hard rails" && has "$EA" "DESTRUKTIF" && ok "emit-agents-md: overwrite|append|sibling glossed (sibling recommended, overwrite flagged destructive)" || fail "emit-agents-md: bare 3-code menu survives"
has "$SF" "skip retrofit\` — lanjut sebagai single-scope" && ok "retrofit review menu glossed + canonical code names" || fail "retrofit review: bare code list survives"
has "$P/skills/generate-intent/references/legacy-retrofit-prompt.md" "glossed per \`setup-flow.md\` Step 0.9c" && ok "legacy-retrofit-prompt mirrors the glossed menu" || fail "retrofit mirror: unaligned"
has "$P/skills/execute-bolts/references/bolt-contract.md" "quote the OQ question text from the vault roll-up" && ok "bolt-time TBD:OQ prompt template authored (was undefined)" || fail "bolt-contract: TBD prompt still undefined"
has "$P/skills/diff-vault/references/auto-and-chain.md" "{code: supersede" && ok "diff_conflict producer emits {code, keterangan} pairs (schema parity)" || fail "diff_conflict producer: bare strings survive"
has "$P/skills/diff-vault/references/report-format.md" "oq_business_p1_unresolved" && ok "P1 gloss cites the canonical halt type" || fail "P1 gloss: nonexistent halt type survives"
has "$SK" "nested deferral not supported" && ok "[B] ALWAYS-visible carve-out for the --binding propagated walk" || fail "[B]: absolute claim contradicts binding-mode step 3"
has "$LR" "setelah lebih dari 3× defer" && ok "memory DEFER gloss matches step 5 (> 3)" || fail "memory: off-by-one defer gloss survives"
has "$BT" "the DISPLAYER" && ok "binding.md legend stays English in the artifact (Tier-3); displayer localizes" || fail "binding template: hardcoded Indonesian in a durable artifact"

if [ "$FAILED" -eq 0 ]; then echo "ALL KETERANGAN PINS OK"; else echo "keterangan pins FAILED"; fi
exit $FAILED
