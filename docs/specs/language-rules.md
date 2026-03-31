# Spec: Language Rules

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-03-30 |
| **Author** | <!-- Your name --> |
| **Status** | Implemented |
| **Roadmap** | RM-005 |
| **RFC** | N/A |

## Problem Statement

AI coding assistants default to the conversation language when creating artifacts (specs, ADRs,
commit messages, code comments, UI copy), requiring constant correction from developers who work
in a language other than English. Additionally, projects have different language requirements:
some are English-only, others need documentation in a regional language while keeping code
identifiers in English, and some have separate requirements for user-facing content.

Octopus had no mechanism to declare language requirements per project, resulting in:
- Repetitive manual corrections every session
- No enforcement for teams where multiple developers interact with the AI in different languages
- No differentiation between artifact types (docs vs. code vs. UI)

## Goals

1. `rules/common/language.md` becomes a behavioral detection rule — the AI reads project context to determine the appropriate language rather than defaulting to conversation language
2. New `language:` field in `.octopus.yml` with optional `docs:`, `code:`, and `ui:` sub-keys for explicit per-project configuration
3. When `language:` is configured, `setup.sh` generates `language.local.md` in each configured CA's rules directory
4. Project-level rule overrides via `.octopus/rules/` directory — any `.local.md` file placed there is distributed by `setup.sh` to all configured agents automatically
5. Works cross-CA: native-rules agents (Claude) receive per-file symlinks + generated `.local.md`; concatenated agents (Copilot, Codex, Antigravity) receive the override content appended last

## Non-Goals

- Do not auto-detect language at `setup.sh` runtime (heuristic detection is delegated to the AI at session time, not to the setup script)
- Do not validate language code values (any string is accepted)
- Do not support language configuration per-agent (one config applies to all agents)

## Design

### Overview

Two complementary mechanisms work together:

1. **Behavioral detection rule** (`rules/common/language.md`): instructs the AI to infer project language from context signals (existing docs, git history, translation files) rather than from conversation language. Code identifiers remain English regardless.

2. **Project override** (`language:` in `.octopus.yml` or `.octopus/rules/common/language.local.md`): when explicit configuration is needed, `setup.sh` generates a `language.local.md` file alongside the symlinked `language.md`. The `.local.md` file takes full precedence.

### `language:` Configuration

```yaml
# Short form
language: en

# Per-scope form
language:
  docs: pt-br    # specs, ADRs, commits, PRs
  code: en       # code comments (identifiers always en)
  ui: pt-br      # user-facing messages, UI copy
```

### Rule Delivery Changes

`deliver_rules()` now creates per-file symlinks (one per `.md` file) instead of a single directory symlink. This allows `language.local.md` to coexist as a real file alongside the symlinked `language.md`.

### `.octopus/` Project Overrides Directory

`.octopus/rules/common/language.local.md` (and any other `.local.md` file under `.octopus/rules/`) serves as a project-level override. `setup.sh` distributes these files to all configured agents, avoiding duplication.

Priority: `.octopus/rules/common/language.local.md` > `language:` config > auto-detection.

## Backward Compatibility

- Projects without `language:` and without `.octopus/rules/` receive only the behavioral detection rule — effective behavior is the same as before (defaults to English when no signals found)
- Existing per-directory symlinks are transparently replaced by per-file symlinks — no consumer-visible change

## Context for Agents

**Knowledge modules**: N/A
**Implementing roles**: N/A
**Related ADRs**: N/A
**Skills needed**: N/A

## Testing Strategy

- `test_language_detection`: project without explicit `language:` → AI infers from context
- `test_language_shortform`: manifest with `language: pt-br` → `language.local.md` generated with Portuguese specification
- `test_language_perscope`: manifest with `language: { docs: pt-br, code: en, ui: pt-br }` → `language.local.md` contains per-scope overrides
- `test_language_projectoverride`: `.octopus/rules/common/language.local.md` present → takes precedence over YAML config
- `test_language_absent`: manifest without `language:` → only base `language.md` delivered

## Risks

- AI agents may not consistently honor language rules if trained on predominantly English data. Mitigation: provide explicit examples in the generated `language.local.md` to strengthen adherence.
- Cross-CA delivery (Copilot, Codex, Antigravity) appends override content to concatenated rules — may cause conflicts if those agents have their own language defaults. Mitigation: test each agent and adjust precedence as needed.

## Changelog

- **2026-03-30** — Initial draft
