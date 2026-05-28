#!/usr/bin/env bash
# tests/test_audit_grounding.sh
# Structural tests for the audit-grounding skill, its stop-hook trigger,
# bundle registration, and feature doc. Grep-based, per project convention.
set -euo pipefail
OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$OCTOPUS_DIR/skills/audit-grounding/SKILL.md"
PASS=0; FAIL=0

check() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then
    echo "PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

# --- Task 1: the skill ---------------------------------------------------
check "SKILL.md exists" test -f "$SKILL"
check "declares name audit-grounding" grep -q "name: audit-grounding" "$SKILL"
check "reads the source of truth (CONTEXT.md)" grep -q "CONTEXT.md" "$SKILL"
check "reads the source of truth (docs/adr)" grep -q "docs/adr" "$SKILL"
check "emits invented-convention finding" grep -q "invented-convention" "$SKILL"
check "emits unsupported-domain-fact finding" grep -q "unsupported-domain-fact" "$SKILL"
check "is signal-only (never blocks)" grep -qiE "signal-only|does not block|never block" "$SKILL"

# --- Task 4: feature doc + roadmap --------------------------------------
DOC="$OCTOPUS_DIR/docs/features/audit-grounding.md"
check "feature doc exists" test -f "$DOC"
check "feature doc names the guardrails config" grep -q "guardrails" "$DOC"
check "feature doc names the quality bundle" grep -q "quality" "$DOC"
check "roadmap has RM-088" grep -q "RM-088" "$OCTOPUS_DIR/docs/roadmap.md"

# --- Task 3: bundle registration ----------------------------------------
QBUNDLE="$OCTOPUS_DIR/bundles/quality.yml"
check "audit-grounding listed in quality bundle" grep -q "audit-grounding" "$QBUNDLE"

# --- Task 2: the stop-hook trigger --------------------------------------
HOOK="$OCTOPUS_DIR/hooks/stop/grounding-check.sh"
check "stop hook exists" test -f "$HOOK"
check "stop hook is executable" test -x "$HOOK"
check "hook routes to proposals queue" grep -q "proposals" "$HOOK"
check "hook is non-blocking (exit 0)" grep -q "exit 0" "$HOOK"
check "hook references audit-grounding" grep -q "audit-grounding" "$HOOK"
check "hook registered in hooks.json" grep -q "grounding-check" "$OCTOPUS_DIR/hooks/hooks.json"

echo "PASS=$PASS FAIL=$FAIL"
test "$FAIL" -eq 0
