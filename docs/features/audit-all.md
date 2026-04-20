# Audit-All

Run all four quality-audit skills in parallel against a single ref,
with shared file discovery and a consolidated severity report.
Composer for `security-scan`, `money-review`, `tenant-scope-audit`,
and `cross-stack-contract`.

## When to use

Before merging any non-trivial PR on a multi-tenant SaaS codebase
with billing. Replaces the sequential invocation of four audits.

## Enable

Add `audit-all` to `.octopus.yml`:

```yaml
skills:
  - audit-all
```

That's enough. The skill's `depends_on:` frontmatter pulls the four
audits automatically at setup time. The `quality-gates` bundle lists
only `audit-all` for the same reason.

## Use

```
# default — since last tag, every installed audit
/octopus:audit-all

# specific version
/octopus:audit-all v1.7.0

# a PR number
/octopus:audit-all #123

# narrow to two audits
/octopus:audit-all --only=money,tenant

# persist the consolidated report
/octopus:audit-all --write-report
```

## Output

A single markdown block:

- Summary header with totals (block / warn / info) and audit names
- Cross-audit hotspots table — files flagged by ≥ 2 audits
- Four sub-reports, each preserving its own format and confidence
  labels
- Closing footer per sub-report so reviewers can paste one
  audit's section into a PR thread

With `--write-report`, the same content lands at
`docs/reviews/YYYY-MM-DD-audit-all-<slug>.md` with frontmatter.

## Individual audits remain first-class

The four audits stay independently invocable:

```
/octopus:security-scan
/octopus:money-review
/octopus:tenant-scope-audit
/octopus:cross-stack-contract
```

Use `audit-all` for a full pre-merge sweep; use an individual audit
for a focused run on a PR that only touches one area.

## Review before merge

`audit-all` is guidance — v1 always exits 0. Treat every 🚫 Block
as a merge blocker unless reviewers accept it with a comment; ⚠
Warns are defense-in-depth.
