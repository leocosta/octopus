# Audit Output Cache Protocol

## Cache Check (before LLM analysis)

Execute immediately after the Pre-Pass produces SCOPED_DIFF, before any inspection check.

**Step 1 — compute CACHE_KEY**

```bash
SKILL_HASH=$(sha256sum <path-to-this-SKILL.md> | cut -c1-64)
CACHE_KEY=$(echo -n "${SCOPED_DIFF}${SKILL_HASH}" | sha256sum | cut -c1-64)
```

**Step 2 — check for hit**

```
CACHE_FILE=.octopus/cache/<skill-name>/<CACHE_KEY>.md
```

If `CACHE_FILE` exists:
- Strip the YAML frontmatter (lines between the first `---` and the closing `---`)
- Print the body as-is
- Stop — do not proceed to inspection checks

**Step 3 — on miss: proceed**

Continue to inspection checks normally. After the LLM produces its full output, execute the Cache Write steps below before returning to the user.

## Cache Write (after LLM produces output)

**Step 4 — ensure directory exists**

Create `.octopus/cache/<skill-name>/` if it does not exist.

**Step 5 — write cache file**

Write `CACHE_FILE` with this structure:

```
---
skill: <skill-name>
ref: <ref argument>
base: <base branch>
created_at: <current UTC datetime in ISO 8601>
---

<full audit output exactly as printed to the user>
```

**Step 6 — .gitignore guard**

If `.octopus/cache/` is not present in the repo's `.gitignore`, append it.
Warn the user if `.gitignore` cannot be written; do not abort.
