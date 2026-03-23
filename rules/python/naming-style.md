# Python Naming Conventions

## General Rules

- `snake_case` for functions, variables, methods, modules, and packages
- `PascalCase` for classes and type aliases
- `UPPER_SNAKE_CASE` for module-level constants
- `_single_prefix` for internal/private names
- `__double_prefix` triggers name mangling — use sparingly
- `__dunder__` reserved for Python special methods (`__init__`, `__repr__`, etc.)

## Functions and Variables

```python
def calculate_total_price(items: list[Item]) -> Decimal:
    base_price = sum(item.price for item in items)
    return base_price

is_active = True
user_count = 0
```

Booleans: prefix with `is_`, `has_`, `can_`, `should_`.

## Classes

```python
class OrderProcessor:
    """Processes incoming orders."""

class HTTPClient:
    """Acronyms stay uppercase in PascalCase."""
```

## Constants

```python
MAX_RETRY_COUNT = 3
DEFAULT_TIMEOUT_SECONDS = 30
BASE_API_URL = "https://api.example.com"
```

Define constants at module level. Never mutate them.

## Private and Internal

```python
class Service:
    def __init__(self) -> None:
        self._connection_pool = []   # internal — not part of public API
        self.__secret = "x"          # name-mangled — rarely needed

def _build_query(params: dict) -> str:
    """Module-internal helper. Not exported."""
```

## Files and Packages

- Module files: `snake_case.py` (e.g., `order_service.py`)
- Packages: short `snake_case` directories with `__init__.py`
- Test files: `test_<module>.py`
- Avoid hyphens in file names — they break imports

## What to Avoid

- Single-letter names outside comprehensions and loop counters
- Abbreviations that obscure intent (`calc_ttl_prc` vs `calculate_total_price`)
- Prefixing classes with `C` or interfaces with `I` — not Pythonic
- `l`, `O`, `I` as standalone names — visually ambiguous
