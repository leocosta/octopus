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
| `style` | Formatting, whitespace, semicolons — no logic change |
| `perf` | Performance improvement |
| `ci` | CI/CD pipeline changes |
| `revert` | Reverts a previous commit |

### Scope

Optional. Identifies the area of the codebase affected (e.g., `auth`, `api`, `ui`, `db`).

### Description

- Use imperative mood: "add feature" not "added feature" or "adds feature"
- Lowercase, no period at the end
- Keep under 72 characters
- Focus on **why**, not **what** (the diff shows what changed)

### Body

- Separate from description with a blank line
- Wrap at 72 characters
- Explain motivation and contrast with previous behavior when relevant

### Footer

- `BREAKING CHANGE: <description>` for breaking changes
- Reference issues: `Closes #123`, `Refs #456`

### Examples

```
feat(students): add enrollment status filter

Allow filtering students by active, inactive, and suspended status
on the listing page.

Closes #234
```

```
fix(auth): prevent token refresh loop on 401

The refresh interceptor was retrying indefinitely when the refresh
token itself was expired. Now it redirects to login after one failed
refresh attempt.
```

```
chore: update dependencies to latest patch versions
```

## Branch Naming

Use the pattern: `<type>/<short-description>`

```
feat/student-enrollment
fix/token-refresh-loop
chore/update-dependencies
refactor/split-user-module
docs/api-authentication
```

- Use lowercase and hyphens (no underscores or camelCase)
- Keep it short but descriptive
- Include a ticket reference when applicable: `feat/PROJ-123-student-enrollment`

## Guidelines

- **One logical change per commit** — don't mix a refactor with a feature
- **Don't commit broken code** — each commit should leave the build passing
- **Don't commit generated files** — build outputs, lock files changes without dependency changes, etc.
- **Squash fixup commits** before merging to main — keep history clean
- **Never force-push to shared branches** (main, develop, release/*)
