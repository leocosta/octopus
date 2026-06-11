#!/usr/bin/env bash
# tests/test_model_tiering.sh — RM-130: audit skills run on a cheap model tier so
# the codereview/pr-review fan-out stops paying Opus for ~6 agents. Each audit
# declares `model:` in its SKILL.md frontmatter (the field skill_matcher.py reads
# and the codereview dispatch honors); adjudicating roles stay on Opus.
#
# Static assertions — no LLM, no setup. Locks the tier policy as a regression guard.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
check() { local d="$1"; shift; if "$@"; then echo "PASS: $d"; PASS=$((PASS + 1)); else echo "FAIL: $d"; FAIL=$((FAIL + 1)); fi; }

# Tier of an audit skill = the value of its `model:` frontmatter line.
tier_of() { grep -m1 '^model:[[:space:]]' "$DIR/skills/audit-$1/SKILL.md" 2>/dev/null | sed 's/^model:[[:space:]]*//'; }

DOMAIN_AUDITS="security money tenant contracts all"   # reason over the diff → sonnet
SIGNAL_AUDITS="grounding verification style config fleet"  # mechanical → haiku

# 1. Every audit declares a tier, and it is never Opus (the whole point).
t_all_declared() {
  local s t
  for s in $DOMAIN_AUDITS $SIGNAL_AUDITS; do
    t="$(tier_of "$s")"
    [[ -n "$t" ]] || { echo "    audit-$s has no model:" >&2; return 1; }
    [[ "$t" != "opus" ]] || { echo "    audit-$s is on opus" >&2; return 1; }
  done
}
check "every audit-* skill declares a non-Opus model tier" t_all_declared

# 2. Domain audits on sonnet (capable enough for money/tenant logic).
t_domain_sonnet() {
  local s; for s in $DOMAIN_AUDITS; do [[ "$(tier_of "$s")" == "sonnet" ]] || { echo "    audit-$s != sonnet" >&2; return 1; }; done
}
check "domain audits (security/money/tenant/contracts/all) are sonnet" t_domain_sonnet

# 3. Signal/config audits on haiku (mechanical passes).
t_signal_haiku() {
  local s; for s in $SIGNAL_AUDITS; do [[ "$(tier_of "$s")" == "haiku" ]] || { echo "    audit-$s != haiku" >&2; return 1; }; done
}
check "signal/config audits (grounding/verification/style/config/fleet) are haiku" t_signal_haiku

# 4. Adjudicating roles stay on Opus — RM-130 reserves Opus for them, not audits.
t_roles_opus() {
  local r; for r in architect dba security; do
    grep -qE '^model:[[:space:]]*opus$' "$DIR/roles/$r.md" || { echo "    role $r is not opus" >&2; return 1; }
  done
}
check "adjudicating roles (architect/dba/security) stay opus" t_roles_opus

# 5. The codereview dispatch actually routes audits by their declared tier (wording guard).
t_codereview_wording() {
  grep -q 'model:` frontmatter' "$DIR/commands/codereview.md" && grep -q 'RM-130' "$DIR/commands/codereview.md"
}
check "codereview.md dispatches audits on their declared model tier (RM-130)" t_codereview_wording

echo "--------------------------------------------------"
echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
