#!/usr/bin/env bash
set -u
f="plugins/mega-sdd/skills/scan-codebase/references/deep-scan-prompts.md"
hits=$(grep -nE 'app/Http|app/Providers|resources/views|resources/js|resources/css|config/(auth|permission|fortify|jetstream)\.php|routes/auth\.php|Gate::define|\$routeMiddleware|\$policies|@extends|@heroicons|@fortawesome|blade|yajra/laravel|Kernel\.php|AuthServiceProvider|RoleSeeder|Spatie..Permission|guard name|Common Laravel| app/ | routes/ | resources/ ' "$f")
if [ -n "$hits" ]; then echo "Laravel tokens still in generic prompts:"; echo "$hits"; exit 1; fi
exit 0
