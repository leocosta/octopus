#!/usr/bin/env bash
# Static structural guard for the launch-feature email + WhatsApp channels.
# The skill is LLM-driven (SKILL.md), so this asserts the templates and wiring
# exist and are well-formed — it does not run the skill end-to-end.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
S="$DIR/skills/launch-feature"
CH="$S/templates/channels"
PASS=0; FAIL=0
check() { local d="$1"; shift; if "$@"; then echo "PASS: $d"; PASS=$((PASS+1)); else echo "FAIL: $d"; FAIL=$((FAIL+1)); fi; }

# WhatsApp channel
t_wa() {
  [[ -f "$CH/whatsapp.md" ]] \
    && grep -qF 'channel: whatsapp' "$CH/whatsapp.md" \
    && grep -qF '{{CTA_URL_WITH_UTM}}' "$CH/whatsapp.md"
}
check "whatsapp channel exists with CTA+UTM placeholder" t_wa

echo ""
echo "launch-feature channels: $PASS passed, $FAIL failed."
[[ "$FAIL" -eq 0 ]]
