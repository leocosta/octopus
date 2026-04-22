# Spec: Role-aware skill hints in full-mode wizard

## Context

The full-mode setup wizard (Group 2 — "What the AI knows and does") asked for
skills before roles. Since roles define which sub-agent personas will be active,
selecting them first gives the user the context needed to make better skill
choices. Additionally, once roles are known, the wizard can visually flag which
skills are most relevant for those roles — reducing cognitive load during
onboarding.

## Goal

1. Reorder Group 2 so roles are selected before skills.
2. After role selection, annotate relevant skills with ★ in the hints list and
   show a legend at the bottom.

## Scope

Single file: `cli/lib/setup-wizard.sh`

## Changes

### 1. `ROLE_SKILL_MAP` (alongside `WIZARD_ROLES` state variable)

```bash
declare -A ROLE_SKILL_MAP=(
  ["backend-specialist"]="backend-patterns tenant-scope-audit money-review security-scan debugging"
  ["frontend-specialist"]="e2e-testing cross-stack-contract debugging"
  ["product-manager"]="adr plan-backlog-hygiene feature-lifecycle doc-design doc-plan"
  ["tech-writer"]="adr doc-design doc-plan continuous-learning"
  ["social-media"]="feature-to-market release-announce"
)
```

### 2. Reorder `_wizard_group_capabilities`

```
Before: rules → skills → roles → knowledge
After:  rules → roles → skills → knowledge
```

### 3. Annotate hints in `_wizard_sub_skills`

Compute the recommended set from `WIZARD_ROLES` before building hints.
Prefix the description with `★ ` for recommended skills. After the hints,
print a legend when any roles are active:

```
★ = recommended for: backend-specialist, frontend-specialist
```

## Behavior matrix

| Roles selected | Skills screen |
|---|---|
| None | No ★, no legend — identical to previous behavior |
| One role | Skills in that role's map get ★; legend shows that role |
| Multiple roles | Union of all mapped skills get ★; legend lists all roles |

## Verification

1. `./cli/octopus setup --mode full` — confirm Roles appears before Skills in Group 2.
2. Select `backend-specialist` → Skills screen shows ★ on `backend-patterns`,
   `tenant-scope-audit`, `money-review`, `security-scan`, `debugging`; legend
   `★ = recommended for: backend-specialist`.
3. Select no roles → Skills screen has no ★, no legend.
4. Select `backend-specialist` + `product-manager` → union of both skill sets
   marked; legend lists both.
5. Complete wizard end-to-end → `.octopus.yml` output unchanged (roles and
   skills in correct sections).
