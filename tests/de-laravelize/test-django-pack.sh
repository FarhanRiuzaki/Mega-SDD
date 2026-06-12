#!/usr/bin/env bash
set -u
err=0
p="plugins/mega-sdd/references/framework-conventions/django.md"
[ -f "$p" ] || { echo "missing django.md"; err=1; }
for s in "## Deep-scan file hints" "## Authz mapping" "## UI detection"; do
  grep -qF "$s" "$p" 2>/dev/null || { echo "django.md missing section: $s"; err=1; }
done
grep -qE 'permission_required|PermissionRequiredMixin|Group|django\.contrib\.auth' "$p" 2>/dev/null || { echo "django.md authz mapping not Django-shaped"; err=1; }
grep -qE 'Gate::define|app/Http|@extends' "$p" 2>/dev/null && { echo "django.md leaks Laravel"; err=1; }
for c in auth-libs rbac-libs ui-libs generic-libs; do
  [ -f "plugins/mega-sdd/references/lib-patterns/django/$c.md" ] || { echo "missing lib-patterns/django/$c.md"; err=1; }
done
fx="tests/fixtures/de-laravelize/django-sample/.mega-sdd/codebase/starterkit-context.yaml"
[ -f "$fx" ] || { echo "missing django fixture"; err=1; }
grep -q 'authz:' "$fx" 2>/dev/null || { echo "django fixture not neutral shape"; err=1; }
grep -qE '^\s*rbac:' "$fx" 2>/dev/null && { echo "django fixture uses old rbac shape"; err=1; }
exit $err
