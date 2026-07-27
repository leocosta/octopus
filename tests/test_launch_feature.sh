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

# HTML email shell
t_email_html() {
  [[ -f "$CH/email.html.tmpl" ]] \
    && grep -qF '{{CTA_URL_WITH_UTM}}' "$CH/email.html.tmpl" \
    && grep -qiF 'unsubscribe' "$CH/email.html.tmpl" \
    && grep -qF '{{PREHEADER}}' "$CH/email.html.tmpl"
}
check "email.html.tmpl has CTA(UTM), preheader, unsubscribe" t_email_html

# Email copy (renamed from email-lancamento.md)
t_email_copy() {
  [[ -f "$CH/email.md" ]] \
    && [[ ! -f "$CH/email-lancamento.md" ]] \
    && grep -qiF 'Subject line options' "$CH/email.md" \
    && grep -qF '{{PREHEADER_ONE_SENTENCE}}' "$CH/email.md"
}
check "email.md replaces email-lancamento.md with subject variants + preheader" t_email_copy

echo ""
echo "launch-feature channels: $PASS passed, $FAIL failed."
[[ "$FAIL" -eq 0 ]]
