#!/usr/bin/env python3
"""
Iter 76 logic-proof for execute-bolts Step 4.5.b-starterkit.build + .build.code-slice + .inject.

Implements the algorithm verbatim from plugins/mega-sdd/skills/execute-bolts/SKILL.md
(walking-skeleton: controller pattern only for code-slice).

Usage: python3 simulate-build.py [scenario]
Scenarios:
  A_match       - unit matches controller pattern (expected: PASS — slice.patterns.controller + code_examples.controller filled)
  B_no_match    - unit target_files don't match any pattern location (expected: slice.patterns empty)
  C_missing_src - patterns.controller._source[0] points to file not on disk (expected: slice.patterns.controller filled, code_examples empty)
"""

import os
import re
import sys
import json
import yaml
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent / "project"
STARTERKIT_YAML = PROJECT_ROOT / ".mega-sdd" / "codebase" / "starterkit-context.yaml"
UNIT_FILE = PROJECT_ROOT / ".mega-sdd" / "vaults" / "test-vault" / "units" / "U-001.md"


def parse_unit_frontmatter(path):
    text = path.read_text()
    m = re.match(r"---\s*\n(.*?)\n---", text, re.DOTALL)
    if not m:
        return {}
    return yaml.safe_load(m.group(1))


def compile_pattern_to_regex(naming, extension):
    """Convert {Model}Controller<ext> → [A-Z]\w+Controller\.<ext>$"""
    if naming is None:
        return None
    pattern = re.escape(naming)
    pattern = pattern.replace(re.escape("{Model}"), r"[A-Z]\w+")
    pattern = pattern.replace(re.escape("{model}"), r"[a-z_]+")
    pattern = pattern.replace(re.escape("{table}"), r"[a-z_]+")
    pattern = pattern.replace(re.escape("{timestamp}"), r"\d{4}_\d{2}_\d{2}_\d{6}")
    ext = re.escape(extension or "")
    pattern = pattern.replace(re.escape("<ext>"), ext)
    pattern = pattern + r"$"
    try:
        return re.compile(pattern)
    except re.error as e:
        print(f"  [warn] naming-regex compile failed for '{naming}': {e}")
        return None


def build_slice(starterkit_context, unit):
    slice_ = {"patterns": {}, "code_examples": {}, "auth": None, "rbac": None, "ui_ux": None, "libs": []}

    relevance = unit.get("starterkit_relevance") or []
    target_files = unit.get("target_files") or []

    # Legacy slices (Iter 32+ — kept as-is)
    if "auth" in relevance and starterkit_context.get("auth"):
        a = starterkit_context["auth"]
        slice_["auth"] = {k: a.get(k) for k in ("lib", "guard", "user_model")}
    if "rbac" in relevance and starterkit_context.get("rbac"):
        r = starterkit_context["rbac"]
        slice_["rbac"] = {k: r.get(k) for k in ("lib", "role_model", "permission_model", "middleware")}
    if "ui_ux" in relevance and starterkit_context.get("ui_ux"):
        u = starterkit_context["ui_ux"]
        slice_["ui_ux"] = {k: u.get(k) for k in ("layout_extends", "notification_lib", "idioms")}
    if "libs" in relevance and starterkit_context.get("libs"):
        # filter by usage_hint overlap with target_files
        for lib in starterkit_context["libs"]:
            hints = lib.get("usage_hint") or []
            if any(any(tf.startswith(h.rstrip("/")) for h in hints) for tf in target_files):
                slice_["libs"].append(lib)

    # ─── Iter 76 §patterns wire (location-primary; naming-fallback only when location null) ──
    patterns_block = starterkit_context.get("patterns") or {}
    if patterns_block and target_files:
        CATEGORIES = ["controller", "data_model", "request_validator", "business_logic", "test", "schema_migration", "route"]
        for category in CATEGORIES:
            pattern = patterns_block.get(category)
            if not pattern:
                continue
            has_location = pattern.get("location") is not None
            for tf in target_files:
                if has_location:
                    location_norm = pattern["location"].rstrip("/") + "/"
                    if tf.startswith(location_norm):
                        slice_["patterns"][category] = pattern
                        break
                else:
                    # naming-fallback against basename only
                    if pattern.get("naming"):
                        naming_regex = compile_pattern_to_regex(pattern.get("naming"), pattern.get("extension"))
                        basename = os.path.basename(tf)
                        if naming_regex and naming_regex.search(basename):
                            slice_["patterns"][category] = pattern
                            break

    # ─── Iter 76 controller code-slice (walking-skeleton) ───────────────
    if slice_["patterns"].get("controller"):
        ctrl = slice_["patterns"]["controller"]
        sources = ctrl.get("_source") or []
        if sources:
            first_source = sources[0]
            example_path = first_source.split(":")[0]
            full_path = PROJECT_ROOT / example_path
            if full_path.is_file():
                size = full_path.stat().st_size
                if size < 3072:
                    content = full_path.read_text()
                    slice_["code_examples"]["controller"] = {
                        "path": example_path,
                        "content": content,
                        "truncated": False,
                    }
                else:
                    lines = full_path.read_text().splitlines()[:100]
                    slice_["code_examples"]["controller"] = {
                        "path": example_path,
                        "content": "\n".join(lines) + "\n# ... (truncated at 100 lines — see full file via Read tool)",
                        "truncated": True,
                    }
            else:
                print(f"  [info] _source[0] not on disk: {full_path} — skipping code example (NOT a halt)")

    return slice_


def render_t23_section(slice_):
    """Implements Step 4.5.b-starterkit.inject render template."""
    lines = ["### Starterkit context (relevant to this unit)", ""]

    if slice_["auth"]:
        a = slice_["auth"]
        lines.append(f"Auth: lib={a['lib']}, guard={a['guard']}, user_model={a['user_model']}")
    if slice_["rbac"]:
        r = slice_["rbac"]
        lines.append(f"RBAC: lib={r['lib']}, role_model={r['role_model']}, middleware={', '.join(r['middleware'] or [])}")
    if slice_["ui_ux"]:
        u = slice_["ui_ux"]
        lines.append(f"UI/UX: extends={u['layout_extends']}, notification={u['notification_lib']}, idioms=[{'; '.join(u['idioms'] or [])}]")
    if slice_["libs"]:
        for lib in slice_["libs"]:
            lines.append(f"Libs in scope: {lib['name']}@{lib['version']} (used in: {', '.join(lib.get('usage_hint') or [])})")

    # Iter 76 §patterns section
    if slice_["patterns"]:
        lines.append("")
        lines.append("### Starterkit code patterns (follow these conventions)")
        lines.append("")
        for category, pat in slice_["patterns"].items():
            lines.append(f"- {category}:")
            lines.append(f"    location:  {pat.get('location')}")
            lines.append(f"    naming:    {pat.get('naming')}")
            lines.append(f"    extension: {pat.get('extension')}")
            extras = pat.get("extras") or {}
            if extras:
                lines.append(f"    extras:    {json.dumps(extras)}")
            sources = pat.get("_source") or []
            if sources:
                lines.append(f"    _source:   {sources[0]}")

    # Iter 76 controller code example
    if slice_["code_examples"].get("controller"):
        ex = slice_["code_examples"]["controller"]
        lines.append("")
        lines.append("### Reference code example (from starterkit)")
        lines.append("")
        lines.append(f"Pattern: controller")
        lines.append(f"File:    {ex['path']}")
        if ex["truncated"]:
            lines.append("(truncated — full file available via Read tool)")
        lines.append("")
        ext = Path(ex["path"]).suffix.lstrip(".")
        lines.append(f"```{ext}")
        lines.append(ex["content"])
        lines.append("```")
        lines.append("")
        lines.append("Follow this style for new controller files. Do not deviate from the import order, base class, method shape, or response idiom shown above unless the unit explicitly requires it.")

    return "\n".join(lines)


def main():
    scenario = sys.argv[1] if len(sys.argv) > 1 else "A_match"

    starterkit_context = yaml.safe_load(STARTERKIT_YAML.read_text())["starterkit_context"]
    unit = parse_unit_frontmatter(UNIT_FILE)

    # Scenario manipulation
    if scenario == "B_no_match":
        unit["target_files"] = ["resources/views/random.blade.php"]  # not in any patterns.location
    elif scenario == "C_missing_src":
        starterkit_context["patterns"]["controller"]["_source"] = ["app/Http/Controllers/NonExistentController.php:1-30"]

    print(f"━━━ Scenario: {scenario} ━━━")
    print(f"unit.target_files = {unit['target_files']}")
    print(f"unit.starterkit_relevance = {unit.get('starterkit_relevance')}")
    print()

    slice_ = build_slice(starterkit_context, unit)

    print("─── build output ───")
    print(f"slice.patterns categories matched: {list(slice_['patterns'].keys()) or '(none)'}")
    print(f"slice.code_examples categories: {list(slice_['code_examples'].keys()) or '(none)'}")
    if slice_["code_examples"].get("controller"):
        ex = slice_["code_examples"]["controller"]
        print(f"  controller.path = {ex['path']}")
        print(f"  controller.truncated = {ex['truncated']}")
        print(f"  controller.content_bytes = {len(ex['content'])}")
    print()

    rendered = render_t23_section(slice_)
    print("─── inject output (T2.3 section) ───")
    print(rendered)
    print()
    print(f"─── rendered_bytes = {len(rendered.encode('utf-8'))} ───")

    # Verdicts
    if scenario == "A_match":
        ok_patterns = "controller" in slice_["patterns"]
        ok_code = "controller" in slice_["code_examples"]
        ok_render = "### Starterkit code patterns" in rendered and "### Reference code example" in rendered
        print()
        print(f"VERDICT: patterns_controller_present={ok_patterns}  code_examples_controller_present={ok_code}  render_has_both_sections={ok_render}")
        assert ok_patterns and ok_code and ok_render, "A_match FAILED"
        print("✓ A_match PASS")
    elif scenario == "B_no_match":
        ok_empty = "controller" not in slice_["patterns"]
        ok_no_render = "### Starterkit code patterns" not in rendered
        print()
        print(f"VERDICT: patterns_empty={ok_empty}  no_patterns_render={ok_no_render}")
        assert ok_empty and ok_no_render, "B_no_match FAILED"
        print("✓ B_no_match PASS")
    elif scenario == "C_missing_src":
        ok_pattern = "controller" in slice_["patterns"]
        ok_no_code = "controller" not in slice_["code_examples"]
        ok_pattern_render = "### Starterkit code patterns" in rendered
        ok_no_code_render = "### Reference code example" not in rendered
        print()
        print(f"VERDICT: pattern_still_present={ok_pattern}  code_example_absent={ok_no_code}  pattern_render_yes={ok_pattern_render}  code_render_no={ok_no_code_render}")
        assert ok_pattern and ok_no_code and ok_pattern_render and ok_no_code_render, "C_missing_src FAILED"
        print("✓ C_missing_src PASS")


if __name__ == "__main__":
    main()
