#!/usr/bin/env bash
# capture-views.sh — screenshot a running UI for the design-reviewer's ceiling
# judgment (the live-app lens — ECC Batch 3, scoped to the floor-vs-ceiling gap).
#
# The design lens proves the FLOOR from code but the CEILING (polish, hierarchy,
# distinctiveness) needs the render. When a dev server is up and a headless
# browser is available, this captures the declared routes at desktop + mobile
# widths into the bolt dir; the design lens Reads them. EVERY failure mode
# (no server, no browser, bad route) is a graceful SKIP with a reason — a render
# we couldn't take is never reported as "looks fine".
#
# STACK-AGNOSTIC: capture only hits HTTP URLs, so the app can be ANY stack —
# Laravel/Blade, Django, Rails, Spring, a Node/Next SPA, anything that serves a
# page. The screenshot DRIVER degrades across ecosystems: a system Chrome/Chromium
# (no Node — works for PHP/Python/Ruby/Go repos) is tried first, then npx
# playwright (common in JS repos). Routes come from the unit, never from a stack
# assumption.
#
# Usage:
#   capture-views.sh --url=<base> --routes=/a,/b --out=<dir> [--widths=1280,390]
# Exit: 0 always (capture is best-effort; absence never blocks a bolt).

set -uo pipefail
URL=""; ROUTES=""; OUT=""; WIDTHS="1280,390"
for arg in "$@"; do
  case "$arg" in
    --url=*) URL="${arg#--url=}" ;;
    --routes=*) ROUTES="${arg#--routes=}" ;;
    --out=*) OUT="${arg#--out=}" ;;
    --widths=*) WIDTHS="${arg#--widths=}" ;;
  esac
done
[ -n "$URL" ] && [ -n "$ROUTES" ] && [ -n "$OUT" ] || {
  echo '{"skipped":true,"reason":"usage: --url= --routes= --out= required"}'; exit 0; }

# Is the server actually up? (curl/wget, else skip — never hang a bolt.)
probe() {
  if command -v curl >/dev/null 2>&1; then curl -fsS -o /dev/null --max-time 5 "$1" 2>/dev/null; return $?; fi
  if command -v wget >/dev/null 2>&1; then wget -q -O /dev/null --timeout=5 "$1" 2>/dev/null; return $?; fi
  return 2
}
if ! probe "$URL"; then
  echo "{\"skipped\":true,\"reason\":\"dev server not reachable at $URL — start it, then re-run the design lens\"}"
  exit 0
fi

mkdir -p "$OUT" 2>/dev/null || { echo '{"skipped":true,"reason":"cannot create output dir"}'; exit 0; }

# ─── STACK-AGNOSTIC driver selection ─────────────────────────────────────────
# The app under test can be ANY stack (Laravel/Blade, Django, Rails, Spring,
# a Node SPA …) — capture only hits HTTP URLs, so the stack is irrelevant.
# What varies is the local SCREENSHOT DRIVER. Try, in order:
#   1) a system Chrome/Chromium headless  — zero Node, works for PHP/Python/Ruby/Go repos
#   2) npx playwright                       — common in JS repos; multi-width, full-page
# We INSTALL nothing; if neither is present, graceful skip → design lens goes code-only.
CHROME_BIN=""
for c in google-chrome google-chrome-stable chromium chromium-browser chrome \
         "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
         "/Applications/Chromium.app/Contents/MacOS/Chromium"; do
  if command -v "$c" >/dev/null 2>&1; then CHROME_BIN="$c"; break; fi
  if [ -x "$c" ]; then CHROME_BIN="$c"; break; fi
done

if [ -n "$CHROME_BIN" ]; then
  # System-Chrome path: one screenshot per route at the FIRST width (chrome
  # headless --screenshot takes a single --window-size). Stack-agnostic, no Node.
  W1="${WIDTHS%%,*}"; [ -n "$W1" ] || W1=1280
  H1=$(( W1 * 3 / 4 ))
  shots="["; first=1
  IFS=',' read -r -a _routes <<< "$ROUTES"
  for route in "${_routes[@]}"; do
    route="$(printf '%s' "$route" | tr -d ' ')"
    [ -n "$route" ] || continue
    case "$route" in /) slug=home ;; *) slug="$(printf '%s' "$route" | tr -cs 'A-Za-z0-9' '-' | sed 's/^-//;s/-$//')" ;; esac
    file="${OUT}/${slug}-${W1}.png"
    if "$CHROME_BIN" --headless=new --disable-gpu --hide-scrollbars --no-sandbox \
        --window-size="${W1},${H1}" --screenshot="$file" "${URL%/}${route}" >/dev/null 2>&1 && [ -s "$file" ]; then
      [ "$first" = 1 ] || shots="${shots},"; first=0
      shots="${shots}{\"route\":\"${route}\",\"width\":${W1},\"file\":\"${file}\"}"
    fi
  done
  shots="${shots}]"
  echo "{\"skipped\":false,\"driver\":\"system-chrome\",\"base\":\"${URL%/}\",\"shots\":${shots}}"
  exit 0
fi

if ! command -v npx >/dev/null 2>&1; then
  echo '{"skipped":true,"reason":"no screenshot driver — install a system Chrome/Chromium (any stack) or playwright (npx). Design lens falls back to code-only ceiling judgment."}'
  exit 0
fi

NODE_SCRIPT=$(mktemp); trap 'rm -f "$NODE_SCRIPT"' EXIT
cat > "$NODE_SCRIPT" <<'NODE'
const { chromium } = require('playwright');
(async () => {
  const base = process.env.URL.replace(/\/$/, '');
  const routes = process.env.ROUTES.split(',').map(s => s.trim()).filter(Boolean);
  const widths = process.env.WIDTHS.split(',').map(s => parseInt(s, 10)).filter(Boolean);
  const out = process.env.OUT;
  const shots = [];
  const browser = await chromium.launch();
  for (const route of routes) {
    for (const w of widths) {
      const page = await browser.newPage({ viewport: { width: w, height: Math.round(w * 0.75) } });
      try {
        await page.goto(base + route, { waitUntil: 'networkidle', timeout: 15000 });
        const slug = (route === '/' ? 'home' : route.replace(/[^a-z0-9]+/gi, '-').replace(/^-|-$/g, ''));
        const file = `${out}/${slug}-${w}.png`;
        await page.screenshot({ path: file, fullPage: true });
        shots.push({ route, width: w, file });
      } catch (e) {
        shots.push({ route, width: w, error: String(e).slice(0, 120) });
      } finally {
        await page.close();
      }
    }
  }
  await browser.close();
  console.log(JSON.stringify({ skipped: false, base, shots }, null, 1));
})();
NODE

if ! URL="$URL" ROUTES="$ROUTES" OUT="$OUT" WIDTHS="$WIDTHS" node "$NODE_SCRIPT" 2>/dev/null; then
  echo '{"skipped":true,"reason":"playwright not available (npm i -D playwright + npx playwright install chromium) — design lens falls back to code-only ceiling judgment"}'
fi
exit 0
