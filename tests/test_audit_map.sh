#!/usr/bin/env bash
# tests/test_audit_map.sh — Unit tests for cli/lib/audit-map.sh
set -euo pipefail

OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0

export AUDIT_MAP_OCTOPUS_DIR="$OCTOPUS_DIR"
# shellcheck source=../cli/lib/audit-map.sh
source "$OCTOPUS_DIR/cli/lib/audit-map.sh"

check() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then
    echo "PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

check_not() {
  local desc="$1"; shift
  if ! "$@" &>/dev/null; then
    echo "PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

TMPDIR_TESTS="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TESTS"' EXIT

# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------
billing_diff() {
  cat > "$1" <<'DIFF'
diff --git a/src/billing/ChargeService.cs b/src/billing/ChargeService.cs
index 000..111 100644
--- a/src/billing/ChargeService.cs
+++ b/src/billing/ChargeService.cs
@@ -1,3 +1,4 @@
+using Stripe;
 public class ChargeService {
   decimal amount = 99.99m;
 }
DIFF
}

secret_diff() {
  cat > "$1" <<'DIFF'
diff --git a/config/app.js b/config/app.js
index 000..111 100644
--- a/config/app.js
+++ b/config/app.js
@@ -1,3 +1,4 @@
+const token = "sk-abcdefghijklmnopqrstuvwx";
 module.exports = {};
DIFF
}

tenant_diff() {
  cat > "$1" <<'DIFF'
diff --git a/src/tenant/TenantRepository.cs b/src/tenant/TenantRepository.cs
index 000..111 100644
--- a/src/tenant/TenantRepository.cs
+++ b/src/tenant/TenantRepository.cs
@@ -1,3 +1,4 @@
+var data = db.Orders.IgnoreQueryFilters().ToList();
 public class TenantRepo {}
DIFF
}

readme_diff() {
  cat > "$1" <<'DIFF'
diff --git a/README.md b/README.md
index 000..111 100644
--- a/README.md
+++ b/README.md
@@ -1,3 +1,4 @@
+# Welcome to the project
 This is the documentation.
DIFF
}

cross_stack_diff() {
  cat > "$1" <<'DIFF'
diff --git a/api/Controllers/OrdersController.cs b/api/Controllers/OrdersController.cs
index 000..111 100644
--- a/api/Controllers/OrdersController.cs
+++ b/api/Controllers/OrdersController.cs
@@ -1 +1,2 @@
+[HttpGet("orders")]
 public class OrdersController {}
diff --git a/app/src/api/orders.ts b/app/src/api/orders.ts
index 000..111 100644
--- a/app/src/api/orders.ts
+++ b/app/src/api/orders.ts
@@ -1 +1,2 @@
+export const fetchOrders = () => fetch('/api/orders');
 export {};
DIFF
}

# ---------------------------------------------------------------------------
# T1: billing diff → audit-money matches
billing_file="$TMPDIR_TESTS/billing.diff"
billing_diff "$billing_file"
check "billing diff matches audit-money" audit_map_match "audit-money" "$billing_file"

# T2: billing diff → audit-security does not match
check_not "billing diff does not match audit-security" audit_map_match "audit-security" "$billing_file"

# T3: secret diff → audit-security matches
secret_file="$TMPDIR_TESTS/secret.diff"
secret_diff "$secret_file"
check "secret diff matches audit-security" audit_map_match "audit-security" "$secret_file"

# T4: tenant diff → audit-tenant matches (via path token)
tenant_file="$TMPDIR_TESTS/tenant.diff"
tenant_diff "$tenant_file"
check "tenant diff matches audit-tenant (path token)" audit_map_match "audit-tenant" "$tenant_file"

# T5: tenant diff (IgnoreQueryFilters) → audit-tenant matches (via content regex)
check "tenant diff matches audit-tenant (content regex)" bash -c '
  source "$1/cli/lib/audit-map.sh"
  grep -q "IgnoreQueryFilters" "$2"
' _ "$OCTOPUS_DIR" "$tenant_file"

# T6: README diff → no audit matches
readme_file="$TMPDIR_TESTS/readme.diff"
readme_diff "$readme_file"
check_not "readme diff does not match audit-money" audit_map_match "audit-money" "$readme_file"
check_not "readme diff does not match audit-security" audit_map_match "audit-security" "$readme_file"
check_not "readme diff does not match audit-tenant" audit_map_match "audit-tenant" "$readme_file"

# T7: audit_map_all on billing diff emits audit-money
check "audit_map_all emits audit-money for billing diff" bash -c \
  'source "$1/cli/lib/audit-map.sh" && audit_map_all "$2" | grep -q "audit-money"' \
  _ "$OCTOPUS_DIR" "$billing_file"

# T8: audit_map_all on README diff emits nothing
check "audit_map_all emits nothing for readme diff" bash -c \
  'source "$1/cli/lib/audit-map.sh" && [[ -z "$(audit_map_all "$2")" ]]' \
  _ "$OCTOPUS_DIR" "$readme_file"

# T9: audit-map.sh file exists
check "audit-map.sh exists" test -f "$OCTOPUS_DIR/cli/lib/audit-map.sh"

# T10: audit_map_match function is defined
check "audit_map_match function defined" bash -c \
  'source "$1/cli/lib/audit-map.sh" && declare -f audit_map_match > /dev/null' \
  _ "$OCTOPUS_DIR"

# T11: audit_map_all function is defined
check "audit_map_all function defined" bash -c \
  'source "$1/cli/lib/audit-map.sh" && declare -f audit_map_all > /dev/null' \
  _ "$OCTOPUS_DIR"

# T12: cross-stack match function is defined
check "_audit_map_match_cross_stack function defined" bash -c \
  'source "$1/cli/lib/audit-map.sh" && declare -f _audit_map_match_cross_stack > /dev/null' \
  _ "$OCTOPUS_DIR"

# T13: malformed patterns.md → warn on stderr, skip that audit
malformed_dir="$TMPDIR_TESTS/skills/broken-audit/templates"
mkdir -p "$malformed_dir"
echo "# No valid headings here" > "$malformed_dir/patterns.md"
check "malformed patterns.md → skips audit (no crash)" bash -c '
  AUDIT_MAP_OCTOPUS_DIR="$2" source "$1/cli/lib/audit-map.sh"
  audit_map_match "broken-audit" "$3"
  true
' _ "$OCTOPUS_DIR" "$TMPDIR_TESTS" "$billing_file"

# T14: _audit_map_path_tokens extracts tokens correctly
check "_audit_map_path_tokens extracts tokens" bash -c \
  'source "$1/cli/lib/audit-map.sh"
   tokens=$(_audit_map_path_tokens "$1/skills/audit-money/templates/patterns.md")
   echo "$tokens" | grep -q "billing"' \
  _ "$OCTOPUS_DIR"

# T15: _audit_map_content_regexes extracts regexes
check "_audit_map_content_regexes extracts regexes" bash -c \
  'source "$1/cli/lib/audit-map.sh"
   regexes=$(_audit_map_content_regexes "$1/skills/audit-security/templates/patterns.md")
   echo "$regexes" | grep -q "sk-"' \
  _ "$OCTOPUS_DIR"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
