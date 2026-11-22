#!/usr/bin/env bash
# Regression test: the edit hooks (auto-format, typecheck) run tools that
# execute project code — eslint/prettier configs, MSBuild targets, mypy
# plugins — and used to fetch packages with `npx --yes`. A hook must never:
#   - run them on a file outside the open project (an edit in a clone under
#     /tmp would run THAT clone's code, approved by nobody);
#   - download and run a package from the npm registry (`npx --yes tsc`
#     installs the unrelated, deprecated `tsc` package, not TypeScript).
# Also: format-check read a top-level `file_path`, which Claude Code never
# sends (the tool input is under tool_input), so it never fired (#245 class).
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS="$DIR/hooks"
PASS=0; FAIL=0
check() { local d="$1"; shift; if "$@"; then echo "PASS: $d"; PASS=$((PASS + 1)); else echo "FAIL: $d"; FAIL=$((FAIL + 1)); fi; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
project="$tmp/project"; outside="$tmp/outside"; fakebin="$tmp/bin"; log="$tmp/calls.log"
mkdir -p "$project" "$outside" "$fakebin"
git -C "$project" init -q

# Fake tools: record every invocation (name + args) instead of running anything.
for t in prettier npx mypy dotnet; do
  printf '#!/usr/bin/env bash\necho "%s $*" >> %q\n' "$t" "$log" > "$fakebin/$t"
  chmod +x "$fakebin/$t"
done
# The real python3/git/etc. stay reachable after the fake bin.
export PATH="$fakebin:$PATH"

payload() { python3 -c 'import json,sys; print(json.dumps({"tool_name":"Edit","tool_input":{"file_path":sys.argv[1]}}))' "$1"; }
# run <hook> <file> — from inside the project, as Claude Code would.
run() { : > "$log"; (cd "$project" && CLAUDE_PROJECT_DIR="$project" bash "$HOOKS/$1" <<<"$(payload "$2")" >/dev/null 2>&1); }

printf 'const a = 1\n' > "$project/a.js";  printf 'const a = 1\n' > "$outside/a.js"
printf 'x = 1\n'       > "$project/a.py";  printf 'x = 1\n'       > "$outside/a.py"
printf 'let a = 1\n'   > "$project/a.ts";  printf 'let a = 1\n'   > "$outside/a.ts"
printf 'class A {}\n'  > "$outside/A.cs";  printf '<Project/>\n'  > "$outside/x.csproj"

# ── inside the project: the tools still run ──────────────────────────────────
t_inside_runs() { run post-tool-use/auto-format.sh "$project/a.js"; grep -q '^prettier ' "$log"; }
check "auto-format still formats a file inside the project" t_inside_runs

# ── outside the project: nothing runs ────────────────────────────────────────
t_outside_format() { run post-tool-use/auto-format.sh "$outside/a.js"; [[ ! -s "$log" ]]; }
check "auto-format runs nothing on a file outside the project" t_outside_format

t_outside_typecheck() {
  local f bad=0
  for f in "$outside/a.py" "$outside/A.cs" "$outside/a.ts"; do
    run post-tool-use/typecheck.sh "$f"; [[ -s "$log" ]] && { echo "  ran: $(cat "$log")"; bad=1; }
  done
  return $bad
}
check "typecheck runs nothing (mypy, dotnet build, tsc) outside the project" t_outside_typecheck

t_outside_symlink() {
  ln -s "$outside" "$project/vendored"
  run post-tool-use/auto-format.sh "$project/vendored/a.js"; local rc=$?
  rm -f "$project/vendored"; [[ ! -s "$log" ]]
}
check "a symlink inside the project that points outside does not count as inside" t_outside_symlink

# ── never fetch from the registry ────────────────────────────────────────────
t_no_npx_fetch() {
  rm -f "$fakebin/prettier"
  run post-tool-use/auto-format.sh "$project/a.js"
  run post-tool-use/typecheck.sh "$project/a.ts"
  printf '#!/usr/bin/env bash\necho "prettier $*" >> %q\n' "$log" > "$fakebin/prettier"; chmod +x "$fakebin/prettier"
  ! grep -q -- '--yes' "$log" && ! grep -rq -- 'npx --yes' "$HOOKS"
}
check "no hook runs npx --yes (no package is downloaded and executed)" t_no_npx_fetch

t_npx_local_only() {
  rm -f "$fakebin/prettier"
  run post-tool-use/auto-format.sh "$project/a.js"
  printf '#!/usr/bin/env bash\necho "prettier $*" >> %q\n' "$log" > "$fakebin/prettier"; chmod +x "$fakebin/prettier"
  grep -q -- 'npx --no-install prettier' "$log"
}
check "npx is only ever asked for an already-installed package (--no-install)" t_npx_local_only

# ── format-check reads the real payload ──────────────────────────────────────
t_format_check_fires() {
  local o
  o="$(cd "$project" && bash "$HOOKS/pre-tool-use/format-check.sh" <<<"$(payload "$project/api-design.md")" 2>&1)"
  grep -q 'Consider placing design docs in docs/' <<<"$o"
}
check "format-check reads tool_input.file_path (it never fired before)" t_format_check_fires

echo ""
echo "hook tool scope: $PASS passed, $FAIL failed."
[[ "$FAIL" -eq 0 ]]
