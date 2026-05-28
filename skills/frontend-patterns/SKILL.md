---
name: frontend-patterns
description: Frontend architecture decision patterns for component-based UIs (React, Next.js, Vue). Component composition, state vs. server cache, data fetching, styling conventions, and accessibility as a first-class concern. Pairs with the frontend-developer role and the test-component / test-e2e skills.
triggers:
  paths: ["**/*.tsx", "**/*.jsx", "**/*.vue", "app/**", "components/**", "src/components/**"]
  keywords: ["react", "nextjs", "vue", "tailwind", "shadcn", "component"]
  tools: []
---

# Frontend Architecture Patterns

## When to Use

- Designing a new component, page, or UI feature
- Choosing where state lives (local, lifted, server cache, global)
- Structuring a new frontend feature or module
- Reviewing frontend architecture decisions

This is the frontend counterpart to `backend-patterns`. Stack-specific
conventions (React/Next/Vue idioms, masks, Tailwind, testing) live in
`rules/typescript/*` — this skill is the decision layer above them.

## Component Design

- Functional components only — type props as `{Component}Props`.
- Composition over configuration: small, focused components combined with
  `children`, render props, or compound components. Avoid boolean-prop
  explosions (`isCompact`, `isLarge`, `hasBorder`) — they signal a missing
  composition seam.
- **Components render; hooks hold logic.** Extract data fetching, mutations,
  derived state, and side effects into `use{Feature}{Action}` hooks.
- Organize by domain feature, not technical layer
  (`features/<domain>/{components,hooks,services,types,pages}`).

## State — choose the narrowest scope

```
Server data?           → server-cache library (React Query / SWR), not useState
Used by one component? → local useState
Shared by siblings?    → lift to nearest common ancestor (not higher)
Cross-cutting + rare?   → context (theme, auth, locale)
Cross-cutting + hot?    → a store (Zustand/Redux) — only when context re-renders hurt
```

Do not mirror server data into local state — it goes stale. Read it from the
cache and derive what you need.

## Data Fetching

- Fetch in hooks, not inside JSX. Components receive data + status as props or
  hook returns.
- Always handle the four states: **loading, error, empty, success.** A UI that
  only renders the happy path is incomplete.
- Co-locate the query key with the feature; invalidate on mutation success.
- Push fetching to the route/page boundary; leaf components stay presentational.

## Styling Conventions

- One styling system per project (Tailwind + a component lib like shadcn/ui is
  the assumed default — follow `rules/typescript/tooling.md`).
- Compose class names through the project `cn()` helper; never concatenate
  conditional class strings by hand.
- No magic pixel values scattered inline — use the design-system scale (spacing,
  color, radius tokens).
- Styling is not behaviour: don't assert on CSS classes in tests.

## Accessibility (first-class, not a polish pass)

- Use semantic elements (`<button>`, `<nav>`, `<label>`) before reaching for
  ARIA. ARIA supplements semantics; it does not replace them.
- Every interactive element is keyboard-reachable and has an accessible name.
- Form inputs are associated with a `<label>`; errors are announced, not only
  coloured red.
- Building components so they're queryable by role/label (see
  `rules/typescript/testing.md`) makes them both accessible **and** testable —
  the same property serves both. `test-component` relies on it.
- For masked/formatted fields (CPF, CNPJ, phone, currency) follow
  `rules/typescript/ui-conventions.md` — always the designated mask component.

## Decision Trees

### Client component vs. server component (Next.js App Router)
```
Needs interactivity / browser APIs / hooks? → client component ("use client")
Pure data display, no interactivity?         → server component (default)
Mostly static with one interactive island?   → server shell + small client leaf
```
Default to server; push `"use client"` down to the smallest leaf that needs it.

### New global store?
```
Is it server data?            → no store — use the server cache
Is it one screen's state?     → no store — local/lifted state
Re-renders measurably hurting? → store, scoped to the slice that changes
Otherwise                      → context is enough
```

## Anti-Patterns

- **Prop-drilling** through 3+ layers — lift to context or restructure.
- **Mirroring server state** into `useState` — it desyncs from the cache.
- **Fat components** that fetch, transform, and render — split logic into hooks.
- **Happy-path-only UI** — missing loading / error / empty states.
- **`div` soup** — non-semantic clickable `<div>`s with `onClick` and no role,
  no keyboard handler.
- **Premature global store** for state one component owns.
- **Testid-driven markup** — reaching for `data-testid` because the component
  isn't queryable by role signals an accessibility gap, not a testing need.

## Integration with Other Skills

- **`test-component`** — verifies these components by behaviour (RTL).
- **`test-e2e`** — covers the assembled flows across pages.
- **`frontend-developer` role** — the persona that implements UI using these
  patterns via `/octopus:delegate`.
- **`review-contracts`** — catches drift between the API and the frontend's
  expected DTOs/endpoints (central to the `fullstack` bundle).
- Stack rules: `rules/typescript/react-patterns.md`,
  `rules/typescript/ui-conventions.md`, `rules/typescript/tooling.md`.
