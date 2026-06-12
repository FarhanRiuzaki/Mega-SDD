#!/usr/bin/env bash
# Pin: every full-tier framework pack carries a Security idioms section with real content.
set -u
err=0
dir=plugins/mega-sdd/references/framework-conventions
for f in "$dir"/*.md; do
  base=$(basename "$f")
  case "$base" in
    _template.md|_universal.md|_lint.md|_registry.md|README.md|laravel-base-26.md) continue ;;
  esac
  n=$(grep -c '^## Security idioms' "$f")
  [ "$n" -eq 1 ] || { echo "$base: expected exactly 1 Security idioms section, got $n"; err=1; continue; }
  # section body: at least 7 bold-labelled class bullets between the heading and the next ## heading
  bullets=$(awk '/^## Security idioms/{on=1; next} on && /^## /{exit} on && /^- \*\*/{c++} END{print c+0}' "$f")
  [ "$bullets" -ge 7 ] || { echo "$base: Security idioms has only $bullets class bullets (need >=7)"; err=1; }
  # the canonical classes every stack must address (or explicitly opt out per-bullet)
  for cls in "Input validation" "SQL injection" "CSRF" "Password hashing" "Secrets"; do
    awk '/^## Security idioms/{on=1; next} on && /^## /{exit} on{print}' "$f" | grep -q "$cls" \
      || { echo "$base: Security idioms missing class: $cls"; err=1; }
  done
done
# template documents the section spec
grep -q '^## Security idioms' "$dir/_template.md" || { echo "_template.md missing Security idioms spec"; err=1; }
exit $err
