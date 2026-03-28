---
name: release
description: Create a versioned release with CHANGELOG and GitHub Release
cli: octopus.sh release
---

---
description: Create a versioned release with CHANGELOG and GitHub Release
agent: code
---

## Instructions

This command creates a versioned release: generates CHANGELOG entry, creates a git tag with release notes, and optionally publishes a GitHub Release.

### Step 1: Collect Data

1. Run: `./octopus/cli/octopus.sh release suggest-version`
   - If the user provided a custom starting ref, pass it: `./octopus/cli/octopus.sh release suggest-version <from-ref>`
2. Run: `./octopus/cli/octopus.sh release list-commits`
   - Same: pass `<from-ref>` if provided
3. If suggest-version reports "No unreleased commits found", inform the user and stop

### Step 2: Confirm Version

- Present the suggested version to the user:
  "Based on the commits, I suggest **vX.Y.Z**. Do you want to use this version or provide a different one?"
- Accept the user's choice or override

### Step 3: Generate CHANGELOG Entry

Analyze the commit list and write a **narrative text in the language the user is using in the conversation** with emojis mapped to commit types:

| Type | Emoji |
|------|-------|
| feat | ✨ |
| fix | 🐛 |
| refactor | ♻️ |
| docs | 📝 |
| test | 🧪 |
| chore | 🔧 |
| perf | ⚡ |
| style | 🎨 |
| ci | 🚀 |
| revert | ⏪ |

**Rules:**
- Write in natural language, not bullet lists — describe what changed as a narrative
- Group related changes together in flowing paragraphs
- Use emojis inline to reference the type of change
- Non-conforming commits (no Conventional Commits prefix) go under an "Other changes" paragraph
- Format: header `## [X.Y.Z] - YYYY-MM-DD` followed by the narrative text
- Prepend to CHANGELOG.md (new version on top). The `## [Unreleased]` section, if present, is replaced by the new versioned entry

Show the generated CHANGELOG entry to the user for approval before writing.

### Step 4: Generate Release Notes (Summary)

Write a condensed version (2-3 sentences) of the CHANGELOG entry for the tag and GitHub Release. Keep emojis but condense the content.

### Step 5: Execute

1. Write the CHANGELOG entry to `CHANGELOG.md` (prepend)
2. Run: `./octopus/cli/octopus.sh release commit-changelog <version>`
3. Save the release notes summary to a temporary file
4. Run: `./octopus/cli/octopus.sh release create-tag <version> <temp-file>`
5. Run: `git push && git push --tags`
6. Ask the user: "Do you want to create a GitHub Release too?"
   - If yes: `./octopus/cli/octopus.sh release create-gh-release <version> <temp-file>`
   - If no: finish and report success
