# Manager Workspace (consigliere)

Your **private** chief-of-staff workspace. It digests diverse inputs (meeting
transcripts, Slack, Jira, Confluence) into living, grounded memory you can track
and query — the details that never make it into Jira.

> **Private by design.** Nothing here is ever committed to a team repo. Keep this
> repository private. See `.gitignore`.

## The model

- **Context** — a *perennial* node in a tree of arbitrary depth
  (product → domain → sub-domain). Each node has its own materialized state.
  Example: `commerce` → `catalog`.
- **Project** — a *temporal* effort (start/middle/end), **cross-cutting**: it can
  span several contexts and workspaces. Example: `checkout-revamp` crosses `payments`
  and `fulfillment`. It lives under `projects/` and links the contexts it touches via
  `meta.yml`.

## Layout

```
.
├── sources/YYYY/MM/<date>-<slug>.<ext>   # raw inputs, IMMUTABLE — the grounding base
├── contexts/<ctx>/[<subctx>/...]         # perennial tree
│   ├── state.md                          # materialized current state (6 fixed sections)
│   ├── journal.md                        # append-only dated log
│   └── playbook.md                       # heuristics (optional)
├── projects/<proj>/                      # temporal, cross-cutting
│   ├── meta.yml                          # contexts: [...], status, dates
│   ├── state.md
│   ├── journal.md
│   └── playbook.md
└── people/<person>.md                    # per-person heuristics
```

Every node — context or project — carries the same trio: **`state.md`**
(materialized) + **`journal.md`** (append-only, dated) + **`playbook.md`**
(heuristics, optional).

## The digest contract (6 fields)

Each digest extracts exactly: **Status por frente · Impedimentos+dono · Decisões ·
Mapa de sistemas/áreas · Ações+owners · Riscos políticos**. These are the fixed
section headers in every `state.md`.

## Grounding

Every claim in `state.md` / `journal.md` traces back to a line in `sources/` via a
`(src: …)` anchor. If it is not in a source, it is not asserted — when in doubt,
the agent asks.

## Workflow

1. `/octopus:digest-source <text | pdf | JIRA-123 | confluence-url> "natural-language description"`
   → snapshot to `sources/` → infer context/project → confirm → preview → write.
2. `/octopus:context-status` → ask "how's payments? what's blocked?" over the materialized state.
3. `/octopus:playbook-review` → seed and promote heuristics.

This workspace was scaffolded by `/octopus:consigliere-bootstrap`.
