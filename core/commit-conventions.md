# Commit Conventions

## Commit Message Format

Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

### Type

| Type | When to use |
|------|-------------|
| `feat` | New feature or capability |
| `fix` | Bug fix |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `docs` | Documentation only |
| `test` | Adding or updating tests |
| `chore` | Build, CI, dependencies, config — no production code change |
| `style` | Formatting, whitespace — no logic change |
| `perf` | Performance improvement |
| `ci` | CI/CD pipeline changes |
| `revert` | Reverts a previous commit |

### Scope

Optional. The area of the codebase affected (e.g., `auth`, `api`, `ui`, `db`).

### Description

- Imperative mood: "add feature", not "added"/"adds"
- Lowercase, no trailing period, under 72 characters
- Focus on **why**, not **what** (the diff shows what changed)

### Body

Optional. Separate with a blank line, wrap at 72 characters; explain motivation
and contrast with previous behavior when relevant.

### Footer

- `BREAKING CHANGE: <description>` for breaking changes
- References: `Closes #123`, `Refs #456`, `Refs: RM-042`

### Example

```
fix(auth): prevent token refresh loop on 401

The refresh interceptor retried indefinitely when the refresh token
itself was expired. Now it redirects to login after one failed attempt.

Closes #234
```

## Guidelines

- **One logical change per commit** — don't mix a refactor with a feature.
- **Don't commit broken code or generated files** (build outputs, unrelated lockfile churn).

## Co-authored-by for AI Assistants

When an AI assistant **generated or substantially modified** the code, append a
`Co-authored-by` trailer in the footer — the human stays the commit author.
Human-only commits get no trailer.

- `octopus[bot]` is added automatically by Octopus slash commands that author the
  message: `Co-authored-by: octopus[bot] <octopus[bot]@users.noreply.github.com>`
- Add the assistant's own trailer too when it wrote the code, e.g.
  `Co-authored-by: claude <claude@anthropic.com>`.
