# API Contract Detection Patterns (default)

> Embedded default. Override at `docs/doc-api/patterns.md`.
> Overrides append; they do not replace the defaults.

## Endpoint & version detection

### .NET (C#)

- Controller attributes: `[HttpGet("...")]`, `[HttpPost("...")]`,
  `[HttpPut("...")]`, `[HttpDelete("...")]`, `[HttpPatch("...")]`.
- Minimal API: `app.MapGet("...")`, `app.MapPost("...")`, etc.
- Route prefix: `[Route("...")]` on the controller.
- Version: `[ApiVersion("2.0")]`, `[Route("v{version:apiVersion}/...")]`,
  `app.MapGroup("/v1")`, or a `v\d+` path segment.

### Node

- `express`/`fastify`: `app.get("...")`, `router.post("...")`,
  `app.use("/v2", router)`.
- `hono`: `app.get("...")`, `app.route("/v1", sub)`.
- `@nestjs/core`: `@Get()`, `@Post()`, `@Controller("v1/...")`,
  `@Version("2")`.

## Error & envelope detection

### .NET (C#)

- `ProblemDetails` / `ValidationProblemDetails` return types.
- `throw new ...Exception`, `Results.Problem(...)`, status via `StatusCode(...)`.
- Envelope: a wrapper record such as `ApiResponse<T>` / `Envelope<T>`.

### Node

- Error shape: `res.status(code).json({ error, message, code })`.
- Thrown `HttpException` (`@nestjs/common`) with a status.
- Envelope: a `{ data, error, metadata }` wrapper.
