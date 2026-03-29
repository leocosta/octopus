# Architecture

> **Note:** Each consumer repository should customize this file to reflect its own system.
> The sections below serve as a guide for what to document.

## System Overview

Describe the main components/services of your system, their responsibilities, and how they interact. Include a high-level diagram if helpful.

## Design Decisions

Document key architectural decisions using this format:

### Decision: [Title]

- **Context:** What problem or need prompted this decision
- **Decision:** What was decided
- **Rationale:** Why this option was chosen over alternatives
- **Consequences:** Known trade-offs and implications

## Cross-Cutting Concerns

- All services must have health check endpoints
- Environment-specific configuration via environment variables — never hardcode
- Secrets managed through `.env.octopus` files locally and secret managers in production
- Infrastructure changes must be documented or automated
