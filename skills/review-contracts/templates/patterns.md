# Cross-Stack Contract Patterns (default)

> Embedded default. Override at `docs/cross-stack-contract/patterns.md`.
> Overrides append; they do not replace the defaults.

## API endpoint detection

### .NET (C#)

- Controller attributes: `[HttpGet("...")]`, `[HttpPost("...")]`,
  `[HttpPut("...")]`, `[HttpDelete("...")]`, `[HttpPatch("...")]`.
- Minimal API: `app.MapGet("...")`, `app.MapPost("...")`, etc.
- Route prefix: `[Route("...")]` on the controller, combined with the
  method attribute.

### Node / TypeScript

- Express: `app.get('/...', ...)`, `router.post('/...', ...)`.
- Fastify: `fastify.route({ method, url })`.
- Hono: `app.get('/...', ...)`.
- NestJS: `@Get('...')`, `@Post('...')` decorators.
- Astro: files under `src/pages/api/` map to `/api/<path>`.

## DTO / record detection

### .NET

- `public record XxxDto(...)`, `public class XxxDto { ... }`,
  `public class XxxRequest`, `public class XxxResponse`.
- Fields annotated with `[JsonPropertyName("...")]` influence wire
  names; the skill uses the wire name when present.

### Node / TypeScript

- Zod schemas: `z.object({ ... })` near a route handler.
- Exported `interface Xxx`, `type Xxx = { ... }` in a
  `types/` or `schemas/` folder.

## Frontend consumer detection

- Fetch / axios / ky: calls with a URL literal or template string
  matching the endpoint path.
- Generated SDK methods matching camelCase of the endpoint path.
- React Query / SWR hooks: `useXxx({ ... })` whose body references the
  endpoint path.

## Enum detection

### .NET

- `public enum Xxx { A, B, C }` used by a DTO or controller return.

### TypeScript

- `type Xxx = 'a' | 'b' | 'c'`, `const Xxx = { A: 'a', ... } as const`,
  or `enum Xxx`.

## Auth attribute detection

- .NET: `[Authorize]`, `[Authorize(Roles = "...")]`, `[AllowAnonymous]`
  on controller or method.
- NestJS: `@UseGuards(...)`.
- Express middleware: a route-level middleware named like
  `authenticate`, `requireAuth`, `isAuthenticated`.
