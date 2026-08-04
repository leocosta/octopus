# Pre-Pass Protocol

**This protocol is compiled (RM-172).** It is no longer executed by reading these
steps — it runs as code, before any model call, in
`cli/lib/audit-prepass.sh`, reached through:

```bash
octopus audit-scope <skill> --base <base> --ref <ref>
```

This file remains the description of the contract; the implementation is the
authority on behaviour.

## Contract

Given a skill's `pre_pass` frontmatter, the pre-pass produces the file set that
the audit is allowed to see:

1. **Candidates** — `git diff --name-only <base>..<ref>` filtered by
   `pre_pass.file_patterns`.
2. **Early exit** — an empty candidate set ends the audit before any analysis,
   surfacing as `OCTOPUS_AUDIT_SCOPE=skip`.
3. **Line filter** — when `pre_pass.line_patterns` is present, a candidate
   survives only if an added line (`^+`) in its diff matches. An empty result
   applies the same early exit.
4. **Scoped diff** — a `## Scoped files` list plus `git diff` restricted to those
   paths. This replaces the full diff in the audit's input.

## Notes for maintainers

- `file_patterns` and `line_patterns` are YAML double-quoted scalars, so `\\.env`
  in the frontmatter is the regex `\.env`. The implementation unescapes them;
  a hand-written pipeline that skips this step will not match the same files.
- Step 3 greps `^+` over the raw diff, which also sees the `+++ b/<path>` header.
  This is preserved deliberately — it is the historical behaviour, and changing
  it would alter which files each audit reviews.
- Covered by `tests/test_audit_prepass.sh`, including verbatim parity against the
  four shipped audits.
