# Roles

Agent personas that combine a responsibility definition with your project context. Each role generates a specialized agent.

**Available roles:** `product-manager`, `backend-specialist`, `frontend-specialist`, `tech-writer`, `social-media`

## How it works

1. Add roles to `.octopus.yml`:
   ```yaml
   roles:
     - product-manager
     - backend-specialist
   ```
2. Optionally configure knowledge modules (see [Knowledge](knowledge.md)) — their content is injected as project context into each role
3. Run `octopus setup`
4. **Claude Code**: each role becomes a native agent file in `.claude/agents/<role>.md` with YAML frontmatter (name, model, color)
5. **Other agents**: roles are appended as sections to the agent's output file

The role template contains a `{{PROJECT_CONTEXT}}` placeholder that gets replaced with assembled knowledge module content. The `_base.md` file provides shared guidelines appended to all roles.

## Adding custom roles

1. Create `octopus/roles/<name>.md` with YAML frontmatter and `{{PROJECT_CONTEXT}}` placeholder
2. Add `- <name>` to the `roles:` list in `.octopus.yml`

## Built-in roles

### `tech-writer`

Documentation lifecycle agent. Use when you need documentation-only execution with stronger editorial rigor: pre-implementation RFC/spec drafting, post-implementation ADR/spec deviation reconciliation, knowledge capture, changelog updates, and documentation audits grounded in code and evidence.

See [Feature Lifecycle](feature-lifecycle.md) for the full guide on using `tech-writer`.

### `social-media`

Use when you need a specialist for campaign copy, launch posts, threads, captions, carousel outlines, and reel/story scripts for X and Instagram. The role treats destination platform as optional: it can generate for X, Instagram, both, or produce variants when the brief does not name a final channel.

For direct X publishing, use `scripts/x_post.py`. It reads credentials from `.env.octopus`, supports credential verification, previews before publishing, and requires an explicit `--publish` flag for live posting.
