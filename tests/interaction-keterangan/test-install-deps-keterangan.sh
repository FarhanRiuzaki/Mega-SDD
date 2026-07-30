#!/usr/bin/env bash
# test-install-deps-keterangan.sh — install-deps Step 4 keterangan contract (F1-5).
#
# The Step-4 batch-confirm AskUserQuestion previously rendered bare option
# labels ([Install all] [Pick subset] [Cancel]) with no per-option Indonesian
# keterangan and no recommended default — a violation of the plugin's
# user-mandated keterangan contract (output-language.md §Prompt surfaces).
# Pins the fix: question text restates what's at stake, every option carries
# a truthful consequence, and exactly one option is marked recommended.
#
# Run: bash tests/interaction-keterangan/test-install-deps-keterangan.sh
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
P="$ROOT/plugins/mega-sdd"
FAILED=0
ok()   { printf '  \xe2\x9c\x93 %s\n' "$*"; }
fail() { printf '  \xe2\x9c\x97 FAIL: %s\n' "$*"; FAILED=1; }
has()  { grep -qF "$2" "$1"; }

echo "== install-deps Step 4 keterangan contract pins (F1-5) =="

ID="$P/skills/install-deps/SKILL.md"

has "$ID" 'version: 1.7.0' && ok "SKILL frontmatter version pinned at 1.7.0" || fail "version not bumped"

has "$ID" '§Prompt surfaces' && ok "Step 4 cites the keterangan contract (output-language.md §Prompt surfaces)" || fail "Step 4: contract citation missing"

has "$ID" 'question text restates what' && ok "Step 4: question text carries the tool list + size + pkg_mgr + commands" || fail "Step 4: question text mandate missing"

has "$ID" '**(recommended — jalankan semua `install_cmd`' && ok "Step 4: 'Install all' marked recommended, listed first, with reason" || fail "Step 4: recommended default missing/unmarked"

has "$ID" 'tool yang TIDAK dipilih tetap `missing` dan jalan di `fallback_behavior`-nya' && ok "Step 4: Pick subset keterangan states the fallback_behavior consequence" || fail "Step 4: Pick subset keterangan missing"

has "$ID" 'batal total, tidak ada yang diinstall' && ok "Step 4: Cancel keterangan states the fallback-degradation consequence" || fail "Step 4: Cancel keterangan missing"

# exactly ONE option carries "(recommended" — Pick subset / Cancel must not also claim it
REC_COUNT=$(grep -o '(recommended' "$ID" | wc -l | tr -d ' ')
if [ "$REC_COUNT" = "1" ]; then ok "exactly ONE recommended default in Step 4 (no contradicting defaults)"; else fail "Step 4: expected exactly 1 '(recommended' marker, found $REC_COUNT"; fi

# no bare-label regression: the 3 options must not appear as a bare bracket menu with
# nothing between it and the next section (i.e. the keterangan bullets must exist).
has "$ID" '`Pick subset` — secondary' && ok "Step 4: Pick subset option carries a dash-gloss (not a bare label)" || fail "Step 4: Pick subset still bare"
has "$ID" '`Cancel` — batal total' && ok "Step 4: Cancel option carries a dash-gloss (not a bare label)" || fail "Step 4: Cancel still bare"

if [ "$FAILED" -eq 0 ]; then echo "ALL INSTALL-DEPS KETERANGAN PINS OK"; else echo "install-deps keterangan pins FAILED"; fi
exit $FAILED
