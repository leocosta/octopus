---
slug: local-guardrails-quality-style-grounding
generated_by: octopus:doc-plan
pipeline:
  review_skill: octopus:codereview
  pr_on_success: true
tasks:
  - id: t1
    agent: reviewer
    depends_on: []
  - id: t2
    agent: backend-specialist
    depends_on: [t1]
  - id: t3
    agent: backend-specialist
    depends_on: [t1, t2]
  - id: t4
    agent: tech-writer
    depends_on: [t1, t2, t3]
---

# Local Guardrails: Semantic Grounding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Flag, at the end of every agent task, any invented team convention or unsupported domain fact by confronting the diff against the repo's living source of truth — signal-only, local.

**Architecture:** A new `audit-grounding` LLM skill reads the diff plus the living source of truth (CONTEXT.md, `docs/adr/`, knowledge base) and emits two finding types: `invented-convention` and `unsupported-domain-fact`. A deterministic `stop` hook (`grounding-check.sh`) triggers it at task end and routes findings to the proposals queue — never blocking. The deterministic syntactic layer (formatter, type check, secret scan, no-bypass) is already shipped by the `guardrails` bundle and its loop-level hooks, so it is adopted, not rebuilt.

**Tech Stack:** Markdown skill (SKILL.md) + bash stop hook; grep-based bash tests (project convention).

**Spec:** `docs/specs/local-guardrails-quality-style-grounding.md`

---

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `skills/audit-grounding/SKILL.md` | create | LLM audit: diff vs source of truth; emits `invented-convention` + `unsupported-domain-fact` findings; signal-only |
| `tests/test_audit_grounding.sh` | create | Structural grep tests for the SKILL markers |
| `hooks/stop/grounding-check.sh` | create | Deterministic task-end trigger; routes findings to the proposals queue, non-blocking |
| `hooks/hooks.json` | modify | Register the `grounding-check` stop hook |
| `bundles/quality.yml` | modify | Add `audit-grounding` to the bundle skills |
| `docs/features/audit-grounding.md` | create | Capability doc + recommended `guardrails`+`quality` config for the syntactic layer |
| `docs/roadmap.md` | modify | RM-088 entry |

---

## Task 1: `audit-grounding` skill + structural tests

**Files:**
- Create: `skills/audit-grounding/SKILL.md`
- Create: `tests/test_audit_grounding.sh`

- [ ] **t1 — Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
# tests/test_audit_grounding.sh
set -euo pipefail
OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$OCTOPUS_DIR/skills/audit-grounding/SKILL.md"
PASS=0; FAIL=0

check() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then echo "PASS: $desc"; PASS=$((PASS+1))
  else echo "FAIL: $desc"; FAIL=$((FAIL+1)); fi
}

check "SKILL.md exists" test -f "$SKILL"
check "declares name audit-grounding" grep -q "name: audit-grounding" "$SKILL"
check "reads the source of truth (CONTEXT.md)" grep -q "CONTEXT.md" "$SKILL"
check "reads the source of truth (docs/adr)" grep -q "docs/adr" "$SKILL"
check "emits invented-convention finding" grep -q "invented-convention" "$SKILL"
check "emits unsupported-domain-fact finding" grep -q "unsupported-domain-fact" "$SKILL"
check "is signal-only (no block)" grep -qi "signal-only\|does not block\|never blocks" "$SKILL"

echo "PASS=$PASS FAIL=$FAIL"; test "$FAIL" -eq 0
```

- [ ] **t1 — Step 2: Run test to verify it fails**

Run: `bash tests/test_audit_grounding.sh`
Expected: FAIL with "SKILL.md exists" failing (file not yet created)

- [ ] **t1 — Step 3: Write minimal implementation**

Create `skills/audit-grounding/SKILL.md` with frontmatter `name: audit-grounding` and a protocol that:
1. Scopes the diff (the same ref-discovery the other `audit-*` skills use).
2. Loads the source of truth in order: `CONTEXT.md`, `docs/adr/*`, the knowledge base, any module-scoped context. Degrades gracefully when `CONTEXT.md` is absent.
3. For each new/changed convention (naming, folder, field) not present in the source of truth → emits an `invented-convention` finding.
4. For each domain claim in the diff or its comments that contradicts or is absent from the decisions of record → emits an `unsupported-domain-fact` finding.
5. States explicitly that it is **signal-only** and **never blocks**; the human decides.
6. Emits findings in the project's structured audit shape (severity tier: info/warn — never block).

- [ ] **t1 — Step 4: Run test to verify it passes**

Run: `bash tests/test_audit_grounding.sh`
Expected: PASS

- [ ] **t1 — Step 5: Commit**

```bash
git add skills/audit-grounding/SKILL.md tests/test_audit_grounding.sh
git commit -m "feat(audit-grounding): flag invented conventions and unsupported domain facts

Co-authored-by: claude <claude@anthropic.com>"
```

---

## Task 2: `grounding-check` stop hook + registration

**Files:**
- Create: `hooks/stop/grounding-check.sh`
- Modify: `hooks/hooks.json`

- [ ] **t2 — Step 1: Write the failing test**

Append to `tests/test_audit_grounding.sh`:

```bash
HOOK="$OCTOPUS_DIR/hooks/stop/grounding-check.sh"
check "stop hook exists" test -f "$HOOK"
check "stop hook is executable" test -x "$HOOK"
check "hook routes to proposals queue" grep -q "proposals" "$HOOK"
check "hook is non-blocking (exit 0)" grep -q "exit 0" "$HOOK"
check "hook registered in hooks.json" grep -q "grounding-check" "$OCTOPUS_DIR/hooks/hooks.json"
```

- [ ] **t2 — Step 2: Run test to verify it fails**

Run: `bash tests/test_audit_grounding.sh`
Expected: FAIL with "stop hook exists" failing

- [ ] **t2 — Step 3: Write minimal implementation**

Create `hooks/stop/grounding-check.sh` modelled on `hooks/stop/propose-knowledge-update.sh`:
- Fires on the `Stop` event (task end).
- Surfaces the request to run `audit-grounding` against the session diff and writes the resulting divergence findings to the proposals queue (`.octopus/proposals/`), matching the precedent set by `propose-knowledge-update.sh`.
- Always `exit 0` — non-blocking by contract.

Register it in `hooks/hooks.json` under the `Stop` matcher with `id: grounding-check`, beside the existing stop hooks.

- [ ] **t2 — Step 4: Run test to verify it passes**

Run: `bash tests/test_audit_grounding.sh`
Expected: PASS

- [ ] **t2 — Step 5: Commit**

```bash
git add hooks/stop/grounding-check.sh hooks/hooks.json
git commit -m "feat(hooks): trigger audit-grounding at task end, route findings to proposals queue

Co-authored-by: claude <claude@anthropic.com>"
```

---

## Task 3: Register `audit-grounding` in the `quality` bundle

**Files:**
- Modify: `bundles/quality.yml`

- [ ] **t3 — Step 1: Write the failing test**

Append to `tests/test_audit_grounding.sh`:

```bash
QBUNDLE="$OCTOPUS_DIR/bundles/quality.yml"
check "audit-grounding listed in quality bundle" grep -q "audit-grounding" "$QBUNDLE"
```

- [ ] **t3 — Step 2: Run test to verify it fails**

Run: `bash tests/test_audit_grounding.sh`
Expected: FAIL with "audit-grounding listed in quality bundle" failing

- [ ] **t3 — Step 3: Write minimal implementation**

Add `audit-grounding` to the `skills:` list in `bundles/quality.yml`, beside `audit-all`, `review-contracts`, `refactor-deepen`, `audit-config`. Update the bundle `description` to mention semantic-grounding divergence so consumers know what they inherit.

- [ ] **t3 — Step 4: Run test to verify it passes**

Run: `bash tests/test_audit_grounding.sh`
Expected: PASS

- [ ] **t3 — Step 5: Commit**

```bash
git add bundles/quality.yml
git commit -m "feat(bundles): add audit-grounding to the quality bundle

Co-authored-by: claude <claude@anthropic.com>"
```

---

## Task 4: Feature doc + roadmap entry

**Files:**
- Create: `docs/features/audit-grounding.md`
- Modify: `docs/roadmap.md`

- [ ] **t4 — Step 1: Write the failing test**

Append to `tests/test_audit_grounding.sh`:

```bash
DOC="$OCTOPUS_DIR/docs/features/audit-grounding.md"
check "feature doc exists" test -f "$DOC"
check "feature doc documents the guardrails+quality config" grep -q "guardrails" "$DOC"
check "roadmap has RM-088" grep -q "RM-088" "$OCTOPUS_DIR/docs/roadmap.md"
```

- [ ] **t4 — Step 2: Run test to verify it fails**

Run: `bash tests/test_audit_grounding.sh`
Expected: FAIL with "feature doc exists" failing

- [ ] **t4 — Step 3: Write minimal implementation**

Create `docs/features/audit-grounding.md` following the `docs/features/*` voice (capability summary, "When to use", "Enable" via `.octopus.yml`). Document that the **syntactic** layer (formatter, type check, secret scan, no-bypass) is covered by adopting the `guardrails` bundle with `hooks: true`, and the **semantic** layer (invented convention, false domain fact) is covered by `audit-grounding` in the `quality` bundle — signal-only. Add the **RM-088** entry to `docs/roadmap.md`.

- [ ] **t4 — Step 4: Run test to verify it passes**

Run: `bash tests/test_audit_grounding.sh`
Expected: PASS

- [ ] **t4 — Step 5: Commit**

```bash
git add docs/features/audit-grounding.md docs/roadmap.md
git commit -m "docs(audit-grounding): document the skill and the recommended guardrails config

Co-authored-by: claude <claude@anthropic.com>"
```

---

## Notes for the implementing agent

- **Open question — dispatch mechanism:** the `stop` hook is the deterministic trigger, but a bash hook cannot itself perform the LLM judgment. Resolve in Task 2 whether the hook injects an instruction for the agent to run `audit-grounding` or enqueues a request the proposals-review flow picks up. Follow the `propose-knowledge-update.sh` precedent.
- **Open question — review scope:** decide in Task 1/2 whether the semantic review runs on every task stop or only when the diff touches domain-relevant files, to control noise.
- **Syntactic layer is adopted, not built:** do not reimplement formatter/type-check/secret-scan — they ship in the `guardrails` bundle and loop-level hooks. Task 4 documents the recommended config only.
