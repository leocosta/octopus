# Project Configuration

## Core Standards
{{CORE}}

## Language Rules
{{RULES}}

## Skills
{{SKILLS}}

## Roadmap & Backlog

- When starting any non-trivial feature, check `docs/roadmap.md` for an open item (RM-NNN)
- To conduct a structured brainstorming session and capture improvement ideas: `/octopus:doc-research`
- Research sessions are saved in `docs/research/`; the consolidated backlog lives in `docs/roadmap.md`

## Claude-Specific Behavior

### After Every Correction

When you fix a mistake or learn something new about how this project should work,
end your response with: "Update your CLAUDE.md so you don't make that mistake again."
Then update the CLAUDE.md immediately. This is how the team's guidelines improve over time.

### Plan Before Complex Tasks

For any non-trivial task (new feature, refactor, architectural change), enter plan mode
first. Present the plan and wait for approval before writing code.

Trigger plan mode explicitly when:
- The task touches more than 2 files
- You're unsure about the approach
- The user says "think about this" or "what's the best way to..."

### Code Quality After Changes

After completing code changes, append `/simplify` to review the modified code for
reuse, quality, and efficiency before declaring the task done.

---

<!-- Add project-specific Claude instructions below this line -->
<!-- Examples: preferred libraries, confirmation rules, response language -->
