# Pre-Pass Protocol

## Pre-Pass (deterministic file discovery)

Execute before LLM analysis. Steps run in order; abort the skill at Step 2 if no candidates are found.

**Step 1 — candidate files**

Run:
```
git diff --name-only <base>..<ref> | grep -E "<pre_pass.file_patterns from this skill's frontmatter>"
```
Store the result as `CANDIDATE_FILES` (newline-separated list of file paths).

**Step 2 — early exit**

If `CANDIDATE_FILES` is empty, print:
```
no <skill-domain> changes detected
```
and stop. Do not proceed to inspection checks.

**Step 3 — optional line filter**

If this skill's frontmatter defines `pre_pass.line_patterns`, apply a secondary filter.
For each file in `CANDIDATE_FILES`, check whether it contains at least one added or changed line matching the pattern:
```
git diff <base>..<ref> -- <file> | grep -E "^\+" | grep -qE "<pre_pass.line_patterns>"
```
Remove files that do not match. If all files are removed, apply the same early exit as Step 2.

**Step 4 — scoped diff output**

Produce the input for LLM analysis:
```
## Scoped files
<CANDIDATE_FILES — one path per line>

<git diff <base>..<ref> -- <CANDIDATE_FILES>>
```
Pass this output to the LLM in place of the full diff. Do not re-run `git diff` without the file filter.
