# Pull Request Workflow

## PR Creation

- Create a branch from the current base branch (`main` by default, or the target `release/*` branch if your team uses release branches) following the [branch naming convention](commit-conventions.md)
- Keep PRs focused — one feature, fix, or refactor per PR
- Small PRs are easier to review and less risky to merge; aim for under 400 lines changed
- If a change is large, break it into stacked PRs with clear dependency order

### Title & Description

- PR title follows Conventional Commits format: `type(scope): description`
- Description must include:
  - **What** — summary of the change (1-3 bullet points)
  - **Why** — motivation, link to issue/ticket
  - **How to test** — steps or commands to verify the change
  - **Screenshots** — for UI changes, include before/after

### Template

```markdown
## Summary
- <what changed and why>

## Related Issues
Closes #<issue>

## How to Test
1. <step>
2. <step>

## Screenshots (if applicable)
```

## Review Process

### For Authors

- Self-review your diff before requesting reviews — catch obvious issues yourself
- Ensure CI passes (tests, lint, build) before requesting review
- Respond to all review comments — resolve or explain why you disagree
- Don't push unrelated changes while a PR is in review
- Rebase on `main` if the branch is outdated, don't merge main into your branch

### For Reviewers

- Review within **one business day** of being assigned
- Focus on:
  - **Correctness** — does the code do what it claims?
  - **Design** — does it fit the existing architecture?
  - **Readability** — can someone unfamiliar with this code understand it?
  - **Edge cases** — missing error handling, race conditions, null checks
  - **Security** — injection, auth bypass, data exposure
  - **Tests** — are the right things being tested?
- Be specific and actionable in feedback — suggest code when possible
- Distinguish between blocking issues and suggestions (prefix with `nit:` for non-blocking)
- Approve when all blocking issues are resolved — don't block on style preferences

### Approval Requirements

- Minimum **1 approval** required before merge
- Author cannot approve their own PR
- Re-request review after significant changes

## Merge Strategy

- Use **squash merge** to the target branch — keeps history clean with one commit per PR
- The squash commit message should follow Conventional Commits format
- Delete the branch after merge
- Never merge with failing CI checks
- Never force-push to `main`

## Hotfix Process

- For critical production issues, create a branch from `main` with prefix `fix/`
- Follow the same review process but with expedited review (tag reviewers directly)
- After merge, verify the fix in production

## Release Branches (Optional)

Teams that use release branches follow a GitFlow-like model:

- Create `release/*` branches from `main` for each release cycle
- Feature branches target the active release branch instead of `main` directly
- When the release is ready, merge `release/*` into `main` with a merge commit
- Tag the merge commit with the version number
