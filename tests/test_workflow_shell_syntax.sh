#!/usr/bin/env bash
# Every `run:` block in .github/workflows/*.yml must be valid shell.
#
# v1.102.1 shipped with an unterminated double quote in build-release.yml's
# "Publish the release" step. `gh release edit --draft=false` on the line above
# had already run, so the release itself was correct — but the job exited 2, and
# every release from then on would have been red for a cosmetic echo. A red
# release build nobody can act on is a signal people learn to ignore.
#
# Nothing validated these fragments: the repo runs no actionlint or yamllint,
# and test_parse_yaml.sh covers .octopus.yml, not workflows. A syntax error here
# is invisible until the workflow next runs — which, for a release workflow,
# means the next release.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW_DIR="$REPO_ROOT/.github/workflows"

if ! python3 -c 'import yaml' 2>/dev/null; then
  echo "SKIP: PyYAML not available — cannot extract run: blocks"
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
manifest="$tmp/manifest.tsv"

# One "<file>\t<job>\t<step>\t<script path>" row per shell `run:` block.
python3 - "$WORKFLOW_DIR" "$tmp" > "$manifest" <<'PYEOF'
import os, sys, yaml

workflow_dir, out_dir = sys.argv[1], sys.argv[2]
n = 0
for name in sorted(os.listdir(workflow_dir)):
    if not name.endswith((".yml", ".yaml")):
        continue
    with open(os.path.join(workflow_dir, name)) as f:
        doc = yaml.safe_load(f)
    for job_name, job in (doc.get("jobs") or {}).items():
        for i, step in enumerate(job.get("steps") or []):
            script = step.get("run")
            if not script:
                continue
            # Only bash/sh steps — a `shell:` of python, pwsh etc. is not ours.
            if (step.get("shell") or "bash").split()[0] not in ("bash", "sh"):
                continue
            n += 1
            path = os.path.join(out_dir, f"{n}.sh")
            with open(path, "w") as f:
                f.write(script)
            print(f"{name}\t{job_name}\t{step.get('name') or f'step {i}'}\t{path}")
PYEOF

pass=0
fail=0
while IFS=$'\t' read -r wf job step path; do
  [[ -n "${path:-}" ]] || continue
  # ${{ }} is substituted by Actions before the shell sees it; swap in a bare
  # token so an expression cannot itself break the parse.
  sed -i 's/\${{[^}]*}}/__GHA_EXPR__/g' "$path"
  if err="$(bash -n "$path" 2>&1)"; then
    pass=$((pass + 1))
  else
    echo "FAIL: $wf / $job / $step"
    echo "      ${err//$path/<step>}"
    fail=$((fail + 1))
  fi
done < "$manifest"

if [[ "$pass" -eq 0 && "$fail" -eq 0 ]]; then
  echo "FAIL: no run: blocks found — the extractor is broken, not the workflows"
  exit 1
fi

echo "--------------------------------------------------"
if [[ "$fail" -gt 0 ]]; then
  echo "PASS=$pass FAIL=$fail"
  exit 1
fi
echo "PASS=$pass FAIL=0 — every workflow run: block parses as shell"
