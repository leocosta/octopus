# Spec: Fix pre-existing test failures

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-04-18 |
| **Author** | Leonardo Costa |
| **Status** | Implemented |
| **Roadmap** | RM-021 |
| **RFC** | N/A |

## Problem

Four tests have been failing on `main` since before v1.0.0 and were waved through as "pre-existing" in every subsequent PR (RM-007/008/009 in PR #30, RM-011–018 in PR #31). A stale failing test is indistinguishable from a real regression on next-person's screen; the noise encourages ignoring the whole suite. Time to clean up.

Failing tests and root causes:

| Test | Failure | Root cause |
|---|---|---|
| `test_generate_claude.sh` | `generate_claude: command not found` | Function was renamed to `generate_main_output` during the manifest-driven refactor; test wasn't updated. |
| `test_mcp_injection.sh` | `inject_mcp_servers: command not found` | Function was replaced by `deliver_mcp` + internal `_inject_mcp_*` helpers; test wasn't updated. |
| `test_gitignore.sh` | `FAIL: missing .claude/CLAUDE.md` | Test calls `update_gitignore` directly but skips the upstream step that populates `$ALL_GITIGNORE_ENTRIES` (`collect_gitignore_entries`). |
| `test_workflow_commands.sh` | `FAIL: frontmatter should be stripped` | Test greps `"^---"` across the whole delivered command file. Current command templates carry a second inline frontmatter block in the body (intentional — a Claude-readable header for slash commands). `strip_frontmatter` removes only the first block. |

## Goals

1. Every test in `tests/test_*.sh` passes on a clean checkout.
2. Tests exercise the actual current delivery path, not ghost functions.
3. Assertions remain tight — we're not deleting failing tests to hide problems; we're updating them to match the real contract.

## Non-goals

- Adding new test coverage.
- Changing setup.sh behavior to accommodate tests — setup.sh is correct; the tests are stale.
- Rewriting the whole test harness.

## Design

### Fix 1 — `test_generate_claude.sh`

Replace `generate_claude` with the current pipeline:

```bash
OCTOPUS_AGENTS=(claude)
load_manifest "claude"
generate_main_output "claude"
```

The assertions (CLAUDE.md exists, contains expected rule references) stay.

### Fix 2 — `test_mcp_injection.sh`

Replace `inject_mcp_servers` with:

```bash
OCTOPUS_MCP=(notion github)
OCTOPUS_AGENTS=(claude)
load_manifest "claude"
deliver_mcp "claude"
```

The assertions (notion + github entries present in settings.json's `mcpServers`) stay.

### Fix 3 — `test_gitignore.sh`

Chain the two steps as `setup.sh`'s main flow does:

```bash
OCTOPUS_AGENTS=(claude copilot codex)
for agent in "${OCTOPUS_AGENTS[@]}"; do
  load_manifest "$agent"
  collect_gitignore_entries "$agent"
done
update_gitignore
```

`ALL_GITIGNORE_ENTRIES` gets populated before the writer runs. The idempotency sub-test continues to work because `update_gitignore` is idempotent.

### Fix 4 — `test_workflow_commands.sh`

The assertion is wrong: "no `^---` anywhere in the delivered file" is too strict because the command template's body intentionally contains a second frontmatter-like block. Change the assertion to "the first frontmatter block was stripped":

```bash
# First 5 lines should NOT start with --- (meaning the opening frontmatter was stripped)
! head -5 "$TMPDIR/.claude/commands/octopus:pr-open.md" | grep -q "^---"
```

This correctly validates the intent — that `strip_frontmatter` ran — without flagging the legitimate body content.

## Testing

After each fix, the specific test runs green standalone:

```bash
bash tests/test_generate_claude.sh
bash tests/test_mcp_injection.sh
bash tests/test_gitignore.sh
bash tests/test_workflow_commands.sh
```

Full suite:

```bash
for t in tests/test_*.sh; do bash "$t"; done
```

Expected: **19 ok, 0 FAIL**.

## Risks

- **Fix 4 under-validates** — changing the assertion from whole-file to first-5-lines loosens the check. Mitigation: add a complementary assertion that the KNOWN frontmatter fields (`name:`, `description:`, `cli:`) don't appear anywhere, which is a tighter contract than "no `^---`".
- **Function signatures change again** — if a future refactor renames `generate_main_output` or `deliver_mcp`, these tests will break again. Not introduced by this fix; all tests that source `setup.sh --source-only` are intrinsically coupled to its internal API.

## Changelog

- **2026-04-18** — Fixed all 4 stale tests. Full suite now passes clean.
