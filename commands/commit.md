---
name: commit
description: Suggest a Conventional Commits message from the staged diff and commit after confirmation
cli: octopus commit
---

## Instructions

### Step 1 — Check staging area

Run:
```bash
git status --short
git diff --staged --stat
```

If nothing is staged:
- Show `git status` output
- Ask: "Nothing staged. Stage all changes (`git add -A`), specific files, or cancel?"
- Wait for the user's answer before continuing.
- If the user specifies files, run `git add <files>`.
- If the user says cancel, stop.

### Step 2 — Resolve language

Check in this order:
1. `.octopus/rules/common/language.local.md` — if present, use its `code:` value for commit messages.
2. `.octopus.yml` `language.code:` or `language:` (short form).
3. Detect from `git log --oneline -20` — match the dominant language in commit messages.
4. Default: **English**.

### Step 3 — Analyse the diff

Run:
```bash
git diff --staged
```

Read the diff and:
- Identify the dominant change type (`feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `style`, `ci`, `revert`).
- Identify the affected scope if obvious (module, directory, or concept).
- If the diff covers **more than one unrelated logical context**, stop and say:
  "This diff touches unrelated areas — suggest splitting into separate commits.
  Use `git add -p` to stage only one context at a time, or confirm you want a
  single commit covering all changes."
  Wait for the user's answer before continuing.

### Step 4 — Detect references

Search for tracker references in:
1. Current branch name (e.g. `feat/RM-042-...`, `fix/PROJ-123-...`)
2. Staged file paths (e.g. `docs/specs/`, `docs/adr/`)
3. Recent commits on this branch (`git log main..HEAD --oneline`)

Collect: RM-NNN roadmap IDs, Jira-style IDs (e.g. PROJ-123), GitHub issue
numbers (#N), Notion URLs. Format as footer lines (`Closes #N`, `Refs: RM-042`,
etc.). If none found, omit silently.

### Step 5 — Suggest the commit message

Write a commit message following `core/commit-conventions.md`:
- First line: `<type>(<scope>): <imperative description>` — under 72 characters,
  lowercase, no trailing period.
- Body (optional): one short paragraph explaining the *why*, wrapped at 72
  characters. Omit if the description is self-evident.
- Footer: tracker references (if any), then always the Octopus co-author trailer:
  `Co-authored-by: octopus[bot] <octopus[bot]@users.noreply.github.com>`

Show the full message in a code block, then ask:
"Use this message? (y / edit / cancel)"

### Step 6 — Commit

**y:** Run:
```bash
git commit -m "<message>"
```
Then show `git log -1 --oneline` to confirm.

**edit:** Show the message again as an editable code block. Ask the user to paste
their version. Commit with the edited message.

**cancel:** Stop without committing.
