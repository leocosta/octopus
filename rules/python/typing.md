# Python Type Hints

## Core Rules

- Type all function signatures (parameters and return)
- Use built-in generics: `list[str]`, `dict[str, int]`, `tuple[int, ...]`
- Use `|` union syntax (3.10+): `str | None` instead of `Optional[str]`
- Avoid `Any` — it disables type checking. Use `object` or a Protocol instead

## Function Signatures

```python
def fetch_users(active_only: bool = True) -> list[User]:
    ...

def find_by_id(user_id: int) -> User | None:
    ...

async def process(payload: bytes) -> dict[str, str]:
    ...
```

## Dataclasses for Immutability

Prefer `frozen=True` for value objects and DTOs:

```python
from dataclasses import dataclass

@dataclass(frozen=True, slots=True)
class Money:
    amount: Decimal
    currency: str
```

## Protocol for Structural Typing

Define interfaces without forcing inheritance:

```python
from typing import Protocol

class Repository(Protocol):
    def get(self, id: int) -> Entity | None: ...
    def save(self, entity: Entity) -> None: ...
```

Any class with matching methods satisfies the Protocol — no registration needed.

## TypedDict for Structured Dicts

When you must work with dicts (API responses, config):

```python
from typing import TypedDict

class UserPayload(TypedDict):
    name: str
    email: str
    age: int | None
```

## Generics

```python
from typing import TypeVar

T = TypeVar("T")

def first(items: list[T]) -> T | None:
    return items[0] if items else None
```

For decorators and higher-order functions:

```python
from typing import ParamSpec, TypeVar
from collections.abc import Callable

P = ParamSpec("P")
R = TypeVar("R")

def retry(fn: Callable[P, R]) -> Callable[P, R]:
    ...
```

## Collections

Import abstract types from `collections.abc`:

```python
from collections.abc import Sequence, Mapping, Iterable

def process(items: Sequence[str]) -> Mapping[str, int]:
    ...
```

Use abstract types in function parameters, concrete types in return values.

## What to Avoid

- `Any` as a shortcut — narrow the type instead
- `# type: ignore` without a specific error code
- Inline `Union[X, Y]` — use `X | Y`
- Mutable default arguments in typed signatures — use `None` + internal creation
