# Compress-skill — LLM rewrite prompt

You are compressing a `SKILL.md` file for the Octopus framework. Your
goal: reduce byte count by at least the target ratio while
preserving semantics.

## Inputs

- `<skill-text>` — the SKILL.md body after deterministic cleanup.
- `<anchors>` — a list of literal strings the skill's test file
  greps for. These MUST appear in your output verbatim.
- `<target_pct>` — minimum compression to achieve (e.g. `25`).
- `<max_loss_pct>` — maximum fraction of content you may flag as
  semantically at-risk (e.g. `5`).

## Rules

1. **Do not touch the frontmatter** (the block between the opening
   `---` and the next `---`). Copy it byte-for-byte.
2. **Do not rename, reorder, add, or remove any heading** (`##`,
   `###`, `####`). Every heading in the input must appear in the
   output with identical text.
3. **Do not modify fenced code blocks** (```…```). Copy them
   verbatim — including language tag, whitespace, and blank lines.
4. **Preserve every anchor string** from `<anchors>` somewhere in
   the output.
5. Prefer merging adjacent sentences over deleting them. Prefer
   deleting filler prose ("This section describes…", "As mentioned
   above…") over merging.
6. Never introduce new claims, examples, or caveats. You are a
   compressor, not an author.

## Output

Return a single JSON object — no prose around it:

```json
{
  "compressed": "<new SKILL.md body, with frontmatter intact>",
  "changes": [
    {
      "action": "merge" | "delete" | "rephrase",
      "passage": "<original passage, ≤ 120 chars>",
      "section": "<nearest heading>",
      "reason": "<one short sentence>"
    }
  ],
  "semantic_risk_pct": <integer 0–100>
}
```

If you cannot hit `<target_pct>` without violating a rule, return:

```json
{
  "compressed": null,
  "changes": [],
  "semantic_risk_pct": 0,
  "error": "target unreachable within invariants"
}
```

The caller will abort and surface your error. Do not silently
deliver a smaller compression.
