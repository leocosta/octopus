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

# Brand tokens
t_brand() {
  [[ -f "$S/templates/brand.yml" ]] \
    && grep -qE '^primary:' "$S/templates/brand.yml" \
    && grep -qE '^unsubscribe_url:' "$S/templates/brand.yml" \
    && grep -qE '^utm_' "$S/templates/brand.yml"
}
check "brand.yml has color + unsubscribe + utm tokens" t_brand

# SaaS copy framework
t_framework() {
  [[ -f "$S/templates/email-saas-framework.md" ]] \
    && grep -qiF 'Subject lines' "$S/templates/email-saas-framework.md" \
    && grep -qiF 'what changed' "$S/templates/email-saas-framework.md"
}
check "email-saas-framework.md has subject formulas + body structure" t_framework

# SKILL.md wiring
t_skill() {
  local f="$S/SKILL.md"
  grep -qiF 'lifecycle' "$f" \
    && grep -qF 'whatsapp' "$f" \
    && grep -qF 'email-saas-framework.md' "$f" \
    && grep -qF 'brand.yml' "$f"
}
check "SKILL.md wires channels, framework, brand tokens, lifecycle positioning" t_skill

# --- RM-168: the templates must not hardcode AI tells ----------------------
# The rule of three was not model drift — the form mandated it. Every channel
# shipped exactly three bullets because it offered exactly three slots. These
# guard the regression: a future template edit must not restore a fixed third
# slot or the decorative glyph.

# No fixed third slot in any channel template or the caption reference.
t_no_fixed_triad() {
  ! grep -rqE '(VALUE|POINT|BULLET)[_ ]?(BULLET )?3' "$S/templates/"
}
check "templates: no fixed third bullet slot (rule of three)" t_no_fixed_triad

# No decorative check-mark glyph baked into captions (pattern 17, emoji).
t_no_glyph() {
  ! grep -rqF '✔' "$S/templates/"
}
check "templates: no hardcoded decorative glyph" t_no_glyph

# The replacement must express a variable count, not a new fixed number.
t_variable_count() {
  grep -rqE '\{\{(POINTS|VALUES|BULLETS)_[0-9]_TO_[0-9]\}\}' "$S/templates/"
}
check "templates: bullets use a variable count placeholder" t_variable_count

# The post skeleton is guidance, not a form — structure must be allowed to vary.
t_skeleton_is_guidance() {
  grep -qiE 'vary|not a form|need not|does not have to' "$S/templates/voice.md"
}
check "voice.md: skeleton is guidance, structure may vary" t_skeleton_is_guidance

echo ""
echo "launch-feature channels: $PASS passed, $FAIL failed."
[[ "$FAIL" -eq 0 ]]
