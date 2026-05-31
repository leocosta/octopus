# Knowledge Hygiene Report

**Root(s):** {{roots}}  ·  **Date:** {{date}}  ·  **Mode:** {{mode}}

## ⚠ Warn

| Check | Node | Detail |
|---|---|---|
| staleness | `{{node}}` | {{detail}} |
| broken-link | `{{node}}` | {{detail}} |

## ℹ Info

| Check | Node | Detail |
|---|---|---|
| orphan | `{{node}}` | no inbound links |
| archive-drift | `{{node}}` | status={{status}} |

## Gaps (with `--gaps`)

| Kind | Node / Entity | Detail |
|---|---|---|
| missing-field | `{{node}}` | missing {{field}} |
| recurring-entity | {{entity}} | appears in {{count}} nodes, no home |

## Fixes applied (with `--fix`)

- `git mv {{node}} → {{archive}}` (reversible)

_Summary: {{warn_count}} warn, {{info_count}} info, {{fix_count}} fixed._
