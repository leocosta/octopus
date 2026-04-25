# Rebranding: Roles, Skills e Bundles

## Problem

The current naming system has three compounding issues:
1. **Inconsistent patterns** — skills mix verbs (`implement`, `batch`), nouns (`adr`, `dotnet`), and long descriptives (`plan-backlog-hygiene`, `receiving-code-review`)
2. **Unclear names** — `cross-stack-contract`, `tenant-scope-audit`, and `receiving-code-review` require domain knowledge to understand
3. **Role/skill overlap** — `tech-writer` (role) alongside `doc-plan`, `doc-design`, `adr` (skills) blurs the boundary between who does the work and what they do

## Solution

Introduce a consistent naming system:
- **Roles** = short job titles (who the agent is)
- **Skills** = grouped by function prefix (what the agent does)
- **Bundles** = plain-English team situation (when to use)

---

## Role Renames

| Old | New | Notes |
|---|---|---|
| `backend-specialist` | `backend-developer` | |
| `frontend-specialist` | `frontend-developer` | |
| `product-manager` | `product-manager` | unchanged |
| `tech-writer` | `writer` | drops redundant "tech" |
| `social-media` | `marketer` | person not domain |
| `staff-engineer` | `architect` | reflects review/architecture role |

## Skill Renames

### `audit-*` — pre-merge quality checks
| Old | New |
|---|---|
| `audit-all` | `audit-all` |
| `money-review` | `audit-money` |
| `security-scan` | `audit-security` |
| `tenant-scope-audit` | `audit-tenant` |

### `doc-*` — documentation creation
| Old | New |
|---|---|
| `adr` | `doc-adr` |
| `doc-plan` | `doc-plan` |
| `doc-design` | `doc-design` |
| `feature-lifecycle` | `doc-lifecycle` |

### `review-*` — code review processes
| Old | New |
|---|---|
| `receiving-code-review` | `review-pr` |
| `cross-stack-contract` | `review-contracts` |

### `launch-*` — publishing and go-to-market
| Old | New |
|---|---|
| `feature-to-market` | `launch-feature` |
| `release-announce` | `launch-release` |

### Unchanged
| Name | Status |
|---|---|
| `implement` | unchanged |
| `debugging` → `debug` | verb normalisation only |
| `plan-backlog-hygiene` → `plan-backlog` | shorter |
| `backend-patterns` | unchanged |
| `e2e-testing` → `test-e2e` | prefix pattern |
| `dotnet` | unchanged |
| `batch` | unchanged |
| `context-budget` | unchanged |
| `continuous-learning` | unchanged |
| `compress-skill` | unchanged |

## Bundle Renames

| Old | New | Notes |
|---|---|---|
| `starter` | `starter` | unchanged |
| `quality-gates` | `saas-quality` | |
| `docs-discipline` | `documentation` | |
| `cross-stack` | `fullstack` | |
| `growth` | `growth` | unchanged |
| `dotnet-api` | `dotnet-api` | unchanged |
| `node-api` | `node-api` | unchanged |
| *(new)* | `quality-leadership` | for `architect` role |

---

## Files to Update

### Rename files/dirs
- `roles/backend-specialist.md` → `roles/backend-developer.md`
- `roles/frontend-specialist.md` → `roles/frontend-developer.md`
- `roles/tech-writer.md` → `roles/writer.md`
- `roles/social-media.md` → `roles/marketer.md`
- `roles/staff-engineer.md` → `roles/architect.md`
- `skills/adr/` → `skills/doc-adr/`
- `skills/feature-lifecycle/` → `skills/doc-lifecycle/`
- `skills/money-review/` → `skills/audit-money/`
- `skills/security-scan/` → `skills/audit-security/`
- `skills/tenant-scope-audit/` → `skills/audit-tenant/`
- `skills/receiving-code-review/` → `skills/review-pr/`
- `skills/cross-stack-contract/` → `skills/review-contracts/`
- `skills/feature-to-market/` → `skills/launch-feature/`
- `skills/release-announce/` → `skills/launch-release/`
- `skills/debugging/` → `skills/debug/`
- `skills/plan-backlog-hygiene/` → `skills/plan-backlog/`
- `skills/e2e-testing/` → `skills/test-e2e/`
- `bundles/quality-gates.yml` → `bundles/saas-quality.yml`
- `bundles/docs-discipline.yml` → `bundles/documentation.yml`
- `bundles/cross-stack.yml` → `bundles/fullstack.yml`

### Update name fields inside files
- Frontmatter `name:` in all renamed roles, skills, bundles
- `ROLE_SKILL_MAP` and `items=()` arrays in `cli/lib/setup-wizard.sh`
- Skill/role references inside all bundle YAML files
- `roles:` and `skills:` references inside all skill SKILL.md files (task-routing, cross-references)
- `.claude/agents/*.md` — regenerate via `octopus setup` after rename
- `.claude/skills/*.md` — regenerate via `octopus setup` after rename
- `.octopus.example.yml` — update Available: comments and examples
- `README.md` — update Available: lists in configuration section
- `tests/test_bundles.sh`, `tests/test_generate_roles.sh`, `tests/test_skill_matcher.sh`, etc.

---

## Out of Scope
- Changing role content/behavior — only names change
- Changing skill behavior — only names and SKILL.md frontmatter change
- Deprecation shims or backwards compatibility — old names are removed cleanly
