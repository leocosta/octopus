# Spec: extensibility-axis

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-08-29 |
| **Author** | Leonardo Costa |
| **Status** | Draft |
| **RFC** | N/A |
| **Roadmap** | RM-184 (Cluster 35) |
| **ADR** | [ADR-012](../adr/012-rigidity-evidence-measure-vs-gate.md) |
| **Research** | [extensibility-axis](../research/2026-08-29-extensibility-axis.md) |

## Problem Statement

`audit-style` owns one half of a design ruler — `over-engineering` catches
premature abstraction, speculative hierarchy and DRY-before-three — and nothing
owns the other half: code so rigid that every extension costs a multi-file
edit. The half was missing because the **evidence** was missing. Judging
rigidity by taste collides head-on with the repo's anti-over-engineering
posture, and a reviewer who argues taste against taste is one a team learns to
ignore.

The trigger is **rigidity under change**, not absence of a pattern. "A Strategy
is missing here" is not a finding. "Every new provider edits the same three
files, and it has done so eight times" is.

## Goals

- A PR review surfaces **actionable findings about the change under review**,
  not a catalogue of ambient debt.
- Rigidity and premature abstraction are judged by **one measurement**, not two
  tastes: abstraction without co-change is premature; co-change without
  abstraction is rigidity.
- No PR is ever blocked for rigidity the diff did not enlarge.
- The evidence costs ~0 LLM tokens and runs in **any repo** — no `quality`
  bundle, no `lizard`/`madge`, no CI, any language.

## Non-Goals

- Static fan-out / import-graph analysis (needs a per-language parser).
- Declared future change (roadmap/ADR) as a trigger — measurement only.
- A new artifact for readability; it is already covered by `audit-style`, the
  native `simplify`, and the `code-metrics` v2 counters.
- Changing `code-metrics`, its thresholds, its report, or the orphan-ref
  baseline contract. `hotspots` must behave identically after this change.
- Extracting the shared layered-config resolver — that is RM-185.
- Auto-applying a refactor. The axis reports and classifies; it never edits.

## Design

### Overview

Three seams, matching ADR-012:

```
octopus git-signals        (deterministic, ~0 tokens, git only)
        │  churn + co-change clusters + diff verdict
        ▼
audit-style  (haiku)       emits `rigidity` finding — signal-only, never blocks
        │
        ▼
architect    (opus)        classifies BLOCKING/ADVISORY, names principle+pattern
        │
        ▼
mentor       (opus)        teaches the why, citing rules + ADR-012
```

### Detailed Design

#### 1. `cli/lib/git-signals.sh` — the deterministic core

Dispatched as `octopus git-signals`. Pure `git` + `awk`; no stack detection, no
external tooling, no network, no orphan ref.

```
octopus git-signals [--base <ref>] [--ref <ref>] [--window <days>] [--verbose]
```

**Churn.** `cm_git_churn` moves here verbatim from `code-metrics-lib.sh`;
`code-metrics-lib.sh` sources this file so `hotspots` keeps working unchanged.
This is a move, not a copy — there must remain exactly one implementation.

**Co-change clusters.** One pass of
`git log --since="<window> days ago" --format='C %H' --name-only`, then awk:

1. Group changed paths per commit.
2. Drop commits touching more than `max_files_per_commit` paths (default 25) —
   a mass rename or a merge is not evidence of conceptual coupling.
3. For each unordered pair `(A,B)` co-occurring in a commit, increment
   `support(A,B)`; also count `commits(A)` per path.
4. Keep a pair when `support >= min_support` **and**
   `cohesion = support / (commits(A) + commits(B) - support) >= min_cohesion`.
   Cohesion is **Jaccard**, not `support / min(A,B)`. A file that changes on
   nearly every commit — a lockfile, a changelog — co-occurs with everything;
   dividing by the smaller side scores it 1.0 against every partner and drags
   the whole repo into one cluster. Jaccard charges it for its own solo
   commits, so it falls out while a genuine trio stays at 1.0. (Found by the
   test fixture, not by inspection: `min()` was implemented first and the
   changelog case caught it.)
5. Clusters are the connected components of the surviving pairs; keep those of
   at least `min_cluster` members.

**Diff verdict.** With `--base`/`--ref`, intersect the changed paths with each
cluster and emit:

- `members_touched` — how many cluster members the diff touches.
- `outsiders` — changed paths that are not members.
- `enlarges: true` when `members_touched >= 2` **and** `outsiders >= 1`.

`enlarges` is the whole gate, so it is defined mechanically rather than by
judgment: the diff is reproducing the very co-change pattern that defines the
cluster *and* pulling a new file into it. Touching one member is passing
through; touching two and adding a third is joining.

**Output** — flat `key:value` lines, mirroring `code-metrics`:

```
=== git-signals ===
window_days: 90
status: ok

cluster:1 size:3 support:8 cohesion:1.00 members_touched:2 outsiders:1 enlarges:true
  member: payments/providers/index.ts churn:47 touched:true
  member: payments/config/registry.ts churn:39 touched:true
  member: payments/providers/boleto.ts churn:31 touched:false
  outsider: payments/providers/pix.ts
```

**Ranking and ceiling.** Clusters are sorted by `enlarges` first, then
`support`, then `size`. Only the top `max_findings` (default **1**) are
printed. This is where the success criterion is enforced: one finding, about
this change.

**Degradation — never a silent zero.** `status:` is `ok`, or
`unavailable:<reason>` with `shallow-clone`, `no-git`, `empty-window`, or
`not-a-repo`. Detection: `git rev-parse --is-shallow-repository` is `true`, or
the window contains fewer than `min_support` commits. On `unavailable`, **no
cluster lines are printed at all** — the caller must not be able to read
absence as evidence. This is the explicit break with `hotspots`, which answers
`0` when `lizard` is missing.

#### 2. Config

A new `git_signals:` block, same layering as `code_metrics:`
(workspace < personal < project; project wins):

```yaml
git_signals:
  cochange:
    window_days: 90
    min_support: 5
    min_cohesion: 0.6
    min_cluster: 3
    max_files_per_commit: 25
    max_findings: 1
```

Rather than a third copy of the resolver, `cm_override` gains a single
indirection: the root block name comes from `${CM_CONFIG_ROOT:-code_metrics}`
instead of the literal. `git-signals.sh` then calls
`CM_CONFIG_ROOT=git_signals cm_field_or cochange window_days 90`. Signatures are
unchanged, `code_metrics` behaviour is unchanged by default, and the numeric
guard in `cm_field` — the security boundary that stops attacker-influenceable
config from reaching awk as program text (closed in the #175 review) — is
inherited rather than reimplemented. Collapsing the three readers is RM-185.

#### 3. `audit-style` — the `rigidity` finding

Protocol gains a step between "hunt over-engineering" and "report": run
`octopus git-signals --base <base> --ref <ref>`, and for each cluster returned
emit one `rigidity` finding.

The finding carries **evidence only**. The Haiku tier does not name principles
or patterns — it reports what the tool measured:

- anchor: the diff path that enlarges the cluster (or the touched member with
  the highest churn when nothing is enlarged);
- cluster members with churn, and which the diff touched;
- `support`, `cohesion`, `window_days`, and `enlarges`.

Tier stays `warn`/`info`, **never `block`** — the signal-only contract is
untouched. `status: unavailable` produces one `info` note naming the reason and
no `rigidity` finding.

The trailer becomes `audit-style: 0 block, N warn, N info` as today, with
rigidity findings counted in.

#### 4. `architect` — classification and naming

A new approval-criteria subsection under **3. Architecture**:

| Condition | Classification |
|---|---|
| `enlarges:true` | `BLOCKING` |
| cluster touched, `enlarges:false` | `ADVISORY` |
| `status: unavailable` | `QUESTION`, tagged `evidence-unavailable` |

`architect` — not the Haiku tier — names the SOLID principle and, when one
applies, the GoF pattern. The naming rule is binding: **a pattern is never
named without the evidence line that justifies it.** Where a pattern is
proposed, the existing ADR trigger ("a new pattern is introduced") applies, and
the co-change evidence is what populates that ADR's Context.

The role also gains the inverse reading, which is what makes the ruler one
ruler: an abstraction the diff introduces **without** co-change evidence stays
`premature abstraction`, exactly as today.

#### 5. `mentor`

No structural change. `rigidity` is another origin-tagged finding; the teaching
unit cites `rules/common/patterns.md`, `coding-style.md` and ADR-012.

### Finding shape vs. anchor verification

`pr-review` Phase 4.5 runs `octopus review-anchor`, which verifies a single
`path:line` and demotes what it cannot resolve to `QUESTION`/`unanchored`. A
rigidity finding names a cluster, so it **must** anchor on one real diff line —
the outsider path that enlarges the cluster — and carry the remaining members
as evidence text, not as anchors.

Phase 4.55 needs no change: its prompt already instructs `keep` when the window
cannot judge "a claim about coupling across files", which is precisely this
finding's shape.

### Migration / Backward Compatibility

- `hotspots` output must be byte-identical before and after the `cm_git_churn`
  move; the existing `test_code_metrics` sections are the regression net.
- `git_signals:` absent from `.octopus.yml` means defaults — no config
  required to adopt.
- `audit-style` in a repo with an older CLI: `octopus git-signals` missing is
  treated as `status: unavailable:no-command`, one `info` note, no finding.
- No change to the orphan ref, the writer Action, or any bundle membership —
  `audit-style` and `architect` are already both in `quality`.

## Implementation Plan

1. **`cli/lib/git-signals.sh`** — move `cm_git_churn`; add `gs_cochange`
   (pair support/cohesion, connected components), `gs_diff_verdict`,
   `gs_status`, ranking and the report writer.
2. **`cli/lib/code-metrics-lib.sh`** — source `git-signals.sh`; delete the
   moved `cm_git_churn`; swap the literal `code_metrics` in `cm_override` for
   `${CM_CONFIG_ROOT:-code_metrics}`.
3. **`cli/lib/commands.default`** — register `git-signals`.
4. **`skills/audit-style/SKILL.md`** — the new protocol step, the `rigidity`
   finding type, the report shape, the unavailable path, and the note that
   naming is `architect`'s job.
5. **`roles/architect.md`** — the classification table, the naming rule, and
   the inverse (premature-abstraction) reading.
6. **`skills/audit-style/SKILL.md`** — document the `git_signals:` block where
   `code-metrics` documents its own (in the SKILL, not `.octopus.example.yml`,
   which carries no `code_metrics:` block either).
7. **`tests/test_git_signals.sh`** — new suite (below).
8. **Docs site** — `docs/site/` EN + pt-br pages for the command and the
   updated skill/role pages, then `sync-content` + `build`.

## Context for Agents

**Knowledge modules**: [architecture, review-engine]
**Implementing roles**: [backend-developer, architect]
**Related ADRs**: [ADR-002, ADR-012]
**Skills needed**: [audit-style, code-metrics, test-tdd]
**Bundle**: `quality (existing)` — `audit-style` and `architect` are already
members; no new skill and no new bundle is introduced.

**Constraints**:
- Pure bash + awk. No `jq`, no Python, no network, no per-language parser.
- Must run with no `.octopus.yml`, no CI, no orphan ref, in any language.
- `code-metrics` behaviour, including `hotspots`, must not change.
- `audit-style` must never emit a `block` tier.
- Config values reaching awk must pass the existing numeric guard.
- Absence of evidence is never reported as `0`.

## Testing Strategy

New `tests/test_git_signals.sh`, built on throwaway fixture repos created with
`git init` + scripted commits (the churn window is real history, so fixtures
must be real commits):

- **Clustering** — three files committed together 8× produce one cluster of 3;
  a file changed alone every commit (changelog-style) is excluded by the
  cohesion rule; a 40-file commit is dropped by `max_files_per_commit`.
- **Verdict** — touching 1 member ⇒ `enlarges:false`; touching 2 members plus a
  new path ⇒ `enlarges:true`; touching 2 members and no outsider ⇒ `false`.
- **Ranking/ceiling** — with two qualifying clusters and `max_findings:1`, only
  the enlarging one is printed.
- **Degradation** — a shallow clone yields `status:unavailable:shallow-clone`
  and **zero** cluster lines; a non-repo yields `not-a-repo`.
- **Config** — `git_signals.cochange.window_days` overrides the default;
  project layer beats personal; a non-numeric value is rejected by the guard.
- **Regression** — `test_code_metrics` must stay green, proving the
  `cm_git_churn` move and the `CM_CONFIG_ROOT` indirection changed nothing.
- **Injection** — a `.octopus.yml` carrying awk metacharacters in a numeric
  field is rejected, mirroring the #175 guard tests.

## Risks

- **Noise.** The dominant failure mode. Mitigated by `max_findings:1`, the
  cohesion rule, and ranking `enlarges` first — but the thresholds are
  guesses until they run against a real repo. First adopter should run
  `--verbose` on a mature repo before the gate is trusted.
- **Cargo-cult patterns.** Mitigated by moving naming to `architect` and by the
  binding evidence rule; residual risk if a reviewer reads the pattern name and
  skips the evidence.
- **Performance.** `git log --name-only` over 90 days on a large monorepo is
  the only cost; bounded by the window and by `max_files_per_commit`. Needs a
  timing check on the largest repo in the fleet.
- **Rename blindness.** Co-change is path-based; a renamed file starts a fresh
  history and its cluster membership resets. Accepted for v1 — `--follow` does
  not compose with multi-path log traversal.
- **Vocabulary collision.** SOLID/GoF vs. `refactor-deepen`'s fixed lexicon.
  Mitigated by layering them explicitly (structure vs. force vs. form) in the
  `architect` change.

## Changelog

- **2026-08-29** — Initial draft. Thresholds, finding shape, and the
  `enlarges` definition resolved from the RM-184 open questions.
