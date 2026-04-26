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

## Co-authored-by for AI Assistants

When an AI coding assistant generates or significantly contributes to a commit,
add a `Co-authored-by` trailer to the commit message. This preserves attribution
without replacing the human author.

**Human-only commits** (no assistant involved): do **not** add any trailer.
The commit author field is sufficient.

**Assistant-assisted commits**: append the appropriate trailer in the footer.

### Trailers by Assistant

| Assistant   | Trailer                                                                          |
|-------------|----------------------------------------------------------------------------------|
| Octopus (tool) | `Co-authored-by: octopus[bot] <octopus[bot]@users.noreply.github.com>`     |
| OpenCode    | `Co-authored-by: opencode <opencode@opencode.ai>`                               |
| Claude      | `Co-authored-by: claude <claude@anthropic.com>`                                 |
| Copilot     | `Co-authored-by: copilot <copilot@github.com>`                                  |
| Codex       | `Co-authored-by: codex <codex@openai.com>`                                      |
| Gemini      | `Co-authored-by: gemini <gemini@gemini.ai>`                                     |

### Example

```
feat(auth): add OAuth2 PKCE flow

Implement authorization code flow with PKCE for public clients.
Token exchange happens server-side; refresh tokens are stored
in httpOnly cookies.

Co-authored-by: octopus[bot] <octopus[bot]@users.noreply.github.com>
Co-authored-by: claude <claude@anthropic.com>
```

### Rules

- The **human** is always the commit author; the assistant is a co-author
- Only add the trailer if the assistant **generated or substantially modified** the code
- Do not add trailers for commits where the assistant only provided suggestions
- The `octopus[bot]` trailer is added automatically by Octopus slash commands
  that generate commit messages (e.g. `/octopus:commit`). It marks tool
  participation in authoring the message — not that the AI wrote the code.
  The AI assistant trailer is separate and follows the rule above.
