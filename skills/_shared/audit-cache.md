# Audit Output Cache Protocol

**This protocol is compiled (RM-172).** It is no longer executed by reading these
steps — it runs as code, before any model call, in `cli/lib/audit-cache.sh`,
reached through:

```bash
octopus audit-scope <skill> --base <base> --ref <ref>          # check
octopus audit-scope <skill> --write <key> --from <report-file> # persist
```

This file remains the description of the contract; the implementation is the
authority on behaviour.

## Contract

- **Key** — `sha256( scoped_diff || sha256(SKILL.md) )`, truncated to 64 chars.
  A change to either the reviewed diff or the skill definition invalidates.
- **Entry** — `.octopus/cache/<skill>/<key>.md`, carrying `skill`, `ref`, `base`
  and `created_at` frontmatter above the audit's verbatim output.
- **Hit** — the stored body is returned with its frontmatter stripped, surfacing
  as `OCTOPUS_AUDIT_SCOPE=cached`. No model call happens.
- **Guard** — `.octopus/cache/` is appended to `.gitignore` once; failure to
  write warns and never aborts.

## Notes for maintainers

- The key derivation is byte-compatible with the pre-RM-172 prose version, so
  entries written before the change still hit. `tests/test_audit_cache.sh` pins
  this against the literal derivation.
- `sha256sum`, `shasum -a 256` and `openssl dgst -sha256` are all accepted and
  must agree — a cache written on Linux has to be readable on macOS, where
  `sha256sum` is absent. `AUDIT_CACHE_HASH_TOOL` pins one for testing.
- **Known limitation:** the key covers the diff and the SKILL.md, not the active
  ruleset. A change under `rules/common/` does not invalidate cached reports.
  Deliberate for now — revisit if rule edits start going stale in review output.
