# Spec: Lazy Skill Activation

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-04-22 |
| **Author** | Leonardo Costa |
| **Status** | Implemented (2026-04-22) |
| **RFC** | N/A |
| **Roadmap** | RM-022 |

## Problem Statement

Octopus bundles skills into a single concatenated file for agents that do not support native skill loading (Copilot, Codex, Gemini, OpenCode). Every skill in the active bundle is appended in full, regardless of whether the project uses the skill's domain. A repo with no Cypress files still loads the full `e2e-testing` skill; a SaaS without billing still loads `money-review`. This inflates the context window by an estimated 40–70%, increasing costs and reducing the signal-to-noise ratio of the instructions file.

## Goals

- Introduce a `triggers:` frontmatter block in `SKILL.md` that declares when the skill is relevant (by file paths, keywords, or manifest tools).
- Modify `setup.sh` to evaluate those triggers at setup time and replace non-matching skills with a 3-line stub in the concatenated output.
- Reduce the concatenated output size by ≥ 40% for a typical project that activates fewer than half the available skills.
- Maintain full backward compatibility: skills without `triggers:` always produce full content.
- Ship `triggers:` for the 6 most domain-specific skills in the default skill library.

## Non-Goals

- Dynamic (runtime) trigger evaluation — the stub is determined at `octopus setup` time only.
- Trigger support for template-mode agents (Claude Code) — they use native skill commands.
- Auto-discovery of trigger patterns from skill content — patterns are authored manually per skill.
- Parallelising setup beyond what bash subshells already provide.

## Design

### Overview

**Skill triggers** introduce a `triggers:` block in each `SKILL.md` frontmatter. When `octopus setup` generates a concatenated output (Copilot, Codex, Gemini, OpenCode), it evaluates each skill's triggers against the project at that moment:

- **Match → full content.** The skill body is appended as today.
- **No match → 3-line stub.** The stub names the skill, states its activation conditions, and tells the agent to `Read octopus/skills/<name>/SKILL.md` if the conditions arise mid-session.
- **No `triggers:` field → always full** (backward compatible; existing skills keep current behaviour).

Trigger evaluation runs entirely in `setup.sh` using static project signals:

| Trigger type | Evaluated by |
|---|---|
| `paths:` | `git ls-files \| grep -E <pattern>` (any match → active) |
| `keywords:` | grep across README, `package.json`, `pyproject.toml`, `docs/` |
| `tools:` | presence of the tool name in the manifest's `tools:` list |

The 3-line stub format:

```
# <name> (inactive — triggers not matched at setup)
Activate when: <human-readable trigger summary>.
Full protocol: read `octopus/skills/<name>/SKILL.md` if conditions arise.
```

Claude Code agents are unaffected — skills are delivered as native commands, not concatenated.

### Detailed Design

**Frontmatter schema (`SKILL.md`)**

```yaml
---
name: e2e-testing
description: ...
triggers:
  paths:    ["**/*.spec.ts", "cypress/**", "playwright/**"]
  keywords: ["e2e", "end-to-end", "playwright", "cypress"]
  tools:    ["Bash"]
---
```

All three keys are optional; omitting a key is equivalent to an empty list. A skill without any `triggers:` block is always included at full content (backward compatible).

---

**Trigger evaluation in `setup.sh`**

New helper `_skill_triggers_match <skill_name>` returns 0 (match) or 1 (no match):

```bash
_skill_triggers_match() {
  local skill_name="$1"
  local skill_file="$OCTOPUS_DIR/skills/${skill_name}/SKILL.md"

  # Extract triggers block via python3 (reuses existing frontmatter parser pattern)
  local paths keywords tools
  paths=$(python3 - "$skill_file" <<'PYEOF'
import sys, re
...   # parse triggers.paths list → space-separated patterns
PYEOF
)

  # paths: any git-tracked file matches any pattern
  for pat in $paths; do
    git ls-files | grep -qE "$pat" && return 0
  done

  # keywords: grep in README*, package.json, pyproject.toml, docs/
  for kw in $keywords; do
    grep -rqiE "$kw" README* package.json pyproject.toml docs/ 2>/dev/null && return 0
  done

  # tools: any tool name present in manifest tools: list
  for tool in $tools; do
    [[ " ${OCTOPUS_MANIFEST_TOOLS[*]:-} " == *" $tool "* ]] && return 0
  done

  return 1  # no trigger matched → stub
}
```

---

**Changes to `concatenate_from_manifest`**

```bash
for skill in "${OCTOPUS_SKILLS[@]}"; do
  local skill_file="$OCTOPUS_DIR/skills/$skill/SKILL.md"
  [[ -f "$skill_file" ]] || continue

  if _skill_has_triggers "$skill" && ! _skill_triggers_match "$skill"; then
    # emit 3-line stub
    local summary
    summary=$(_skill_triggers_summary "$skill")
    {
      echo ""
      echo "# ${skill} (inactive — triggers not matched at setup)"
      echo "Activate when: ${summary}."
      echo "Full protocol: read \`octopus/skills/${skill}/SKILL.md\` if conditions arise."
    } >> "$full_output"
  else
    echo "" >> "$full_output"
    cat "$skill_file" >> "$full_output"
  fi
done
```

`_skill_has_triggers` checks for the presence of the `triggers:` key (cheap string check). `_skill_triggers_summary` returns a human-readable string built from the trigger lists (e.g. `"paths matching **/*.spec.ts, keywords: e2e, playwright"`).

---

**Which existing skills get `triggers:` added**

| Skill | Trigger signal | Always-on? |
|---|---|---|
| `e2e-testing` | paths: `**/*.spec.ts`, `cypress/**`, `playwright/**` | No |
| `dotnet` | paths: `**/*.csproj`, `**/*.cs` | No |
| `security-scan` | keywords: `auth`, `jwt`, `secret`, `token`, `sql` | No |
| `money-review` | keywords: `price`, `payment`, `invoice`, `stripe`, `billing` | No |
| `tenant-scope-audit` | keywords: `tenant`, `org`, `workspace` | No |
| `cross-stack-contract` | paths: `openapi/**`, `contracts/**` | No |
| `implement`, `debugging`, `receiving-code-review`, `adr`, `feature-lifecycle`, `context-budget` | — | Always-on |

### Migration / Backward Compatibility

Skills without `triggers:` continue to be included in full — zero breaking change for existing repos. Bundles need no changes; the feature is opt-in per skill.

For user-defined skills (in `.octopus/skills/`): the `triggers:` field is also read if present, following the same logic. Local skills without the field remain always-active.

The `triggers:` field is silently ignored by agents that use template mode (Claude Code) — they never pass through `concatenate_from_manifest`.

## Implementation Plan

1. **Add `triggers:` parser to `setup.sh`.** Implement `_skill_has_triggers`, `_skill_triggers_match`, and `_skill_triggers_summary` helpers. Cache `git ls-files` in a variable before the skill loop to avoid repeated subprocess calls. No dependencies.
2. **Modify `concatenate_from_manifest` in `setup.sh`.** Replace the skills loop with the conditional stub/full logic that calls the new helpers. Depends on step 1.
3. **Add `triggers:` to the 6 eligible skills** — `e2e-testing`, `dotnet`, `security-scan`, `money-review`, `tenant-scope-audit`, `cross-stack-contract` — each with appropriate `paths` and/or `keywords`. Depends on step 1 (schema defined).
4. **Structural tests in `tests/test_lazy_skill_activation.sh`.** Verify: stub emitted when triggers don't match; full content when they do; skills without `triggers:` always full; backward compatibility with repos lacking `git`. Depends on steps 1 and 2.
5. **Dog-food:** run `octopus setup` on this repo and measure line-count reduction in the concatenated output of a non-Claude-Code agent. Capture findings in `docs/research/YYYY-MM-DD-lazy-skill-dogfood.md`. Merge any protocol issues back into `setup.sh` before the roadmap flip. Depends on steps 1–3.

## Context for Agents

**Knowledge modules**: N/A
**Implementing roles**: backend-specialist (bash), tech-writer (trigger lists for existing skills)
**Related ADRs**: N/A
**Skills needed**: `implement`, `feature-lifecycle`
**Bundle**: N/A — no new skill; changes are in `setup.sh` and existing skill frontmatter

**Constraints**:
- Pure bash + python3 (already used in `setup.sh`) — no new external dependencies
- Backward compatible: skills without `triggers:` must always produce full content, unchanged
- `triggers:` field silently ignored in template-mode agents (Claude Code)
- `git ls-files` output must be cached before the skill loop, not called per-skill
- Glob-to-regex conversion required before passing patterns to `grep -E`

## Testing Strategy

- **Structural tests** in `tests/test_lazy_skill_activation.sh`: build skill fixtures with and without `triggers:`, run `setup.sh` against a temp directory, assert stub vs. full content in the generated output.
- **Dog-food** (implementation step 5): measure real line-count reduction on a concatenated agent output after adding triggers to the 6 eligible skills.
- **Not tested:** stub quality as an agent instruction (LLM-dependent).

## Risks

- **Pattern matching false-negative.** `grep -qE` with YAML glob patterns (e.g. `**/*.spec.ts`) does not work directly as regex — `**` has no special meaning in ERE. The implementation must convert globs to regex (`**` → `.*`, `*` → `[^/]*`, `.` → `\.`) before passing to grep. Naive conversion may stub out relevant skills incorrectly.
- **Repos without git.** `git ls-files` fails outside a git repository. Mitigation: check `git rev-parse --is-inside-work-tree` first; if it fails, treat path triggers as "no match" (conservative fallback = full content).
- **Overly generic keywords.** A keyword like `token` may match any project with a README. Skill maintainers must choose specific-enough keywords to avoid always activating the skill.
- **Setup cost.** Each skill with `triggers:` adds a python3 call + grep per type. With 20 skills and 3 types each, that is ~60 extra operations at setup. Mitigation: cache `git ls-files` output in a variable before the loop; parallelize with subshells if needed.

## Changelog

<!-- Updated as the spec evolves -->
- **2026-04-22** — Initial draft
- **2026-04-22** — Design session completed
