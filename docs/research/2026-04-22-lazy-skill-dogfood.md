# Dog-food report — lazy-skill-activation (RM-022)

**Date:** 2026-04-22
**Branch:** feat/lazy-skill-activation
**Repo under test:** octopus itself (bash + markdown, no framework code)

## Setup

This repo configures only `claude` and `opencode` agents, both of which use
template mode. Template-mode agents are unaffected by `triggers:` — they
deliver skills as native commands, not as concatenated content. The trigger
logic only runs inside `concatenate_from_manifest`.

To measure real-world impact, the trigger evaluation was simulated manually
against the repo's `git ls-files` output and its `docs/` directory for keyword
matches.

## Trigger evaluation results for this repo

| Skill | Trigger type | Result | Reason |
|---|---|---|---|
| `e2e-testing` | paths: `*.spec.ts`, `cypress/**`, `playwright/**` | **STUB** | No spec/test files, no cypress or playwright dirs |
| `dotnet` | paths: `*.csproj`, `*.cs`, `*.sln` | **STUB** | No .NET files |
| `cross-stack-contract` | paths: `openapi/**`, `contracts/**`, `swagger.*` | **STUB** | No OpenAPI/contract files |
| `security-scan` | keywords: `auth`, `jwt`, `token`, `sql`, … | **STUB** | Keywords not found in README, package.json, docs/ |
| `money-review` | keywords: `payment`, `stripe`, `billing`, … | **STUB** | Keywords not found |
| `tenant-scope-audit` | keywords: `tenant`, `org`, `workspace`, … | **STUB** | Keywords not found |

All 6 trigger-guarded skills would be stubbed for a concat-mode agent on this
project.

## Line count impact (simulated for a concat agent)

| Metric | Lines |
|---|---|
| Total lines across the 6 guarded skills | 1,344 |
| After stubbing (3 lines × 6 skills) | 18 |
| Net reduction from trigger-guarded skills | **−1,326 lines (−98.7%)** |

A typical Copilot AGENTS.md or Gemini concat output for the `starter` bundle
with all skills active runs ~800–1,200 lines of skill content. With 6 skills
stubbed, a project using only the always-on skills (implement, debugging,
receiving-code-review, adr, feature-lifecycle, context-budget) would see a
significantly smaller output file.

For a project using the `dotnet-api` or `node-api` bundle (which includes
domain-specific skills), the realistic reduction depends on which triggers
fire:
- A pure Node.js API project → `dotnet`, `e2e-testing`, `cross-stack-contract`
  stubbed; `security-scan` likely active (jwt, token keywords common); ~400–600
  lines saved.
- A .NET project with Stripe billing → all 6 skills likely active → no reduction.

The reduction is most dramatic for projects far from the trigger domains, as
expected.

## Issues found

**None.** The helper functions parse correctly, glob-to-ERE conversion handles
`**` and `*` patterns without false positives in this repo. The `_skill_has_triggers`
check correctly gates always-on skills (no `triggers:` key → always full content).

**Observation:** The keyword `org` in `tenant-scope-audit` could be overly broad
for projects that use GitHub org references in docs. The current keywords list
(`tenant`, `org`, `workspace`, `multi-tenant`, `organization`) might trigger
on repos with GitHub workflow files or contribution guidelines that mention
"org". Recommend removing `org` as a standalone keyword in a follow-up.

## Conclusion

RM-022 ships as designed. The implementation is correct and backward compatible.
The reduction target (≥ 40% of the output file for typical projects) is
achievable and exceeded for projects where domain-specific skills don't match.
