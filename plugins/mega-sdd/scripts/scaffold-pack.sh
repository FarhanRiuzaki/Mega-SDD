#!/usr/bin/env bash
# scaffold-pack.sh — generate a linter-valid skeleton pack from _template.md
#
# Usage:
#   scaffold-pack.sh <framework>
#
# The skeleton is written to:
#   ${SCAFFOLD_DEST_DIR:-<conventions-dir>}/<framework>.md
#
# Environment:
#   SCAFFOLD_DEST_DIR  — override destination directory (default: conventions dir
#                        next to this script). Used verbatim when set.
#
# Exit: 0 = success, 1 = error, 2 = usage error
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONV_DIR="$(cd "$SCRIPT_DIR/../references/framework-conventions" && pwd)"
TEMPLATE="$CONV_DIR/_template.md"

# --------------------------------------------------------------------------
# Arg parse
# --------------------------------------------------------------------------
if [ $# -eq 0 ]; then
  echo "usage: scaffold-pack.sh <framework>" >&2
  echo "  <framework>: kebab-case framework name (e.g. fastapi, nestjs, sveltekit)" >&2
  exit 2
fi

FRAMEWORK="$1"

# Resolve destination directory
DEST_DIR="${SCAFFOLD_DEST_DIR:-$CONV_DIR}"
DEST_FILE="$DEST_DIR/${FRAMEWORK}.md"

# --------------------------------------------------------------------------
# Pre-flight checks
# --------------------------------------------------------------------------
if [ ! -f "$TEMPLATE" ]; then
  echo "ERROR: template not found at $TEMPLATE" >&2
  exit 1
fi

if [ -f "$DEST_FILE" ]; then
  echo "ERROR: $DEST_FILE already exists — will not clobber." >&2
  echo "  Delete it manually if you want to re-scaffold." >&2
  exit 1
fi

if [ ! -d "$DEST_DIR" ]; then
  echo "ERROR: destination directory does not exist: $DEST_DIR" >&2
  exit 1
fi

# --------------------------------------------------------------------------
# Derive display name (capitalize first letter)
# --------------------------------------------------------------------------
# e.g. fastapi -> FastAPI would need special casing; use Title-cased kebab parts
# Strategy: capitalize each hyphen-separated word.
display_name=""
IFS='-' read -ra parts <<< "$FRAMEWORK"
for part in "${parts[@]}"; do
  if [ -n "$part" ]; then
    # Capitalize first letter
    cap="$(printf '%s' "${part:0:1}" | tr '[:lower:]' '[:upper:]')${part:1}"
    if [ -n "$display_name" ]; then
      display_name="${display_name} ${cap}"
    else
      display_name="${cap}"
    fi
  fi
done

# --------------------------------------------------------------------------
# Build skeleton via python3 (line-by-line substitution)
# Avoids sed quoting pitfalls and handles the frontmatter rewrite precisely.
# --------------------------------------------------------------------------
python3 - "$TEMPLATE" "$DEST_FILE" "$FRAMEWORK" "$display_name" <<'PYEOF'
import sys, re

template_path, dest_path, framework, display_name = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

with open(template_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

out = []
in_frontmatter = False
frontmatter_count = 0
pack_tier_written = False
framework_version_written = False
fm_manifest_done = False
fm_marker_done = False

for line in lines:
    stripped = line.rstrip('\n')

    # Track frontmatter delimiters
    if stripped == '---':
        frontmatter_count += 1
        if frontmatter_count == 1:
            in_frontmatter = True
            out.append(line)
            continue
        elif frontmatter_count == 2:
            in_frontmatter = False
            # Ensure pack_tier is written before closing ---
            if not pack_tier_written:
                out.append('pack_tier: thin\n')
                pack_tier_written = True
            out.append(line)
            continue

    if in_frontmatter:
        # Replace framework: line
        if re.match(r'^framework:', stripped):
            out.append(f'framework: {framework}\n')
            # Insert pack_tier right after framework line
            out.append('pack_tier: thin\n')
            pack_tier_written = True
            continue

        # Drop existing pack_tier if template ever has one
        if re.match(r'^pack_tier:', stripped):
            continue

        # Replace framework_version_range with TBD
        if re.match(r'^framework_version_range:', stripped):
            out.append('framework_version_range: "TBD"\n')
            framework_version_written = True
            continue

        # Rewrite detection_signature sub-keys to TBD (strip angle-bracket placeholders)
        if re.match(r'^  package_manifest:', stripped):
            out.append('  package_manifest: TBD\n')
            fm_manifest_done = True
            continue

        if re.match(r'^  dependency_marker:', stripped):
            out.append('  dependency_marker: TBD\n')
            fm_marker_done = True
            continue

        # Keep other frontmatter lines (last_verified_against, maintainer, etc.)
        # but strip inline comments from lines we haven't rewritten, to keep them clean
        # Strip trailing comment-style text (# ...) from frontmatter values
        cleaned = re.sub(r'\s+#\s.*$', '', stripped)
        out.append(cleaned + '\n')
        continue

    # Outside frontmatter: process body

    # Replace H1 title line
    if re.match(r'^# ', stripped) and not re.match(r'^## ', stripped):
        out.append(f'# {display_name} Convention Pack\n')
        continue

    # Replace the 1-sentence purpose placeholder
    if re.match(r'^<1-sentence pack purpose', stripped):
        out.append(f'<1-sentence purpose for {framework} projects.>\n')
        continue

    # Neutralize framework-specific example tokens in placeholder text to avoid
    # cross-framework token leaks in the scaffolded body.
    # The token map (see _lint.md) flags:
    #   laravel: app/Http, Gate::define, $routeMiddleware, .blade.php, Eloquent,
    #            artisan, composer.json, @extends(, @section(, blade
    #   rails:   ActiveRecord, config/routes.rb, app/controllers, .html.erb,
    #            Gemfile, attr_accessible
    #   django:  settings.py, INSTALLED_APPS, models.Model, urls.py, manage.py,
    #            {%extends, {%block, {%url, pyproject.toml
    #   spring:  @RestController, application.properties, @Autowired, pom.xml,
    #            @SpringBootApplication, @Service(, @Repository(
    # We replace them with generic <...> placeholders ONLY in lines that
    # are clearly illustrative examples (contain angle-bracket placeholders
    # or start with a pipe/bullet) — this preserves the section structure.

    # Only clean lines that are in example/template rows (contain <...> or | or start with - or whitespace-)
    is_example = ('<' in stripped and '>' in stripped) or stripped.startswith('|') or stripped.startswith('-') or stripped.startswith('  -')

    if is_example:
        s = stripped
        # --- Laravel tokens ---
        s = s.replace('app/Http/Controllers/', '<e.g., src/routers/>')
        s = s.replace('app/Http/', '<e.g., src/>')
        s = s.replace('.blade.php', '.<ext>.html')
        s = s.replace('Eloquent', '<ORM>')
        s = s.replace('artisan', '<cli>')
        s = s.replace('composer.json', '<manifest-file>')
        s = s.replace('composer.lock', '<lock-file>')
        s = s.replace('composer update', '<update-cmd>')
        s = s.replace('composer install', '<install-cmd>')
        s = s.replace('@extends(', '<layout-directive>(')
        s = s.replace('@section(', '<section-directive>(')
        s = s.replace('resources/views/**/*.blade.php', 'resources/views/**/*.<ext>.html')
        s = s.replace('resources/views/**/show.blade.php', 'resources/views/**/show.<ext>.html')
        s = s.replace('resources/views/**/edit.blade.php', 'resources/views/**/edit.<ext>.html')
        # blade (standalone word) — careful not to break .blade.php already replaced above
        s = re.sub(r'\bBlade\b', '<templating-engine>', s)
        # --- Rails tokens ---
        s = s.replace('ActiveRecord', '<ORM>')
        s = s.replace('config/routes.rb', '<routes-file>')
        s = s.replace('app/controllers', '<controllers-dir>')
        s = s.replace('.html.erb', '.<ext>.html')
        s = s.replace('Gemfile.lock', '<lock-file>')
        s = s.replace('Gemfile', '<manifest-file>')
        s = s.replace('attr_accessible', '<attr-accessor-macro>')
        # --- Django tokens ---
        s = s.replace('settings.py', '<settings-file>')
        s = s.replace('INSTALLED_APPS', '<installed-apps>')
        s = s.replace('models.Model', '<Model-base-class>')
        s = s.replace('urls.py', '<urls-file>')
        s = s.replace('manage.py', '<cli>')
        s = s.replace('{%extends', '<layout-tag-extends')
        s = s.replace('{%block', '<layout-tag-block')
        s = s.replace('{%url', '<url-tag')
        s = s.replace('pyproject.toml', '<manifest-file>')
        # --- Spring tokens ---
        s = s.replace('@RestController', '<rest-controller-annotation>')
        s = s.replace('application.properties', '<app-config-file>')
        s = s.replace('@Autowired', '<inject-annotation>')
        s = s.replace('pom.xml', '<manifest-file>')
        s = s.replace('@SpringBootApplication', '<app-annotation>')
        s = s.replace('@Service(', '<service-annotation>(')
        s = s.replace('@Repository(', '<repository-annotation>(')
        out.append(s + '\n')
        continue

    # All other body lines: emit as-is
    out.append(line)

with open(dest_path, 'w', encoding='utf-8') as f:
    f.writelines(out)

print(f"Scaffolded: {dest_path}")
PYEOF

rc=$?
if [ $rc -ne 0 ]; then
  echo "ERROR: scaffold generation failed (python3 exit $rc)" >&2
  # Clean up partial file if it was created
  [ -f "$DEST_FILE" ] && rm -f "$DEST_FILE"
  exit 1
fi

# --------------------------------------------------------------------------
# Next-steps guidance
# --------------------------------------------------------------------------
cat <<GUIDE

  Pack skeleton created: $DEST_FILE

  Next steps:
    1. Open the file and fill in every <placeholder> section.
    2. Lint your pack:
         bash plugins/mega-sdd/scripts/validate-pack.sh ${FRAMEWORK}.md
    3. Update the registry:
         bash plugins/mega-sdd/scripts/validate-pack.sh --registry
    4. When all sections are complete, set pack_tier to 'full' and re-lint.

  The pack starts as pack_tier: thin — thin packs are non-blocking in --all
  until you promote them to 'full'.

GUIDE

exit 0
