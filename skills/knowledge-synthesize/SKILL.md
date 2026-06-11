---
name: knowledge-synthesize
model: haiku
description: >
  Surface cross-node connections in a knowledge root. The deterministic core
  (octopus synthesize, over the octopus kr registry) ranks candidates —
  shared-target, co-mention, and --node relevance (forgotten-but-relevant);
  this skill judges which are real, flags contradictions, and seeds missing
  links with --fix.
triggers:
  paths: ["docs/**", "knowledge/**", "CONTEXT.md"]
  keywords: ["synthesize", "connection", "related", "forgotten", "contradiction"]
  tools: []
---

# /octopus:knowledge-synthesize

## Purpose

A knowledge base is worth more than the sum of its notes only if something
*traverses* it and surfaces links manual recall misses. Every root is a silo by
default. This skill surfaces cross-node connections and the forgotten-but-relevant
past note, and flags where a node contradicts an authority it cites.

The mechanical candidate-finding is deterministic in the `octopus synthesize`
core, which reads nodes and links from `octopus kr`. This skill adds the
judgment the core can't make.

## Invocation

```
/octopus:knowledge-synthesize [--root <id>] [--node <path>] [--fix]
```

- `--root <id>` — one root (e.g. `docs`, `memory`, `consigliere`); default: every resolved root.
- `--node <path>` — forgotten-but-relevant lookup for that node (ranked by shared entities).
- `--fix` — seed a missing link where a mention resolves to exactly one node.

Run the core directly with `octopus synthesize [--root <id>] [--node <path>] [--fix]`.

## Signals

Each candidate is one line: `kind|root|a|b|signal|score`.

- **shared-target** — node pair `a`,`b` that both link the same third node (`signal`); `score` = intersection size. They relate via that target.
- **co-mention** — an entity (`a`) appearing across `score` nodes with no node of its own. A recurring topic with no home.
- **relevant** — (with `--node`) other nodes ranked by shared-entity overlap with the focus node.

## Contradiction

The core does **not** decide contradictions — it surfaces a node together with the authorities it links (e.g. ADRs). Read the node and its linked authority; judge whether the node asserts something the authority negates, and report it with the citing line. This is the judgment that justifies the skill over the bare core.

## Fix Mode

`--fix` seeds a relative link only when a mention's entity resolves to **exactly one** node title (unambiguous) and the link is not already present. Multi-target or fuzzy matches stay report-only. The edit is a plain append the user can `git revert`.

## Entity Extraction (language-neutral core + LLM free-text pass)

The deterministic core's `ks_entities` extracts only **structural, language-neutral** entities — `[[mentions]]` and `` `code` `` spans. It does **not** guess free-text entities: a hardcoded English regex + stopword list would miss accented entities (`[[Política Fiscal]]`, `Gestão de Estoque`) and silo every non-English root.

**Free-text / multilingual entity detection is yours (the LLM).** When a root is not wikilinked (e.g. `docs/` with relative links), read the nodes and identify the proper nouns / domain terms in **whatever language they are written in** — pt-br, en, etc. This linguistic step is exactly what the model layer is for.

**Run this free-text pass on the cheapest model tier.** It is light NLP, not reasoning — the costly structural work already happened for free in bash. When dispatching it through Octopus, route to the cheapest model (Claude: `octopus ask <role> --skill knowledge-synthesize --model haiku "…"`; other assistants: their fastest/cheapest model). Do not spend a frontier model on entity tokenization.
