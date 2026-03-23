# Python Testing with pytest

## Naming Pattern

```
test_{scenario}_{expected_result}
```

```python
def test_create_order_returns_order_with_pending_status():
    ...

def test_create_order_raises_when_items_empty():
    ...
```

## AAA Pattern

Every test follows Arrange-Act-Assert:

```python
def test_apply_discount_reduces_total():
    # Arrange
    order = Order(items=[Item(price=100)])

    # Act
    order.apply_discount(percent=10)

    # Assert
    assert order.total == 90
```

## Fixtures

Use `conftest.py` for shared fixtures. Keep fixtures close to where they are used.

```python
# tests/conftest.py
@pytest.fixture
def db_session():
    session = create_test_session()
    yield session
    session.rollback()

@pytest.fixture
def sample_user(db_session):
    user = User(name="Alice")
    db_session.add(user)
    db_session.flush()
    return user
```

## Parametrize

Use `@pytest.mark.parametrize` for data-driven tests:

```python
@pytest.mark.parametrize("input_val,expected", [
    ("", False),
    ("valid@email.com", True),
    ("no-at-sign", False),
])
def test_validate_email(input_val, expected):
    assert validate_email(input_val) == expected
```

## Markers

Separate fast unit tests from slow integration tests:

```python
# pyproject.toml
[tool.pytest.ini_options]
markers = ["unit", "integration"]

# usage
@pytest.mark.unit
def test_calculate_tax(): ...

@pytest.mark.integration
def test_persist_order_to_db(): ...
```

Run selectively: `pytest -m unit`

## Integration Tests with Testcontainers

```python
from testcontainers.postgres import PostgresContainer

@pytest.fixture(scope="session")
def pg_container():
    with PostgresContainer("postgres:16") as pg:
        yield pg

@pytest.fixture
def db_url(pg_container):
    return pg_container.get_connection_url()
```

## Coverage

```bash
pytest --cov=src --cov-report=term-missing --cov-fail-under=80
```

Configure in `pyproject.toml`:

```toml
[tool.coverage.run]
source = ["src"]
omit = ["*/tests/*"]
```
