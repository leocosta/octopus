---
name: code-metrics
description: PR-time dual-delta read of coverage/complexity/module-size/dependency-cycles vs. orphan-ref baseline; ratchet+absolute thresholds; LLM curation only on breach.
triggers:
  paths: ["**/*.cs", "**/*.ts", "**/*.tsx", "**/*.js"]
  keywords: ["code metrics", "coverage", "complexity", "module size", "dependency cycles", "code-metrics"]
  tools: []
---

# /octopus:code-metrics

## Purpose

Give the PR author a local, non-blocking read of how their change moves a
fixed set of deterministic code metrics **before** they open the PR. Two
deltas are always reported:

- **vs_baseline** — change versus the last-main baseline (trend anchor stored
  on the `octopus/code-metrics` orphan ref after each merge to `main`)
- **vs_main** — change versus local `main` HEAD (this-PR's direct impact)

Numbers are computed cheaply by stack-specific tooling (zero LLM tokens in
the common case). A low-cost (Haiku-class) model is invoked **only** when a
metric crosses its threshold, to explain the regression and suggest a fix.

This is a **signal, never a gate**. It does not block the PR.

## Invocation

```
/octopus:code-metrics [--stack <csharp|typescript>] [--metric <name>] [--verbose]
```

- `--stack <name>` — force the adapter (default: auto-detected via stack-detection).
- `--metric <name>` — report only one metric (default: all four).
- `--verbose` — show raw tooling output alongside the summary.

Run the deterministic core directly: `octopus code-metrics [args]`

## Metrics (v1)

| Metric | Direction | Default threshold |
|---|---|---|
| `coverage` | higher is better | ratchet only (no regression) |
| `complexity` | lower is better | ratchet only (per-function cyclomatic) |
| `module_size` | lower is better | ratchet only (lines per module) |
| `dependency_cycles` | lower is better | ratchet only (cycle count) |

## Dual Delta

```
metric:coverage     current:78.5  vs_baseline:+3.5  vs_main:+1.2
metric:complexity   current:9     vs_baseline:-1    vs_main:0
metric:module_size  current:340   vs_baseline:-10   vs_main:+5
metric:dependency_cycles current:0 vs_baseline:0   vs_main:0
```

`vs_baseline` separates the **trend** question ("is the codebase improving
over time?") from `vs_main` which answers the **PR impact** question ("what
did this PR actually change?").

## Threshold Configuration

Thresholds live in `.octopus.yml` under `code_metrics:` with
**per-field, per-layer** resolution (`default < workspace < personal <
project`; **project wins**). A field absent from all layers defaults to
**ratchet only** — a change may not regress versus baseline, but there is no
absolute floor or ceiling.

```yaml
code_metrics:
  coverage:
    min: 80          # absolute floor; ratchet applies if below this
    test_filter: "Category!=Integration"   # (C#) dotnet test --filter; e.g. unit-only
    settings: api/coverage.settings.xml     # (C#) dotnet-coverage settings (scope/excludes)
  complexity:
    max: 10          # absolute ceiling per function
  module_size:
    max: 400         # absolute ceiling in lines
  dependencies:
    cycles_allowed: 0
```

`coverage.test_filter` and `coverage.settings` are **string** fields (not numeric
thresholds). They let a repo run coverage over a subset — e.g. unit tests only,
leaving slow e2e/integration tests as a separate CI gate — and scope the
dotnet-coverage report to production assemblies (excluding generated code such as
EF migrations). They are honoured by the C# adapter; absent fields are no-ops.

Precedence order: workspace → personal → **project (wins)**. The committed repo
state is authoritative for a quality contract.

## Ratchet vs. Absolute Thresholds

- **Ratchet (default)** — a metric may not regress versus the baseline. Legacy
  repos are never immediately "red"; only *new* regressions are flagged.
- **Absolute** — set an explicit floor/ceiling in config. When the absolute
  threshold is satisfied, the ratchet is not additionally checked.

## LLM Curation on Breach

When a metric crosses its threshold the skill fires a low-cost (Haiku-class)
model call with:
- The specific metric name, current value, threshold, and delta
- A diff snippet of the files that moved the metric

The model is asked to: (a) identify the concrete cause of the regression
(e.g. a god-function, an uncovered code path), and (b) suggest a minimal
targeted fix. Token cost is proportional to the diff of the offending files
only; it is zero when nothing regresses.

The harness's low-cost model is resolved as:
- **Claude Code**: `claude-haiku-4-5` (or the current Haiku-tier release)
- **Other harnesses**: the `OCTOPUS_LOW_COST_MODEL` env var if set, else the
  harness default

## Baseline Store (orphan ref)

Baseline snapshots are stored on the `octopus/code-metrics` orphan ref
(not on `main` or any protected branch) as a single `baseline.json` file.

```json
{
  "commit": "abc123",
  "timestamp": "2026-06-01T00:00:00Z",
  "coverage": 78.5,
  "complexity": 9,
  "module_size": 350,
  "dependency_cycles": 0
}
```

The **reader** (this skill) fetches the ref with `git fetch` — no write,
no conflict risk on PR branches. The **writer** is a GitHub Action that fires
on `push:main` and overwrites `baseline.json` with the merged-commit metrics.

A single overwritten snapshot was chosen over append-only history because:
- Fetch payload stays minimal (one small JSON file per repo)
- The v2 mutation-testing pulse can co-locate on the same ref as
  `mutation-baseline.json` without format entanglement
- Cross-repo trend aggregation (future Tech Manager dashboard) can poll
  the ref across repos without downloading a growing log

## Stack Adapters

The stack-agnostic metric contract is implemented per stack. v1 ships:

- **C#** (`stack-csharp` bundle): coverage via `dotnet-coverage` → Cobertura XML
  (falls back to the `coverlet` XPlat collector when absent — dotnet-coverage's
  binary instrumentation is far faster on large/async-heavy suites);
  complexity + module_size via `lizard`; dependency cycles via `dotnet list
  reference` + cycle detection (thinner than TS — no free `madge` equivalent
  for C# assembly graphs; project-reference cycles only in v1).
- **TypeScript** (`stack-typescript` bundle): coverage via `vitest` → LCOV;
  complexity + module_size via `lizard`; dependency cycles via `madge` (full
  import graph + cycle detection).

Stack detection is automatic via the existing `_detect_stack` mechanism.
Use `--stack` to override.

## Writer Action

Install `templates/github-actions/code-metrics-writer.yml` into
`.github/workflows/` in each repo that uses this bundle. It fires on
`push:main`, recomputes full-repo metrics on the merged commit, and writes
the orphan ref. It **never pushes to `main` or `release/*`**.

See `templates/github-actions/code-metrics-writer.yml` for the full
template and installation notes.

## Relationship to quality and knowledge-ops

- **quality** — blocking pre-merge audits and advisory signals (security, money,
  tenant, contracts, grounding, verification, style). Fine-tune members down via
  the interactive picker (uncheck → `exclude:`).
- **knowledge-ops** — knowledge-base operations (`knowledge-hygiene`/`synthesize`/`briefing`).
- **code-metrics** — deterministic measurement over time + per-PR delta.
  *Measurement axis (this bundle).*
