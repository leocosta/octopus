# launch-feature — email (HTML) + WhatsApp announcement channels

**Status:** design (approved 2026-07-27) · **Scope:** extend `launch-feature` · **Bundle:** `growth` (no change)

## Context

The team needs to announce newly developed features to their contact list by
**email and WhatsApp**, written like a professional SaaS copywriter, with
**professional (HTML) email marketing** output.

Today that recipe is split across two skills and neither delivers it:

- `launch-feature` is feature-driven and holds the copywriting craft (`voice.md`,
  `marketer-hooks.md`, the `marketer` role), and already has a `--channels`
  selector with one template per channel. But its email is a **markdown
  skeleton** (`channels/email-lancamento.md`) and it has **no WhatsApp**; its
  channels are acquisition-oriented (Instagram, LinkedIn, video, LP).
- `launch-release` has an **HTML email** (`html/email.html.tmpl`) and a
  **WhatsApp** template, but is **release/version-driven** (input = tags/ranges),
  aimed at existing users, and spread across 9 channels + 12 themes.

**Decision:** extend `launch-feature` rather than build a third (overlapping)
skill or merge the two launch skills. The channel mechanism already fits — a new
channel is a template file plus `--channels` selection.

## Goals

- Run `launch-feature <ref> --channels=email,whatsapp` to produce, from a
  feature, a **send-ready professional HTML email** and a **WhatsApp** message.
- Email copy authored like a **SaaS copywriter** (benefit-led, no inflation).
- Keep the full existing launch kit working unchanged.

## Non-goals

- Not merging `launch-feature` and `launch-release`.
- **No `_shared/` extraction.** The chosen single brand-token email diverges from
  `launch-release`'s themed email, and the WhatsApp placeholders differ too, so a
  shared fragment would be premature abstraction. This stays a self-contained
  extension of `launch-feature`.
- No 12-theme system; no plain-text multipart (essentials tier, not "full").

## Design

### Locked decisions

1. **HTML email = one brand-token template** (not the 12-theme system).
2. **Email anatomy = copy + deliverability essentials**: 2–3 subject-line
   variants, preheader, benefit-led body, single CTA, signoff, footer with
   unsubscribe + company address, UTM-tagged links, optional `{{FIRST_NAME}}`.
3. **SaaS voice = embedded framework + `marketer` role** (not voice-only, not
   role-only).

### New / changed files (all under `skills/launch-feature/`)

- **`templates/channels/whatsapp.md`** (new) — bold headline, 1–2 highlights, one
  CTA link, signature. Feature/brand-driven placeholders; self-contained.
- **`templates/channels/email.html.tmpl`** (new) — single brand-token HTML shell:
  table-based, inline styles, CTA button, footer (unsubscribe + company address),
  UTM-tagged links. Placeholders filled from brand tokens + authored copy.
- **`templates/channels/email.md`** (rename of `email-lancamento.md`) — the copy
  artifact / plain source (subject variants, preheader, body, CTA, signoff). Both
  `email.md` and `email.html` are emitted.
- **`templates/brand.yml`** (new) — email brand tokens: accent hex, background,
  text, muted; display + body font; logo path; CTA label + href base; company
  name + postal address (CAN-SPAM); unsubscribe href; UTM base params. Override
  at `docs/marketing/brand.yml`. (`brand.md` stays for prose brand guidance.)
- **`templates/email-saas-framework.md`** (new) — the SaaS copy framework:
  subject-line formulas, benefit-over-feature translation, the
  "what changed / why it matters / what to do" body structure, subject/preheader
  length discipline. Layered over `voice.md`, followed by the `marketer` role.
- **`SKILL.md`** (edit) —
  - Description/positioning: feature-driven announcements across **acquisition
    and lifecycle** channels (email/WhatsApp), not acquisition-only.
  - Channel list adds `whatsapp` and the HTML `email`; render steps for the HTML
    shell (brand tokens, UTM, footer) and WhatsApp.
  - Copy step references `email-saas-framework.md`.

### Channel selection UX

`--channels=email,whatsapp` renders only those. Default (no flag) still renders
every channel whose template/override exists. The email channel emits both
`email.md` (copy) and `email.html` (send-ready).

## Testing

Add **`tests/test_launch_feature.sh`** (none exists today). Structural, no real
send. Assert `--channels=email,whatsapp` on a fixture ref:

- emits `email.md`, `email.html`, and `whatsapp.md`;
- `email.html` contains the CTA button, an unsubscribe link, and UTM params;
- 2–3 subject-line variants present in `email.md`;
- brand tokens are filled (no leftover `{{...}}`);
- `--dry-run` prints without writing.

## Out of scope / follow-ups

- The other `launch-feature` templates keep Portuguese names (`copy-lp`,
  `roteiro-video`, `changelog-vendedor`, …), which violate the English-only repo
  rule — a separate cleanup, not folded in here (only the email file is renamed).
- Plain-text multipart, segmentation guidance, and a shared channel fragment with
  `launch-release` are deferred.
