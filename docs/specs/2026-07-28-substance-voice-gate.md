# Substance-voice: a shared anti-apelativo product voice for the launch skills

**Status:** design (approved 2026-07-28) · **Scope:** `launch-release` + `launch-feature` · **Bundle:** `growth` (no change)

## Context

The launch skills carry copy voice, but it is scattered and only *encourages*
substance. `launch-feature` has a local `templates/voice.md` (a good compact
Tone/Vocabulary/Structure guide with a banned-words list). `launch-release` has
a richer, theme-driven system (`voice.tone ∈ {calm,bold,playful,formal}`, a
`feature/benefit/evidence` model where **evidence is only "encouraged"**, a
"message-mother" `narrative.yml`, `--audience` tuning). Neither *forces*
substance, and `voice.tone: bold|playful` can drift into hype.

The goal is a **product-led voice that is not apelativo** (not
hype/FOMO/superlative-driven) — the Ogilvy → Basecamp/37signals → Stripe axis,
with the direct-response / "lançamento" school as an explicit anti-reference.
`skills/_shared/` already hosts cross-skill fragments (audit-cache, task-routing,
audit-pre-pass), so a shared substance kit is idiomatic and DRY.

## Goals

- One reusable substance/voice kit both launch skills consume.
- Substance is **forced, not suggested**: evidence default-required; superlative
  without evidence and manufactured FOMO/urgency are cut.
- A cheap **deterministic** check that flags hype/FOMO in generated output.
- Name the north star (Ogilvy/Basecamp/Stripe) and the anti-reference so the
  calibration is explicit for the model.

## Non-goals

- Not a hard block / CI gate — the lint is **advisory** (flag-for-review),
  matching the LLM-driven nature and avoiding false positives (a legit "unlock
  the door").
- Not rewriting the 12 theme YAMLs — tone calibration is an applied rule, not a
  per-theme edit.
- No new bundle wiring (`growth` already carries both skills).

## Design

### 1. `skills/_shared/substance-voice.md` (new — the reusable core)

- **North star / anti-reference:** product-led, respect the reader; north =
  Ogilvy, Basecamp/37signals, Stripe; anti-reference = direct-response /
  "lançamento" hype.
- **Substance rule:** every claim names a concrete outcome, behavior change, or
  number; a superlative without evidence is cut.
- **Evidence default-required:** no metric → describe the concrete behavior;
  **never fabricate a number.**
- **Banned vocabulary** (superlative/hype, EN + PT: revolutionize, unlock,
  seamless, game-changer, synergy, revolucionário, incrível, poderoso,
  definitivo, …) **+ FOMO/urgency** (don't miss, last chance, não perca, última
  chance, vagas limitadas, agora ou nunca).
- **CTA:** single, explicit, no manufactured urgency.
- **Tone calibration:** default *calm/measured*; `bold` only with evidence;
  `playful` opt-in per brand.
- **Audience restraint:** developer/technical → more restraint, mechanism before
  benefit.
- Overridable at `docs/marketing/substance-voice.md`.

### 2. `skills/_shared/substance-lint.sh` (new — the deterministic gate)

Scans a file or directory of generated output for the banned/hype/FOMO lists
(regex, EN + PT, case-insensitive) and **reports hits with file:line** for the
author to revise or confirm. Advisory: prints findings; a `--strict` flag may
exit non-zero for callers that want it, but the default is report-only.
Independently testable.

### 3. `skills/launch-release/SKILL.md` (edit)

- Reference `_shared/substance-voice.md` as the governing voice.
- Flip `evidence` from "encouraged" to **default-required** in the
  feature/benefit/evidence model.
- Add a **mandatory pre-publish self-check**: each headline/benefit must name a
  concrete outcome or number, or be revised.
- Add a step to **run `substance-lint.sh` over the rendered output** and revise
  flagged files.
- Note the tone calibration (bold needs evidence; playful opt-in).

### 4. `skills/launch-feature/SKILL.md` + `templates/voice.md` (edit)

- `voice.md`'s Tone + Vocabulary sections **fold into** the shared fragment (a
  reference replaces the duplicated lists); the per-post **Structure (hook)**
  stays local (it is channel-specific).
- Add the same `substance-lint.sh` run step after rendering.

### 5. Tests

- `tests/test_substance_lint.sh` (new): the lint flags a fixture containing
  hype/FOMO, and passes on sober copy; covers EN + PT tokens.
- Extend a structural check (in the same test) that both `SKILL.md` files
  reference `_shared/substance-voice.md` and invoke `substance-lint.sh`.

## Verification

- `bash tests/test_substance_lint.sh` → green (flags hype fixture, passes sober
  fixture, both SKILL.md wired).
- `bash tests/test_bundles.sh` → green (`growth` unchanged).
- Manual: run each launch skill against a fixture ref and confirm the lint step
  flags an injected superlative.

## Follow-ups / notes

- A future `--strict` CI usage of the lint could gate marketing docs in repos
  that want it — out of scope here.
- PT-name cleanup of `launch-feature` templates remains a separate task.
