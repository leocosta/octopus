# Rebranding: Roles, Skills, Bundles — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename all roles, skills, and bundles to a consistent system: roles = short job titles, skills = category-prefixed nouns, bundles = plain-English team situations.

**Architecture:** Pure rename — no behavior changes. Execute in dependency order: (1) rename files/dirs, (2) update content inside files, (3) update cross-references, (4) update wizard, (5) update tests, (6) update docs, (7) regenerate .claude/ via octopus setup.

**Tech Stack:** Bash, YAML, Markdown, `git mv`, `sed`/Edit tool

---

## Rename Map Reference

### Roles
| Old | New |
|---|---|
| `backend-specialist` | `backend-developer` |
| `frontend-specialist` | `frontend-developer` |
| `tech-writer` | `writer` |
| `social-media` | `marketer` |
| `staff-engineer` | `architect` |
| `product-manager` | `product-manager` (unchanged) |

### Skills (renamed only)
| Old | New |
|---|---|
| `adr` | `doc-adr` |
| `feature-lifecycle` | `doc-lifecycle` |
| `money-review` | `audit-money` |
| `security-scan` | `audit-security` |
| `tenant-scope-audit` | `audit-tenant` |
| `receiving-code-review` | `review-pr` |
| `cross-stack-contract` | `review-contracts` |
| `feature-to-market` | `launch-feature` |
| `release-announce` | `launch-release` |
| `debugging` | `debug` |
| `plan-backlog-hygiene` | `plan-backlog` |
| `e2e-testing` | `test-e2e` |

### Bundles
| Old | New |
|---|---|
| `quality-gates` | `saas-quality` |
| `docs-discipline` | `documentation` |
| `cross-stack` | `fullstack` |

---

## File Map

| File | Change |
|---|---|
| `roles/*.md` (5 files) | Rename + update `name:` frontmatter |
| `skills/*/` (12 dirs) | Rename dir + update `name:` in SKILL.md |
| `bundles/*.yml` (3 files) | Rename + update `name:` + internal role/skill refs |
| `bundles/quality-leadership.yml` | Create new |
| `bundles/starter.yml` | Update skill refs (debugging→debug, receiving-code-review→review-pr, feature-lifecycle→doc-lifecycle, adr→doc-adr) |
| `bundles/docs-discipline.yml` (→ documentation.yml) | Rename + update name + plan-backlog-hygiene→plan-backlog, tech-writer→writer, doc-design/doc-plan stay |
| `bundles/growth.yml` | Update feature-to-market→launch-feature, release-announce→launch-release, social-media→marketer |
| `bundles/cross-stack.yml` (→ fullstack.yml) | Rename + update cross-stack-contract→review-contracts, backend-specialist→backend-developer, frontend-specialist→frontend-developer |
| `bundles/node-api.yml` | Update e2e-testing→test-e2e |
| `bundles/dotnet-api.yml` | Update e2e-testing→test-e2e |
| `bundles/quality-gates.yml` (→ saas-quality.yml) | Rename + update name + backend-specialist→backend-developer |
| `cli/lib/setup-wizard.sh` | Update ROLE_SKILL_MAP, items arrays, hints, skill items list |
| `skills/*/SKILL.md` (13 files with cross-refs) | Update role/skill name references in body text |
| `tests/test_generate_roles.sh` | Update role name assertions |
| `tests/test_bundles.sh` | Update bundle/role/skill name assertions |
| `tests/test_feature_to_market.sh` | Update skill name references |
| `tests/test_knowledge.sh` | Update role name references |
| `tests/test_control.sh` | Update role name references |
| `tests/test_parse_yaml.sh` | Update role references |
| `README.md` | Update Available: lists in all config sections |
| `.octopus.example.yml` | Update Available: comments and examples |

---

### Task 1: Rename role files and update their frontmatter

**Files:**
- Rename: `roles/backend-specialist.md` → `roles/backend-developer.md`
- Rename: `roles/frontend-specialist.md` → `roles/frontend-developer.md`
- Rename: `roles/tech-writer.md` → `roles/writer.md`
- Rename: `roles/social-media.md` → `roles/marketer.md`
- Rename: `roles/staff-engineer.md` → `roles/architect.md`

- [ ] **Step 1: Write failing test**

Add to `tests/test_generate_roles.sh` before the existing assertions:
```bash
echo "Test: role files use new names"
for role in backend-developer frontend-developer writer marketer architect product-manager; do
  [[ -f "roles/${role}.md" ]] \
    || { echo "FAIL: roles/${role}.md not found"; exit 1; }
done
echo "PASS"

echo "Test: old role files removed"
for role in backend-specialist frontend-specialist tech-writer social-media staff-engineer; do
  [[ ! -f "roles/${role}.md" ]] \
    || { echo "FAIL: old roles/${role}.md still present"; exit 1; }
done
echo "PASS"
```

- [ ] **Step 2: Run to verify it fails**

```bash
bash tests/test_generate_roles.sh 2>&1 | grep "FAIL\|PASS" | head -6
```
Expected: `FAIL: roles/backend-developer.md not found`

- [ ] **Step 3: Rename the files**

```bash
cd /path/to/project
git mv roles/backend-specialist.md roles/backend-developer.md
git mv roles/frontend-specialist.md roles/frontend-developer.md
git mv roles/tech-writer.md roles/writer.md
git mv roles/social-media.md roles/marketer.md
git mv roles/staff-engineer.md roles/architect.md
```

- [ ] **Step 4: Update `name:` in each renamed file**

In `roles/backend-developer.md`, change frontmatter line:
```yaml
name: backend-developer
```

In `roles/frontend-developer.md`:
```yaml
name: frontend-developer
```

In `roles/writer.md`:
```yaml
name: writer
```

In `roles/marketer.md`:
```yaml
name: marketer
```

In `roles/architect.md`:
```yaml
name: architect
```

- [ ] **Step 5: Run test to verify it passes**

```bash
bash tests/test_generate_roles.sh 2>&1 | grep "FAIL\|PASS" | head -6
```
Expected: all new-name assertions PASS

- [ ] **Step 6: Commit**

```bash
git add roles/
git commit -m "refactor: rename role files to new naming system

backend-specialist→backend-developer, frontend-specialist→frontend-developer,
tech-writer→writer, social-media→marketer, staff-engineer→architect

Co-authored-by: claude <claude@anthropic.com>"
```

---

### Task 2: Rename skill directories and update their frontmatter

**Files:**
- Rename 12 skill directories (see rename map above)

- [ ] **Step 1: Write failing test**

Add to `tests/test_bundles.sh`:
```bash
echo "Test: renamed skill dirs exist"
for skill in doc-adr doc-lifecycle audit-money audit-security audit-tenant review-pr review-contracts launch-feature launch-release debug plan-backlog test-e2e; do
  [[ -d "skills/${skill}" ]] \
    || { echo "FAIL: skills/${skill}/ not found"; exit 1; }
done
echo "PASS"
```

- [ ] **Step 2: Run to verify it fails**

```bash
bash tests/test_bundles.sh 2>&1 | grep "renamed skill" | head -3
```
Expected: `FAIL: skills/doc-adr/ not found`

- [ ] **Step 3: Rename all skill directories**

```bash
git mv skills/adr skills/doc-adr
git mv skills/feature-lifecycle skills/doc-lifecycle
git mv skills/money-review skills/audit-money
git mv skills/security-scan skills/audit-security
git mv skills/tenant-scope-audit skills/audit-tenant
git mv skills/receiving-code-review skills/review-pr
git mv skills/cross-stack-contract skills/review-contracts
git mv skills/feature-to-market skills/launch-feature
git mv skills/release-announce skills/launch-release
git mv skills/debugging skills/debug
git mv skills/plan-backlog-hygiene skills/plan-backlog
git mv skills/e2e-testing skills/test-e2e
```

- [ ] **Step 4: Update `name:` in each SKILL.md**

For each renamed skill, open its SKILL.md and update the `name:` frontmatter field:

`skills/doc-adr/SKILL.md`: `name: doc-adr`
`skills/doc-lifecycle/SKILL.md`: `name: doc-lifecycle`
`skills/audit-money/SKILL.md`: `name: audit-money`
`skills/audit-security/SKILL.md`: `name: audit-security`
`skills/audit-tenant/SKILL.md`: `name: audit-tenant`
`skills/review-pr/SKILL.md`: `name: review-pr`
`skills/review-contracts/SKILL.md`: `name: review-contracts`
`skills/launch-feature/SKILL.md`: `name: launch-feature`
`skills/launch-release/SKILL.md`: `name: launch-release`
`skills/debug/SKILL.md`: `name: debug`
`skills/plan-backlog/SKILL.md`: `name: plan-backlog`
`skills/test-e2e/SKILL.md`: `name: test-e2e`

- [ ] **Step 5: Run test to verify it passes**

```bash
bash tests/test_bundles.sh 2>&1 | grep "renamed skill"
```
Expected: `PASS`

- [ ] **Step 6: Commit**

```bash
git add skills/
git commit -m "refactor: rename skill directories to category-prefixed names

audit-*, doc-*, review-*, launch-* prefixes; debug, plan-backlog, test-e2e

Co-authored-by: claude <claude@anthropic.com>"
```

---

### Task 3: Rename bundle files, update names and internal references

**Files:**
- Rename: `bundles/quality-gates.yml` → `bundles/saas-quality.yml`
- Rename: `bundles/docs-discipline.yml` → `bundles/documentation.yml`
- Rename: `bundles/cross-stack.yml` → `bundles/fullstack.yml`
- Modify: all bundle files that reference old skill/role names

- [ ] **Step 1: Write failing test**

Add to `tests/test_bundles.sh`:
```bash
echo "Test: renamed bundle files exist with new names"
for bundle in saas-quality documentation fullstack; do
  [[ -f "bundles/${bundle}.yml" ]] \
    || { echo "FAIL: bundles/${bundle}.yml not found"; exit 1; }
  grep -q "^name: ${bundle}$" "bundles/${bundle}.yml" \
    || { echo "FAIL: name field wrong in bundles/${bundle}.yml"; exit 1; }
done
echo "PASS"

echo "Test: old bundle files removed"
for bundle in quality-gates docs-discipline cross-stack; do
  [[ ! -f "bundles/${bundle}.yml" ]] \
    || { echo "FAIL: old bundles/${bundle}.yml still present"; exit 1; }
done
echo "PASS"
```

- [ ] **Step 2: Run to verify it fails**

```bash
bash tests/test_bundles.sh 2>&1 | grep "renamed bundle\|old bundle" | head -4
```
Expected: `FAIL: bundles/saas-quality.yml not found`

- [ ] **Step 3: Rename the three bundle files**

```bash
git mv bundles/quality-gates.yml bundles/saas-quality.yml
git mv bundles/docs-discipline.yml bundles/documentation.yml
git mv bundles/cross-stack.yml bundles/fullstack.yml
```

- [ ] **Step 4: Update content of all bundle files**

**`bundles/saas-quality.yml`** — change `name:` and role ref:
```yaml
name: saas-quality
description: SaaS quality audits — secrets, money-logic, tenant-scope, provider integrations.
category: intent
persona_question: "Is this a SaaS product for external customers (billing, multi-tenant)?"
persona_default: false
skills:
  - audit-all
roles:
  - backend-developer
rules: []
mcp: []
hooks: null
```

**`bundles/documentation.yml`** — change `name:`, role, and skill refs:
```yaml
name: documentation
description: Teams that document with RFCs, specs, ADRs, and a living roadmap.
category: intent
persona_question: "Do you document with RFCs, specs, and ADRs?"
persona_default: false
skills:
  - plan-backlog
  - continuous-learning
  - compress-skill
  - doc-design
  - doc-plan
roles:
  - writer
rules: []
mcp: []
hooks: null
```

**`bundles/fullstack.yml`** — change `name:`, skill, and role refs:
```yaml
name: fullstack
description: Monorepo with a backend API and one or more separate frontends.
category: intent
persona_question: "Does your repo contain both an API and a separate frontend?"
persona_default: false
skills:
  - review-contracts
roles:
  - backend-developer
  - frontend-developer
rules: []
mcp: []
hooks: null
```

**`bundles/starter.yml`** — update skill refs only (name stays `starter`):
```yaml
name: starter
description: Baseline for any repo — ADRs, feature lifecycle, context budget, implementation workflow, debugging protocol, review-feedback discipline.
category: foundation
skills:
  - doc-adr
  - doc-lifecycle
  - context-budget
  - implement
  - debug
  - review-pr
roles: []
rules: []
mcp: []
hooks: null
```

**`bundles/growth.yml`** — update skill and role refs:
```yaml
name: growth
description: Ship features as launch kits — social posts, email, LP copy, changelog.
category: intent
persona_question: "Does your team produce marketing content alongside code?"
persona_default: false
skills:
  - launch-feature
  - launch-release
roles:
  - marketer
rules: []
mcp: []
hooks: null
```

**`bundles/node-api.yml`** — update skill ref:
```yaml
name: node-api
description: Node / TypeScript backend — patterns, E2E.
category: stack
persona_question: "Primary backend language is Node / TypeScript?"
persona_default: false
skills:
  - backend-patterns
  - test-e2e
roles: []
rules: []
mcp: []
hooks: null
```

**`bundles/dotnet-api.yml`** — update skill ref:
```yaml
name: dotnet-api
description: .NET / ASP.NET Core backend — patterns, helpers, E2E.
category: stack
persona_question: "Primary backend language is .NET?"
persona_default: false
skills:
  - dotnet
  - backend-patterns
  - test-e2e
roles: []
rules: []
mcp: []
hooks: null
```

- [ ] **Step 5: Create `bundles/quality-leadership.yml`**

```yaml
name: quality-leadership
description: Architecture review, ADR discipline, and senior code review by a dedicated staff engineer.
category: intent
persona_question: "Do you want a dedicated architect for architecture review and senior code review?"
persona_default: false
skills:
  - doc-adr
  - review-pr
roles:
  - architect
rules: []
mcp: []
hooks: null
```

- [ ] **Step 6: Run test to verify it passes**

```bash
bash tests/test_bundles.sh 2>&1 | grep "renamed bundle\|old bundle"
```
Expected: both PASS

- [ ] **Step 7: Commit**

```bash
git add bundles/
git commit -m "refactor: rename and update bundle files

quality-gates→saas-quality, docs-discipline→documentation, cross-stack→fullstack.
All internal role/skill references updated to new names.
Add quality-leadership bundle for architect role.

Co-authored-by: claude <claude@anthropic.com>"
```

---

### Task 4: Update setup-wizard.sh

**Files:**
- Modify: `cli/lib/setup-wizard.sh`

- [ ] **Step 1: Write failing test**

Add to `tests/test_control.sh`:
```bash
echo "Test: setup-wizard uses new role names"
grep -q "backend-developer" "$REPO_DIR/cli/lib/setup-wizard.sh" \
  || { echo "FAIL: backend-developer not in setup-wizard.sh"; exit 1; }
grep -q "backend-specialist" "$REPO_DIR/cli/lib/setup-wizard.sh" \
  && { echo "FAIL: old name backend-specialist still in setup-wizard.sh"; exit 1; }
echo "PASS"

echo "Test: setup-wizard uses new skill names"
grep -q "audit-security" "$REPO_DIR/cli/lib/setup-wizard.sh" \
  || { echo "FAIL: audit-security not in setup-wizard.sh"; exit 1; }
grep -q '"security-scan"' "$REPO_DIR/cli/lib/setup-wizard.sh" \
  && { echo "FAIL: old name security-scan still in setup-wizard.sh"; exit 1; }
echo "PASS"
```

- [ ] **Step 2: Run to verify it fails**

```bash
bash tests/test_control.sh 2>&1 | grep "setup-wizard" | head -4
```
Expected: `FAIL: backend-developer not in setup-wizard.sh`

- [ ] **Step 3: Update ROLE_SKILL_MAP (lines 473-479)**

Replace the entire `declare -A ROLE_SKILL_MAP=(...)` block:

```bash
declare -A ROLE_SKILL_MAP=(
  ["backend-developer"]="backend-patterns audit-tenant audit-money audit-security debug"
  ["frontend-developer"]="test-e2e review-contracts debug"
  ["product-manager"]="doc-adr plan-backlog doc-lifecycle doc-design doc-plan"
  ["writer"]="doc-adr doc-design doc-plan continuous-learning"
  ["marketer"]="launch-feature launch-release"
  ["architect"]="doc-adr audit-security review-pr audit-all"
)
```

- [ ] **Step 4: Update `_wizard_sub_roles` (lines 781-800)**

Replace the entire `_wizard_sub_roles()` function:

```bash
_wizard_sub_roles() {
  local items=(backend-developer frontend-developer product-manager writer marketer architect)
  local defaults=("${WIZARD_ROLES[@]}")

  _wizard_subheader "Roles" "Specialized sub-agent personas; each carries its own instructions."
  _wizard_hints \
    "backend-developer|APIs, data modeling, server-side logic" \
    "frontend-developer|UI/UX, components, accessibility" \
    "product-manager|specs, roadmap, prioritization" \
    "writer|docs, READMEs, release notes, ADRs" \
    "marketer|platform-native posts and campaigns" \
    "architect|architecture review, ADR compliance, senior code review"

  _multiselect \
    "Select roles" \
    "backend-developer · frontend-developer · product-manager · writer · marketer · architect" \
    items defaults

  WIZARD_ROLES=("${WIZARD_SELECTED[@]}")
}
```

- [ ] **Step 5: Update skills items array (line 714)**

Replace the `local items=(adr audit-all ...)` line with:

```bash
  local items=(audit-all audit-money audit-security audit-tenant backend-patterns batch compress-skill context-budget continuous-learning debug doc-adr doc-design doc-lifecycle doc-plan dotnet implement launch-feature launch-release plan-backlog review-contracts review-pr test-e2e)
```

- [ ] **Step 6: Update skills hints array**

Replace each old name in `raw_hints` with its new name:

```bash
  local raw_hints=(
    "audit-all|run all quality audits in parallel with consolidated report"
    "audit-money|audit money-logic changes for split/tax/rounding bugs"
    "audit-security|scan diffs for secrets and vulnerabilities"
    "audit-tenant|audit multi-tenant data-scope enforcement (query filters, raw SQL, ownership)"
    "backend-patterns|apply repo/service/DI patterns"
    "batch|fan out a prompt across many targets in parallel"
    "compress-skill|shrink a SKILL.md by ~25% with diff review and invariants"
    "context-budget|monitor and trim the conversation context"
    "continuous-learning|capture lessons learned per session"
    "debug|apply the Octopus bug-fix protocol — reproduce, isolate, regression test, document"
    "doc-adr|record Architecture Decision Records"
    "doc-design|drive an interactive spec-design session filling Design, Testing, and adaptive sections"
    "doc-lifecycle|spec → PR → release helpers"
    "doc-plan|turn a completed spec into a bite-sized, TDD-style implementation plan"
    "dotnet|.NET-specific build/test/format helpers"
    "implement|apply the Octopus workflow — TDD, plan gate, verification, simplify, commit cadence"
    "launch-feature|turn a shipped feature into a launch kit"
    "launch-release|themed release kit for existing users (HTML + channels + slides)"
    "plan-backlog|audit plans/ and roadmap for stale, orphan, or duplicate items"
    "review-contracts|detect API-vs-frontend drift in monorepos"
    "review-pr|apply the Octopus PR-feedback discipline — verify, ask, clarify, never performative"
    "test-e2e|scaffold end-to-end test suites"
  )
```

- [ ] **Step 7: Run test to verify it passes**

```bash
bash tests/test_control.sh 2>&1 | grep "setup-wizard"
```
Expected: both PASS

- [ ] **Step 8: Commit**

```bash
git add cli/lib/setup-wizard.sh tests/test_control.sh
git commit -m "refactor(wizard): update ROLE_SKILL_MAP, role items, and skill hints to new names

Co-authored-by: claude <claude@anthropic.com>"
```

---

### Task 5: Update cross-references inside SKILL.md files

**Files:**
- Modify: body text of 13 SKILL.md files that reference old role/skill names

- [ ] **Step 1: Verify references exist (confirm they need updating)**

```bash
grep -rl "backend-specialist\|frontend-specialist\|tech-writer\|social-media\|staff-engineer\|receiving-code-review\|cross-stack-contract\|tenant-scope-audit\|money-review\|security-scan\|feature-to-market\|release-announce\|feature-lifecycle\|plan-backlog-hygiene\|e2e-testing\|debugging\b" skills/*/SKILL.md | sort
```
Expected: lists ~13 files

- [ ] **Step 2: Apply sed replacements across all SKILL.md files**

```bash
find skills -name "SKILL.md" | xargs sed -i \
  -e 's/backend-specialist/backend-developer/g' \
  -e 's/frontend-specialist/frontend-developer/g' \
  -e 's/tech-writer/writer/g' \
  -e 's/social-media/marketer/g' \
  -e 's/staff-engineer/architect/g' \
  -e 's/`receiving-code-review`/`review-pr`/g' \
  -e 's/receiving-code-review/review-pr/g' \
  -e 's/`cross-stack-contract`/`review-contracts`/g' \
  -e 's/cross-stack-contract/review-contracts/g' \
  -e 's/`tenant-scope-audit`/`audit-tenant`/g' \
  -e 's/tenant-scope-audit/audit-tenant/g' \
  -e 's/`money-review`/`audit-money`/g' \
  -e 's/money-review/audit-money/g' \
  -e 's/`security-scan`/`audit-security`/g' \
  -e 's/security-scan/audit-security/g' \
  -e 's/`feature-to-market`/`launch-feature`/g' \
  -e 's/feature-to-market/launch-feature/g' \
  -e 's/`release-announce`/`launch-release`/g' \
  -e 's/release-announce/launch-release/g' \
  -e 's/`feature-lifecycle`/`doc-lifecycle`/g' \
  -e 's/feature-lifecycle/doc-lifecycle/g' \
  -e 's/`plan-backlog-hygiene`/`plan-backlog`/g' \
  -e 's/plan-backlog-hygiene/plan-backlog/g' \
  -e 's/`e2e-testing`/`test-e2e`/g' \
  -e 's/e2e-testing/test-e2e/g' \
  -e 's/\badr\b/doc-adr/g' \
  -e 's/`debugging`/`debug`/g' \
  -e 's/debugging/debug/g'
```

- [ ] **Step 3: Verify no old names remain in SKILL.md files**

```bash
grep -rl "backend-specialist\|frontend-specialist\|tech-writer\b\|social-media\|staff-engineer\|receiving-code-review\|cross-stack-contract\|tenant-scope-audit\|money-review\b\|security-scan\|feature-to-market\|release-announce\|feature-lifecycle\|plan-backlog-hygiene\|e2e-testing\b" skills/*/SKILL.md 2>/dev/null | wc -l
```
Expected: `0`

- [ ] **Step 4: Commit**

```bash
git add skills/
git commit -m "refactor: update role/skill cross-references in all SKILL.md files

Co-authored-by: claude <claude@anthropic.com>"
```

---

### Task 6: Update tests

**Files:**
- Modify: `tests/test_bundles.sh`, `tests/test_generate_roles.sh`, `tests/test_feature_to_market.sh`, `tests/test_knowledge.sh`, `tests/test_parse_yaml.sh`

- [ ] **Step 1: Run existing tests to see current state**

```bash
for t in tests/test_bundles.sh tests/test_generate_roles.sh tests/test_feature_to_market.sh tests/test_knowledge.sh tests/test_parse_yaml.sh; do
  echo "=== $t ==="; bash "$t" 2>&1 | grep "FAIL" || true
done
```

- [ ] **Step 2: Update `tests/test_bundles.sh`**

Replace all old bundle, role, and skill name assertions:
```bash
# Change bundle name assertions
sed -i \
  -e 's/quality-gates/saas-quality/g' \
  -e 's/docs-discipline/documentation/g' \
  -e 's/cross-stack\b/fullstack/g' \
  -e 's/backend-specialist/backend-developer/g' \
  -e 's/receiving-code-review/review-pr/g' \
  -e 's/feature-lifecycle/doc-lifecycle/g' \
  -e 's/\badr\b/doc-adr/g' \
  -e 's/security-scan/audit-security/g' \
  -e 's/money-review/audit-money/g' \
  -e 's/tenant-scope-audit/audit-tenant/g' \
  -e 's/cross-stack-contract/review-contracts/g' \
  -e 's/debugging\b/debug/g' \
  tests/test_bundles.sh
```

Also update the bundle loop at line 8 from:
```bash
for name in starter quality-gates growth docs-discipline cross-stack dotnet-api node-api; do
```
to:
```bash
for name in starter saas-quality growth documentation fullstack dotnet-api node-api quality-leadership; do
```

- [ ] **Step 3: Update `tests/test_generate_roles.sh`**

```bash
sed -i \
  -e 's/social-media/marketer/g' \
  -e 's/backend-specialist/backend-developer/g' \
  -e 's/frontend-specialist/frontend-developer/g' \
  -e 's/tech-writer/writer/g' \
  -e 's/staff-engineer/architect/g' \
  tests/test_generate_roles.sh
```

- [ ] **Step 4: Update `tests/test_feature_to_market.sh`, `tests/test_knowledge.sh`, `tests/test_parse_yaml.sh`**

```bash
sed -i \
  -e 's/backend-specialist/backend-developer/g' \
  -e 's/frontend-specialist/frontend-developer/g' \
  -e 's/tech-writer/writer/g' \
  -e 's/social-media/marketer/g' \
  -e 's/feature-to-market/launch-feature/g' \
  tests/test_feature_to_market.sh tests/test_knowledge.sh tests/test_parse_yaml.sh
```

- [ ] **Step 5: Run all updated tests**

```bash
for t in tests/test_bundles.sh tests/test_generate_roles.sh tests/test_feature_to_market.sh tests/test_knowledge.sh; do
  echo "=== $t ==="; bash "$t" 2>&1 | grep "FAIL\|PASS" | head -5
done
```
Expected: no FAIL lines

- [ ] **Step 6: Commit**

```bash
git add tests/
git commit -m "test: update assertions to new role/skill/bundle names

Co-authored-by: claude <claude@anthropic.com>"
```

---

### Task 7: Update README.md and .octopus.example.yml

**Files:**
- Modify: `README.md`, `.octopus.example.yml`

- [ ] **Step 1: Update README.md**

Apply replacements to the Available: lists and configuration examples:
```bash
sed -i \
  -e 's/starter, quality-gates, growth, docs-discipline, cross-stack, dotnet-api, node-api/starter, saas-quality, growth, documentation, fullstack, dotnet-api, node-api, quality-leadership/g' \
  -e 's/adr, audit-all, backend-patterns, context-budget, continuous-learning, debugging, cross-stack-contract, dotnet, e2e-testing, feature-lifecycle, feature-to-market, implement, money-review, plan-backlog-hygiene, receiving-code-review, release-announce, security-scan, tenant-scope-audit/audit-all, audit-money, audit-security, audit-tenant, backend-patterns, batch, compress-skill, context-budget, continuous-learning, debug, doc-adr, doc-design, doc-lifecycle, doc-plan, dotnet, implement, launch-feature, launch-release, plan-backlog, review-contracts, review-pr, test-e2e/g' \
  -e 's/product-manager, backend-specialist, frontend-specialist, tech-writer, social-media/product-manager, backend-developer, frontend-developer, writer, marketer, architect/g' \
  -e 's/backend-specialist/backend-developer/g' \
  -e 's/frontend-specialist/frontend-developer/g' \
  -e 's/tech-writer/writer/g' \
  -e 's/social-media/marketer/g' \
  README.md
```

- [ ] **Step 2: Update .octopus.example.yml**

```bash
sed -i \
  -e 's/starter, quality-gates, growth, docs-discipline, cross-stack, dotnet-api, node-api/starter, saas-quality, growth, documentation, fullstack, dotnet-api, node-api, quality-leadership/g' \
  -e 's/product-manager, backend-specialist, frontend-specialist, tech-writer/product-manager, backend-developer, frontend-developer, writer/g' \
  -e 's/backend-specialist/backend-developer/g' \
  -e 's/frontend-specialist/frontend-developer/g' \
  -e 's/tech-writer/writer/g' \
  -e 's/social-media/marketer/g' \
  .octopus.example.yml
```

- [ ] **Step 3: Verify no old names remain in docs**

```bash
grep -n "backend-specialist\|frontend-specialist\|tech-writer\b\|social-media\b\|quality-gates\b\|docs-discipline\b\|cross-stack\b" README.md .octopus.example.yml | head -10
```
Expected: no output (empty)

- [ ] **Step 4: Commit**

```bash
git add README.md .octopus.example.yml
git commit -m "docs: update README and example config to new names

Co-authored-by: claude <claude@anthropic.com>"
```

---

### Task 8: Regenerate .claude/ files and run full test suite

**Files:**
- Regenerate: `.claude/agents/*.md`, `.claude/skills/` (via octopus setup)
- Verify: all tests pass

- [ ] **Step 1: Update .octopus.yml to include new role names**

In `.octopus.yml`, update any role references:
```yaml
roles:
  - marketer
  - architect
```

- [ ] **Step 2: Run octopus setup to regenerate agent files**

```bash
octopus setup
```
Expected: `=== Setup complete ===` with no errors

- [ ] **Step 3: Verify new agent files exist**

```bash
ls .claude/agents/
```
Expected: `architect.md  backend-developer.md  dream.md  frontend-developer.md  marketer.md  product-manager.md  writer.md`

- [ ] **Step 4: Verify old agent files are gone**

```bash
ls .claude/agents/ | grep -E "backend-specialist|frontend-specialist|tech-writer|social-media|staff-engineer" | wc -l
```
Expected: `0`

- [ ] **Step 5: Run full test suite**

```bash
for t in tests/test_*.sh; do
  result=$(bash "$t" 2>&1 | grep "FAIL" || true)
  [[ -n "$result" ]] && echo "=== $t ===" && echo "$result"
done
echo "Done"
```
Expected: only the pre-existing `test_bundle_preview.sh` failure; all others pass

- [ ] **Step 6: Commit**

```bash
git add .claude/ .octopus.yml
git commit -m "chore: regenerate .claude/agents after role rename

Co-authored-by: claude <claude@anthropic.com>"
```
