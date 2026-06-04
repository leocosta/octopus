#!/usr/bin/env bash
# tests/test_stack_detection.sh
# RM-138 — _detect_stack scans a repo and emits the matching profile-bundle
# names (stack-<lang>, db-<engine>). Extract the self-contained function from
# cli/lib/setup.sh (single column-0 `}`) and run it against fixtures. A C#-only
# repo must NOT detect python/typescript or a DB it doesn't use. Grep/exit-code
# assertions, per project convention.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
eval "$(sed -n '/^_detect_stack()/,/^}/p' "$SCRIPT_DIR/cli/lib/setup.sh")"
PASS=0; FAIL=0
has()  { grep -qx "$2" <<<"$1"; }
check() { local d="$1"; shift; if "$@"; then echo "PASS: $d"; PASS=$((PASS+1)); else echo "FAIL: $d"; FAIL=$((FAIL+1)); fi; }

# --- fixture 1: C# + MSSQL only ------------------------------------------
F1=$(mktemp -d)
mkdir -p "$F1/src"
printf '<Project><ItemGroup><PackageReference Include="Microsoft.Data.SqlClient" Version="5"/></ItemGroup></Project>\n' > "$F1/src/Api.csproj"
out="$(_detect_stack "$F1")"
check "C# repo → stack-csharp"          has "$out" "stack-csharp"
check "MSSQL signal → db-mssql"         has "$out" "db-mssql"
check "C# repo → NOT stack-python"      bash -c "! grep -qx stack-python <<<\"$out\""
check "C# repo → NOT stack-typescript"  bash -c "! grep -qx stack-typescript <<<\"$out\""
check "C#+MSSQL → NOT db-postgres"      bash -c "! grep -qx db-postgres <<<\"$out\""
rm -rf "$F1"

# --- fixture 2: Node/TS + Postgres ---------------------------------------
F2=$(mktemp -d)
printf '{ "dependencies": { "pg": "^8", "express": "^4" } }\n' > "$F2/package.json"
printf '{}\n' > "$F2/tsconfig.json"; : > "$F2/index.ts"
out="$(_detect_stack "$F2")"
check "TS repo → stack-typescript"      has "$out" "stack-typescript"
check "pg dep → db-postgres"            has "$out" "db-postgres"
check "TS repo → NOT stack-csharp"      bash -c "! grep -qx stack-csharp <<<\"$out\""
rm -rf "$F2"

# --- fixture 3: Python + Redis -------------------------------------------
F3=$(mktemp -d)
printf '[project]\nname="x"\n' > "$F3/pyproject.toml"
printf 'redis-py==5.0\n' > "$F3/requirements.txt"
out="$(_detect_stack "$F3")"
check "Python repo → stack-python"      has "$out" "stack-python"
check "redis-py → db-redis"             has "$out" "db-redis"
rm -rf "$F3"

# --- fixture 4: empty repo → nothing -------------------------------------
F4=$(mktemp -d)
out="$(_detect_stack "$F4")"
check "empty repo → no profiles"        test -z "$out"
rm -rf "$F4"

echo "-----------------------------------------"
echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
