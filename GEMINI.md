# Octopus Framework Guidelines

## Octopus Agents (Roles)
- **Definition:** In the context of this project, "Octopus Agents" are defined by the Markdown files located in the `roles/` directory.
- **Usage:** When asked about Octopus agents or roles, refer to the files in `roles/` (e.g., `roles/backend-specialist.md`, `roles/frontend-specialist.md`, etc.).
- **Structure:** Each agent file contains its identity, responsibilities, and specific workflows (Phases 0-4).

## Directory Structure Reference
- `roles/`: Contains the core agent/role definitions.
- `agents/`: Contains provider-specific configurations (antigravity, claude, codex, etc.) which may implement or use these roles.
- `commands/`: Contains specialized command definitions for the agents.
- `rules/`: Language and domain-specific rules followed by the agents.
