# Design: `doc-api` — Assess & Plan generation flow

| Field | Value |
|---|---|
| **Date** | 2026-07-24 |
| **Author** | Leonardo Costa |
| **Status** | Draft |
| **Roadmap** | RM-162 (new) |
| **Extends** | `doc-api.md` (RM-161, shipped v1.89.0) |

## Problem Statement

`doc-api` ships two modes today: `validate` (read-only fidelity report) and
`--write` (regenerate `openapi.yaml` + integrator reference behind a single
all-or-nothing confirmation gate). There is no middle ground between "tell me
what drifted" and "regenerate everything". Two gaps follow from that binary:

1. **Create-from-scratch is a second-class path.** When no spec or integrator
   doc exists, `--write` only *offers to generate one* from an error branch
   (`doc-api.md` §8). Bootstrapping documentation for an undocumented API is a
   first-class use case, not an error recovery.
2. **The user cannot choose fix vs recreate per artifact.** `--write` today
   regenerates wholesale. A team with a hand-curated integrator reference that
   drifted in three places has no way to say "patch those three, leave the prose
   alone" — regeneration discards their curation. The inverse (a legacy doc so
   divergent that patching is noise, better rebuilt) is equally unserved.

The user wants a single flow that, from the code + OAS, **assesses what can be
generated or corrected, then lets them pick — per artifact — between correcting
the existing doc and recreating it from scratch**, before anything is written.

## Goals

- Add an **Assess & Plan** stage to `doc-api` that runs in both modes: rendered
  as a read-only report section without `--write`, and as an **interactive
  per-artifact plan** under `--write`.
- Under `--write`, present each artifact (× API version) with its assessed state
  and offer `correct` / `recreate` / `skip` (or `create` when absent); the user
  chooses **item by item**; only chosen items are written.
- Make **create-from-scratch a first-class action**, not an error branch.
- Define **correct** as a minimal surgical patch that preserves hand-authored
  prose, ordering, and examples that are not drift; define **recreate** as a
  wholesale rebuild from the code contract.
- Surface **breaking-change impact on the chosen action** inline in the plan,
  before the user commits to it.
- Reuse the existing four checks (`openapi`/`errors`/`breaking`/`grounding`) as
  the evidence behind each artifact's assessed state — no new checks.

## Non-Goals

- **No new command, mode, or flag.** The behavior lives inside the existing
  `--write` path (chosen packaging: evolve `--write`). Invocation is unchanged.
- **No scope beyond the API surface.** Specs, ADRs, README, and `CONTEXT.md`
  are out of scope — `doc-api` remains an API-contract tool.
- Error catalog stays a **section of the integrator reference**, not a separate
  artifact.
- Does **not** modify application code (unchanged guardrail).
- Does **not** change validate mode's read-only guarantee, the `audit-grounding`
  reuse, full-tree discovery, or the `audit-all` exclusion.

## Design

### 1. Positioning

An additive change to the `doc-api` skill (RM-161). Same command, same bundle
(`docs`), same model tier (`sonnet`), same on-demand / no-hook / not-in-`audit-all`
posture. The only behavioral change is internal to the pipeline.

### 2. Invocation (unchanged)

```
/octopus:doc-api [--write] [--only=<checks>] [--stacks=<list>] [--spec=<path>] [--out=<path>] [--base=<ref>]
```

No new flags. `--write` gains the interactive per-artifact plan; the default
(validate) mode gains a read-only preview of the same plan.

### 3. Pipeline

Insert **Assess & Plan** between Extract and Document; run Assess in both modes
(one assessment, two renderings — DRY):

```
Discover → Extract → Assess ─┬─ (no --write) → render as read-only report section
                             └─ (--write)     → interactive Plan → Generate (chosen items only)
```

1. **Discover / Extract** — unchanged (`doc-api.md` §3, §3a). Endpoints, DTOs,
   enums, envelopes, status codes, error responses, auth rules; per API version.
2. **Assess** — classify each canonical artifact (× version) using the four
   checks as evidence (see §4).
3. **Plan** (`--write`) — render the per-artifact plan and collect the user's
   per-item choice (see §5).
4. **Generate** (`--write`) — apply only the chosen actions behind the write
   gate (see §6).

### 4. Artifact state model

The canonical artifacts are the two from `doc-api.md` §5 — the OpenAPI spec and
the integrator reference — assessed **per API version**.

| State | How it is detected | Actions offered |
|---|---|---|
| `absent` | file does not exist at the resolved/confirmed path | `create` |
| `stale` | drift found by `openapi` / `errors` / `grounding` | `correct` / `recreate` / `skip` |
| `ok` | no drift found | `skip` (default) / `recreate` |

State is **derived from the existing checks**, not a new signal:

- `openapi` drift → the **OpenAPI spec** state; its endpoint/envelope portion
  also flows to the integrator reference, whose endpoint-reference and envelopes
  sections document the same surface.
- `errors` + `grounding` drift → the **integrator reference** state (the error
  catalog and business rationale are sections of it).
- `breaking` → not a state; it **annotates the chosen action** (see §5).

An artifact is `stale` if any check that feeds it reports drift.

### 5. The plan and the three actions

Under `--write`, print the plan: each artifact × version, its state, and the
available actions. The user chooses one action per item.

**Action semantics:**

- **`correct` (surgical patch)** — apply the minimal set of edits that closes
  the drift the Assess found (missing endpoint, divergent type, stale error
  message), **preserving hand-authored prose, ordering, and examples** that are
  not drift. For curated docs that only went stale in spots.
- **`recreate` (wholesale)** — rebuild the artifact from the code contract,
  **discarding the existing structure**. For docs so divergent or legacy-shaped
  that patching is noise.
- **`create` (from scratch)** — no artifact exists; generate a fresh one at the
  confirmed path. A first-class action, not an error branch.
- **`skip`** — leave the artifact untouched.

**Breaking-change annotation.** The `breaking` check (diffed per version against
the baseline — committed `openapi.yaml` at `HEAD`, or `--base`) annotates any
action that would make the spec reflect a divergence already present in the
code. Such an item is marked 🚫 in the plan with the specific changes, e.g.
*"recreate `openapi.yaml` (v1) applies 2 breaking changes vs baseline: field
`order.total` removed, `status` retyped string→enum — confirm?"*. Nothing
breaking is written silently.

**Validate-mode rendering.** Without `--write`, the same Assess renders as a
read-only **Improvement Plan** section appended to the fidelity report: each
artifact, its state, and what `correct` / `recreate` / `create` *would* do — no
prompts, no writes. This keeps the two modes consistent (advisory preview vs
actionable flow) at no extra cost.

### 6. Write gate (`--write`) — the plan is the gate

The existing gate (`doc-api.md` §6: print paths → confirm/override → show
diff → write all) becomes the **per-artifact interactive plan**:

1. Print the plan: each artifact × version with state and available actions.
2. Per item, the user chooses `correct` / `recreate` / `create` / `skip`;
   autodetected paths are shown as defaults and may be overridden (legacy
   layouts preserved, as today).
3. Show the **diff of the chosen action** per item (minimal patch for `correct`;
   full file for `recreate` / `create`).
4. On final confirmation, write **only the chosen items**.

Unchanged: `--write` never touches application code; all written artifacts are
English.

### 7. Composition and reuse (unchanged)

- Reuses `_shared/audit-output-format.md` and the `audit-grounding`
  source-of-truth protocol for `grounding`. Full-tree discovery, not the
  diff-scoped `_shared/audit-pre-pass.md`.
- Registered in the `docs` bundle. Not referenced by `audit-all`.

### 8. Errors

Inherits `doc-api.md` §8. The one behavioral change:

- **No OpenAPI spec found, `--write`** → no longer an offer from an error
  branch. The spec artifact is assessed as `absent` and appears in the plan with
  the first-class `create` action.

## Testing

Bats-style skill tests extending the RM-161 suite:

- Assess classifies an existing-but-drifted integrator reference as `stale` and
  offers `correct` / `recreate` / `skip`; a missing `openapi.yaml` as `absent`
  with `create` only; a clean artifact as `ok` with `skip` default.
- `correct` on a stale integrator reference patches only the drifted lines and
  leaves hand-authored prose/examples untouched (diff is minimal).
- `recreate` rebuilds the artifact wholesale and the diff replaces the whole
  file.
- `create` generates a fresh artifact at the confirmed path when none exists (no
  longer routed through the error branch).
- Per-item selection writes only chosen artifacts; a `skip` item is left
  byte-identical.
- Breaking annotation: recreating a spec that would drop a field is marked 🚫 in
  the plan with the specific change before the user confirms.
- Validate mode renders the Improvement Plan section and writes nothing.
- Per-version: v1 and v2 artifacts assess and plan independently.

## Rollout

1. Land the skill change and extended tests (this spec → plan → implement).
2. Add RM-162 to `docs/roadmap.md`, referencing this spec.
3. Ship in the next release cut from `main`.
