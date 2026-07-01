// mermaid_parse_oracle.mjs — headless ground-truth for "does this mermaid render?"
//
// Runs mermaid.parse() (grammar validation, NO browser/Chromium needed) on ONE
// mermaid diagram and classifies the result. The bundled min build pulls a DOM
// (DOMPurify) dependency that throws AFTER grammar validation on VALID input, so
// a clean grammar with a DOM-only error is reported OK; only a genuine grammar
// failure is reported as an error. This is the opt-in ground-truth layer behind
// verify-mermaid.sh — it catches render-breakers the zero-dep heuristic cannot
// (reserved-word `end` nodes, unterminated shapes, bad transition labels, ...).
//
// Usage: node mermaid_parse_oracle.mjs <mermaid-core.mjs> <diagram-file.mmd>
// Output (stdout): "OK" | "GRAMMAR_ERROR: <first line>"
// Exit: 0 = grammar OK (renderable), 1 = grammar error, 2 = oracle unavailable
import { readFileSync } from "node:fs";

// INVERTED classifier. mermaid.parse() throws for BOTH real grammar errors AND
// (headless) a benign DOM/sanitizer dependency that runs AFTER the grammar has
// already validated. An allow-list of grammar markers is version-fragile — a new
// mermaid release or a Langium/Chevrotain "Lexer error" would slip through as a
// false PASS (certifying a broken diagram). So we INVERT: every throw is a
// GRAMMAR_ERROR unless the message matches this benign-DOM deny-list. Ground-
// truthed: every valid diagram type throws only the DOMPurify "addHook" signature
// in Node. Bias is deliberately toward false-FAIL (safe) over false-PASS (lying).
const BENIGN_DOM = /addHook|DOMPurify|\b(document|window|navigator|self|globalThis|getComputedStyle|HTMLElement|SVGElement|localStorage|requestAnimationFrame)\b/i;

const corePath = process.argv[2];
const diagramFile = process.argv[3];

let mermaid;
try {
  mermaid = (await import(corePath)).default;
} catch (e) {
  console.log("ORACLE_UNAVAILABLE: " + (e && e.message ? e.message : String(e)).split("\n")[0]);
  process.exit(2);
}
// A resolved-but-unusable core (wrong package, no default export, .parse missing)
// must NOT silently mass-pass every diagram. Degrade to SKIP (exit 2), not OK.
if (!mermaid || typeof mermaid.parse !== "function") {
  console.log("ORACLE_UNAVAILABLE: resolved core exposes no parse()");
  process.exit(2);
}

let src;
try {
  src = readFileSync(diagramFile, "utf8");
} catch (e) {
  console.log("ORACLE_UNAVAILABLE: cannot read diagram file");
  process.exit(2);
}

try {
  await mermaid.parse(src);
  console.log("OK");
  process.exit(0);
} catch (e) {
  const msg = e && e.message ? e.message : String(e);
  const first = msg.split("\n")[0];
  if (BENIGN_DOM.test(msg)) {
    // grammar validated; the throw is only the headless DOM/sanitizer dependency
    console.log("OK");
    process.exit(0);
  }
  console.log("GRAMMAR_ERROR: " + first);
  process.exit(1);
}
