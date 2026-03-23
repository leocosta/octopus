# Python Project Architecture

## Source Layout

Use the `src` layout to prevent accidental imports of the uninstalled package:

```
project-root/
  src/
    myapp/
      __init__.py
      main.py
      domain/
      services/
      adapters/
      api/
  tests/
  pyproject.toml
```

## Package Organization

Organize by feature or clean architecture layer. Pick one and stay consistent.

**By layer (small-to-medium projects):**

```
src/myapp/
  domain/          # entities, value objects, domain errors
  services/        # use cases / application logic
  adapters/        # DB repos, HTTP clients, external APIs
  api/             # routes, serializers, request handlers
```

**By feature (larger projects):**

```
src/myapp/
  orders/
    domain.py
    service.py
    repository.py
    router.py
  users/
    ...
```

## `__init__.py` Usage

- Keep `__init__.py` minimal — re-export public API only
- Never put business logic in `__init__.py`
- Use `__all__` to control `from package import *` behavior

```python
# src/myapp/domain/__init__.py
from .order import Order, OrderStatus
__all__ = ["Order", "OrderStatus"]
```

## Dependency Injection

Prefer manual constructor injection. Frameworks like `inject` or `dependency-injector` are optional.

```python
class OrderService:
    def __init__(self, repo: OrderRepository, notifier: Notifier) -> None:
        self._repo = repo
        self._notifier = notifier
```

Wire dependencies at the composition root (`main.py` or a `bootstrap` module). Keep domain free of framework imports.

## Entry Points

Define entry points in `pyproject.toml`:

```toml
[project.scripts]
myapp = "myapp.main:run"
```

Or use `__main__.py` for `python -m myapp` support.

## Key Principles

- Domain layer has zero external dependencies
- Adapters depend on domain — never the reverse
- Configuration loaded once at startup, passed explicitly
- Avoid circular imports — if they appear, restructure the dependency graph
