#!/usr/bin/env bash
# validate-pack.sh — author/CI linter for framework-convention packs.
#
# Usage:
#   validate-pack.sh <pack.md>        — validate a single pack file
#   validate-pack.sh --all            — validate all <fw>.md packs in the
#                                       framework-conventions dir
#   validate-pack.sh --registry       — generate _registry.md pack-readiness table
#   validate-pack.sh --check-registry — check if _registry.md is up-to-date (exit 0=fresh, 1=stale)
#
# Exit: 0 = PASS, 1 = one or more violations, 2 = usage error
#
# NEVER called as a runtime hook — author/CI gate only.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONV_DIR="$(cd "$SCRIPT_DIR/../references/framework-conventions" && pwd)"
LINT_MD="$CONV_DIR/_lint.md"

# --------------------------------------------------------------------------
# Arg parse
# --------------------------------------------------------------------------
MODE="single"
SINGLE_FILE=""

if [ $# -eq 0 ]; then
  echo "usage: validate-pack.sh <pack.md> | --all" >&2
  exit 2
fi

case "$1" in
  --all)
    MODE="all"
    ;;
  --registry)
    MODE="registry"
    ;;
  --check-registry)
    MODE="check-registry"
    ;;
  --*)
    echo "NOTE: unknown flag '$1' — usage: validate-pack.sh <pack.md> | --all | --registry | --check-registry" >&2
    exit 2
    ;;
  *)
    MODE="single"
    SINGLE_FILE="$1"
    ;;
esac

# --------------------------------------------------------------------------
# YAML block validator
# --------------------------------------------------------------------------
# Try python3 yaml; fall back to structural check if module unavailable.
_yaml_valid() {
  local block="$1"
  # Try python3 with PyYAML
  if python3 -c "import sys,yaml" 2>/dev/null; then
    printf '%s\n' "$block" | python3 -c "import sys,yaml; yaml.safe_load(sys.stdin.read())" 2>/dev/null
    return $?
  fi
  # Fall back to /opt/homebrew/bin/python3.11 if available
  if [ -x /opt/homebrew/bin/python3.11 ]; then
    printf '%s\n' "$block" | /opt/homebrew/bin/python3.11 -c "import sys,yaml; yaml.safe_load(sys.stdin.read())" 2>/dev/null
    return $?
  fi
  # Structural fallback: check for unclosed brackets and obviously broken YAML
  # Count open vs close brackets/braces
  local open_sq close_sq open_cu close_cu
  open_sq=$(printf '%s\n' "$block" | grep -o '\[' | wc -l | tr -d ' ')
  close_sq=$(printf '%s\n' "$block" | grep -o '\]' | wc -l | tr -d ' ')
  open_cu=$(printf '%s\n' "$block" | grep -o '{' | wc -l | tr -d ' ')
  close_cu=$(printf '%s\n' "$block" | grep -o '}' | wc -l | tr -d ' ')
  if [ "$open_sq" != "$close_sq" ] || [ "$open_cu" != "$close_cu" ]; then
    return 1
  fi
  return 0
}

_yaml_available() {
  python3 -c "import yaml" 2>/dev/null && return 0
  [ -x /opt/homebrew/bin/python3.11 ] && /opt/homebrew/bin/python3.11 -c "import yaml" 2>/dev/null && return 0
  return 1
}

# --------------------------------------------------------------------------
# Token map reader — parses ## Cross-framework token map from _lint.md
# --------------------------------------------------------------------------
# Outputs: one line per framework: "framework token1 token2 ..."
_read_token_map() {
  if [ ! -f "$LINT_MD" ]; then
    echo "NOTE: _lint.md not found at $LINT_MD — skipping cross-framework leak check" >&2
    return 1
  fi
  # Extract lines between the opening ``` and closing ``` of the token-map fenced block
  awk '/^## Cross-framework token map/{found=1} found && /^```$/{if(in_block){in_block=0; found=0} else {in_block=1}} in_block && !/^```/{print}' "$LINT_MD"
}

# --------------------------------------------------------------------------
# Core validator for a single pack file
# --------------------------------------------------------------------------
_validate_pack() {
  local pack_file="$1"
  local violations=0
  local notes=""

  if [ ! -f "$pack_file" ]; then
    echo "VIOLATION: file not found: $pack_file"
    return 1
  fi

  local content
  content=$(cat "$pack_file")

  # ---- Extract frontmatter -----------------------------------------------
  local frontmatter
  frontmatter=$(awk '/^---/{n++; if(n==1){next} if(n==2){exit}} n==1{print}' "$pack_file")

  if [ -z "$frontmatter" ]; then
    echo "VIOLATION: missing YAML frontmatter (no --- delimiters found)"
    violations=$((violations + 1))
  fi

  # ---- Check 1: required frontmatter keys --------------------------------
  local fm_key fm_ok
  for fm_key in "framework:" "detection_signature:" "package_manifest:" "dependency_marker:" "framework_version_range:"; do
    if ! printf '%s\n' "$frontmatter" | grep -q "$fm_key"; then
      echo "VIOLATION: frontmatter missing required key: $fm_key"
      violations=$((violations + 1))
    fi
  done

  # ---- Extract pack's own framework value --------------------------------
  local pack_framework
  pack_framework=$(printf '%s\n' "$frontmatter" | grep -m1 '^framework:' | sed 's/framework:[[:space:]]*//' | tr -d '"'"'" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')

  # ---- Check 2: required-always sections ---------------------------------
  local req_section
  for req_section in \
    "## File location standards" \
    "## Naming standards" \
    "## Idioms" \
    "## Hard Rules emitted" \
    "## Testing conventions"; do
    if ! printf '%s\n' "$content" | grep -qF "$req_section"; then
      echo "VIOLATION: missing section — $req_section"
      violations=$((violations + 1))
    fi
  done

  # ---- Check 3: conditional sections (heading MUST be present) -----------
  local cond_section
  for cond_section in \
    "## Deep-scan file hints" \
    "## Authz mapping" \
    "## UI detection" \
    "## Reuse discovery"; do
    if ! printf '%s\n' "$content" | grep -qF "$cond_section"; then
      echo "VIOLATION: missing section — $cond_section (add heading + content, or opt-out with _(N/A: ...)_)"
      violations=$((violations + 1))
    fi
  done

  # ---- Check 3b (S5 GU-PACKLINT-GATES): gate-driving header typo lint -----
  # flow-coverage / sibling-consistency / unit-spec / fanout-parity resolve pack
  # sections by EXACT prefix match; a typo'd gate header silently falls back to
  # _universal's principle-only prose and downgrades a BLOCKING gate to SKIP with
  # no diagnostic. Any `## ` header in the pack that is not in the recognized set
  # but is a near-miss of a gate-driving header is a violation.
  local _known_headers="File location standards|Naming standards|Idioms|Hard Rules emitted|Testing conventions|Deep-scan file hints|Authz mapping|UI detection|Reuse discovery|Flow-artifact derivation|Conditional scaffold artifacts|Cross-cutting concerns|Relation derivation|UI quality signatures|Entity source globs|Entity matching tokens|Test patterns|Contents"
  local _gate_stems="Flow.artifact|Cross.cutting|Relation deriv|UI quality|Entity source|Entity match|Test pattern|Scaffold|Deep.scan|Authz|Reuse"
  local _hdr _hname
  while IFS= read -r _hdr; do
    _hname=$(printf '%s' "$_hdr" | sed 's/^##[[:space:]]*//')
    if printf '%s' "$_hname" | grep -qE "^(${_known_headers})([[:space:]]|$)"; then
      continue
    fi
    if printf '%s' "$_hname" | grep -qiE "(${_gate_stems})"; then
      echo "VIOLATION: unrecognized gate-like section header — '## ${_hname}' (near-miss of a gate-driving header; the resolver matches EXACT names, so a typo silently downgrades a blocking gate to SKIP. Recognized: Flow-artifact derivation / Cross-cutting concerns / Relation derivation / UI quality signatures / Conditional scaffold artifacts / Entity source globs / Entity matching tokens / Test patterns)"
      violations=$((violations + 1))
    fi
  done <<EOF_HDRS
$(printf '%s\n' "$content" | grep -E '^## ' || true)
EOF_HDRS

  # ---- Check 3c (S5): unresolved extends placeholder breaks the chain walk ─
  if printf '%s\n' "$frontmatter" | grep -qE '^extends:.*<[^>]*>'; then
    echo "VIOLATION: extends carries an unrewritten template placeholder (e.g. '<other-pack-or-null>') — the resolver chain walk breaks and every section falls back to nothing. Set extends to a real pack name or null."
    violations=$((violations + 1))
  fi

  # ---- Check 4: YAML validity in hint-section fenced blocks ---------------
  # We extract yaml fenced blocks that appear under the four conditional sections.
  # Strategy: scan line by line; track which conditional section we're in;
  # collect yaml fenced blocks; validate each one.
  # Per-line matching uses bash builtins ([[ ]]) — the former per-line
  # `printf | grep` pipeline forked ~10 subshells PER LINE and was the dominant
  # lint cost (~7s of ~7.6s on a 170-line pack). Builtins are fork-free; the
  # match semantics are identical: substring (grep -F), '^## ' / '^```yaml'
  # prefix (grep -E), and the fence-end '^```[[:space:]]*$' (== grep -E
  # '^```\s*$' on this platform, verified).
  local hint_sections=("## Deep-scan file hints" "## Authz mapping" "## UI detection" "## Reuse discovery")
  local in_hint_section=0
  local in_yaml_fence=0
  local yaml_block=""
  local hint_block_count=0

  if ! _yaml_available; then
    echo "NOTE: yaml validator unavailable — structural check only"
  fi

  while IFS= read -r line; do
    # Check if we're entering a conditional hint section
    local hs
    for hs in "${hint_sections[@]}"; do
      if [[ $line == *"$hs"* ]]; then
        in_hint_section=1
        break
      fi
    done
    # Check if we've left the hint section (new ## heading, not a hint section)
    if [[ $line == "## "* ]] && [ "$in_hint_section" -eq 1 ]; then
      local is_hint=0
      for hs in "${hint_sections[@]}"; do
        if [[ $line == *"$hs"* ]]; then
          is_hint=1
          break
        fi
      done
      if [ "$is_hint" -eq 0 ]; then
        in_hint_section=0
      fi
    fi

    if [ "$in_hint_section" -eq 1 ]; then
      # Start of a yaml fenced block
      if [[ $line == '```yaml'* ]]; then
        in_yaml_fence=1
        yaml_block=""
        hint_block_count=$((hint_block_count + 1))
        continue
      fi
      # End of a yaml fenced block
      if [ "$in_yaml_fence" -eq 1 ] && [[ $line =~ ^'```'[[:space:]]*$ ]]; then
        in_yaml_fence=0
        # Validate the collected yaml block
        if ! _yaml_valid "$yaml_block"; then
          echo "VIOLATION: invalid YAML block #$hint_block_count under a hint section"
          violations=$((violations + 1))
        fi
        yaml_block=""
        continue
      fi
      # Accumulate yaml block lines
      if [ "$in_yaml_fence" -eq 1 ]; then
        if [ -n "$yaml_block" ]; then
          yaml_block="${yaml_block}
${line}"
        else
          yaml_block="$line"
        fi
      fi
    fi
  done < "$pack_file"

  # ---- Check 5: cross-framework token leak --------------------------------
  if [ -z "$pack_framework" ]; then
    echo "NOTE: could not determine pack framework — skipping cross-framework leak check"
  else
    # Extract body (everything after the second ---)
    local body
    body=$(awk '/^---/{n++; if(n==2){body=1; next}} body{print}' "$pack_file")

    # Remove contrast-example fenced blocks from the body before checking
    # A contrast-example fence: opening ``` line whose info-string or immediately
    # preceding non-empty line contains "contrast example" (case-insensitive).
    local body_stripped
    local tmp_body_in
    tmp_body_in=$(mktemp)
    printf '%s\n' "$body" > "$tmp_body_in"
    body_stripped=$(BODY_IN="$tmp_body_in" python3 -c '
import sys, re, os
body_file = os.environ.get("BODY_IN", "")
try:
    text = open(body_file).read()
except Exception:
    sys.exit(0)
lines = text.split("\n")
result = []
i = 0
while i < len(lines):
    line = lines[i]
    if line.startswith("```"):
        info_str = line[3:].strip().lower()
        prev_text = ""
        for j in range(len(result)-1, max(len(result)-5, -1), -1):
            if result[j].strip():
                prev_text = result[j].lower()
                break
        is_contrast = "contrast example" in info_str or "contrast example" in prev_text
        if is_contrast:
            i += 1
            while i < len(lines) and not re.match(r"^```\s*$", lines[i]):
                i += 1
            i += 1
            continue
    result.append(line)
    i += 1
print("\n".join(result))
' 2>/dev/null)
    rm -f "$tmp_body_in"
    [ -z "$body_stripped" ] && body_stripped="$body"

    # Read the token map and check each foreign framework's tokens
    # Write body_stripped to a temp file, pass token map + framework via env vars
    # Also pass the extends: value so child packs don't get flagged for parent tokens
    local pack_extends
    pack_extends=$(printf '%s\n' "$frontmatter" | grep -m1 '^extends:' | sed 's/extends:[[:space:]]*//' | tr -d '"'"'" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]' | sed 's/_universal//;s/_//')
    local token_map_raw
    token_map_raw=$(_read_token_map 2>/dev/null)
    if [ -n "$token_map_raw" ]; then
      local tmp_body
      tmp_body=$(mktemp)
      printf '%s\n' "$body_stripped" > "$tmp_body"
      local leak_output
      leak_output=$(PACK_FW="$pack_framework" PACK_EXTENDS="$pack_extends" TOKEN_MAP_FILE="$LINT_MD" BODY_FILE="$tmp_body" \
        python3 -c '
import os, sys

own_fw = os.environ.get("PACK_FW", "").lower().strip()
# pack_extends: the framework this pack extends (if any); its tokens are permitted
pack_extends_raw = os.environ.get("PACK_EXTENDS", "").lower().strip()
# Build set of exempt framework names: own framework + all frameworks that are
# prefixes of own_fw (e.g. "laravel-base-26" extends "laravel")
exempt_fws = {own_fw}
if pack_extends_raw:
    exempt_fws.add(pack_extends_raw)
# Also exempt any framework whose name is a prefix of own_fw (child pack detection)
# e.g. own_fw="laravel-base-26" -> exempt "laravel"
parts = own_fw.split("-")
for i in range(1, len(parts)):
    exempt_fws.add("-".join(parts[:i]))

lint_md = os.environ.get("TOKEN_MAP_FILE", "")
body_file = os.environ.get("BODY_FILE", "")

# Read body
try:
    body = open(body_file).read()
except Exception:
    sys.exit(0)

# Parse token map from _lint.md
token_map_raw = ""
try:
    content = open(lint_md).read()
    in_map = False
    in_fence = False
    for line in content.splitlines():
        if "## Cross-framework token map" in line:
            in_map = True
            continue
        if in_map and line.strip().startswith("```"):
            in_fence = not in_fence
            continue
        if in_map and in_fence:
            token_map_raw += line + "\n"
        elif in_map and not in_fence and line.startswith("## "):
            break
except Exception:
    sys.exit(0)

violations = []
for line in token_map_raw.strip().splitlines():
    line = line.strip()
    if not line or line.startswith("#"):
        continue
    if ":" not in line:
        continue
    fw_raw, _, tokens_raw = line.partition(":")
    fw = fw_raw.strip().lower()
    if fw in exempt_fws:
        continue
    tokens = [t.strip() for t in tokens_raw.split(",") if t.strip()]
    for token in tokens:
        if token in body:
            print(f"VIOLATION: cross-framework leak — found \"{token}\" ({fw} token) in {own_fw} pack body")

' 2>/dev/null || true)
      rm -f "$tmp_body"
      if [ -n "$leak_output" ]; then
        echo "$leak_output"
        local n_leaks
        n_leaks=$(printf '%s\n' "$leak_output" | grep -c '^VIOLATION:' || true)
        violations=$((violations + n_leaks))
      fi
    fi
  fi

  # ---- Summary -----------------------------------------------------------
  if [ "$violations" -eq 0 ]; then
    echo "PASS: $pack_file — no violations"
    return 0
  else
    echo "SUMMARY: $pack_file — $violations violation(s) found"
    return 1
  fi
}

# --------------------------------------------------------------------------
# Registry helpers
# --------------------------------------------------------------------------

# _enum_frameworks: parse §8.5 detection table from scan-procedure.md;
# emit one framework name per line, sorted alphabetically.
SCAN_PROC="$SCRIPT_DIR/../skills/scan-codebase/references/scan-procedure.md"

_enum_frameworks() {
  if [ ! -f "$SCAN_PROC" ]; then
    echo "ERROR: scan-procedure.md not found at $SCAN_PROC" >&2
    return 1
  fi
  # Extract lines between ## Step 8.5 and ## Step 9, filter to table rows,
  # skip header and separator rows, take the 4th pipe-delimited column (Framework),
  # strip leading spaces, take the first whitespace token (strips parentheticals),
  # lowercase, sort.
  awk '/^## Step 8\.5/,/^## Step 9/' "$SCAN_PROC" \
    | grep '^|' \
    | grep -v '^| Manifest\|^|---' \
    | awk -F'|' '{print $4}' \
    | sed 's/^[[:space:]]*//' \
    | awk '{print $1}' \
    | tr '[:upper:]' '[:lower:]' \
    | sort
}

# _registry_table_body: emit the registry table body (header + rows) to stdout.
# Deterministic: alphabetical framework order, no timestamps.
_registry_table_body() {
  printf '| framework | pack file | tier | status | lints_clean |\n'
  printf '|---|---|---|---|---|\n'
  while IFS= read -r fw; do
    pack_file="$CONV_DIR/${fw}.md"
    if [ ! -f "$pack_file" ]; then
      printf '| %s | — | — | none | n/a |\n' "$fw"
      continue
    fi
    # Read frontmatter
    local fm
    fm=$(awk '/^---/{n++; if(n==1){next} if(n==2){exit}} n==1{print}' "$pack_file")
    local tier
    tier=$(printf '%s\n' "$fm" | grep -m1 '^pack_tier:' | sed 's/pack_tier:[[:space:]]*//' | tr -d '"'"'" | tr -d '[:space:]')
    local pack_basename
    pack_basename="${fw}.md"
    if [ -z "$tier" ]; then
      printf '| %s | %s | — | unknown | n/a |\n' "$fw" "$pack_basename"
      continue
    fi
    if [ "$tier" = "thin" ]; then
      printf '| %s | %s | thin | thin | n/a |\n' "$fw" "$pack_basename"
      continue
    fi
    if [ "$tier" = "full" ]; then
      # Run linter; suppress output; check rc
      local lint_ok
      if _validate_pack "$pack_file" >/dev/null 2>&1; then
        lint_ok="yes"
      else
        lint_ok="no"
      fi
      if [ "$lint_ok" = "yes" ]; then
        printf '| %s | %s | full | ready | yes |\n' "$fw" "$pack_basename"
      else
        printf '| %s | %s | full | partial | no |\n' "$fw" "$pack_basename"
      fi
      continue
    fi
    # Any other tier value: treat as unknown
    printf '| %s | %s | %s | unknown | n/a |\n' "$fw" "$pack_basename" "$tier"
  done < <(_enum_frameworks)
}

# _generate_registry_content: emit the full _registry.md content to stdout.
_generate_registry_content() {
  printf '<!-- DO NOT EDIT BY HAND — regenerate with: bash plugins/mega-sdd/scripts/validate-pack.sh --registry -->\n'
  printf '\n'
  printf '# Framework Pack Registry\n'
  printf '\n'
  printf 'Auto-generated readiness table. Frameworks enumerated from §8.5 of\n'
  printf '`scan-codebase/references/scan-procedure.md` (the framework detection table).\n'
  printf '\n'
  printf '%s\n' '**Status key:**'
  printf '%s\n' '- `ready` — pack file exists, `pack_tier: full`, lints clean'
  printf '%s\n' '- `partial` — pack file exists, `pack_tier: full`, but has lint violations'
  printf '%s\n' '- `thin` — pack file exists with `pack_tier: thin`'
  printf '%s\n' '- `unknown` — pack file exists but no recognised `pack_tier`'
  printf '%s\n' '- `none` — no pack file'
  printf '\n'
  _registry_table_body
}

# _pack_tier: echo the pack_tier frontmatter value (full|thin|...) or empty.
_pack_tier() {
  awk '/^---/{n++; if(n==1){next} if(n==2){exit}} n==1{print}' "$1" \
    | grep -m1 '^pack_tier:' | sed 's/pack_tier:[[:space:]]*//' | tr -d '"'"'" | tr -d '[:space:]'
}

# --------------------------------------------------------------------------
# Main dispatch
# --------------------------------------------------------------------------
if [ "$MODE" = "single" ]; then
  _validate_pack "$SINGLE_FILE"
  exit $?
fi

if [ "$MODE" = "registry" ]; then
  REGISTRY_FILE="$CONV_DIR/_registry.md"
  _generate_registry_content > "$REGISTRY_FILE"
  echo "Generated: $REGISTRY_FILE"
  exit 0
fi

if [ "$MODE" = "check-registry" ]; then
  REGISTRY_FILE="$CONV_DIR/_registry.md"
  if [ ! -f "$REGISTRY_FILE" ]; then
    echo "stale: _registry.md does not exist — run: bash plugins/mega-sdd/scripts/validate-pack.sh --registry" >&2
    exit 1
  fi
  fresh_content=$(_generate_registry_content)
  committed_content=$(cat "$REGISTRY_FILE")
  if [ "$fresh_content" = "$committed_content" ]; then
    echo "OK: _registry.md is up-to-date"
    exit 0
  else
    echo "stale: _registry.md is out of date — run: bash plugins/mega-sdd/scripts/validate-pack.sh --registry" >&2
    exit 1
  fi
fi

# --all mode — tier-aware aggregation.
# Per-pack validation is UNCHANGED (it prints every violation; single mode still
# exits non-zero on any violation — the contract). Only the AGGREGATE gate's
# blocking policy is tier-aware:
#   - pack_tier: full       → any violation blocks (these packs claim completeness)
#   - thin / untiered       → only STRUCTURAL errors block (invalid YAML or a
#                             cross-framework leak); missing-section gaps are
#                             reported but non-blocking (thin proof-packs and
#                             project overlays are intentionally incomplete).
# This makes `--all` a usable green CI gate without weakening per-pack linting.
overall=0
found=0
for f in "$CONV_DIR"/*.md; do
  [ -f "$f" ] || continue
  base=$(basename "$f")
  case "$base" in
    _template.md|_universal.md|_lint.md|_registry.md|README.md) continue ;;
    _*) continue ;;
  esac
  found=$((found + 1))
  echo "--- $base ---"
  tier=$(_pack_tier "$f")
  out=$(_validate_pack "$f"); rc=$?
  printf '%s\n' "$out"
  if [ "$rc" -ne 0 ]; then
    if [ "$tier" = "full" ]; then
      overall=1
    elif printf '%s\n' "$out" | grep -qiE 'invalid YAML|cross-framework leak'; then
      overall=1
      echo "NOTE: $base (${tier:-untiered}) has BLOCKING structural errors (invalid YAML / cross-framework leak)"
    else
      echo "NOTE: $base (${tier:-untiered}) lint findings are non-blocking for --all (tier-aware); run 'validate-pack.sh $base' for the full list"
    fi
  fi
done
if [ "$found" -eq 0 ]; then
  echo "NOTE: no pack files found in $CONV_DIR"
fi
exit $overall
