# Python Tooling

## pyproject.toml as Single Config

Consolidate all tool configuration in `pyproject.toml`. No `setup.cfg`, `tox.ini`, or scattered config files.

```toml
[project]
name = "myapp"
version = "1.0.0"
requires-python = ">=3.11"
dependencies = ["httpx", "pydantic>=2"]

[project.optional-dependencies]
dev = ["pytest", "pytest-cov", "ruff", "mypy"]
```

## Ruff (Linting + Formatting)

Ruff replaces flake8, isort, black, and most other linters. Single tool, fast.

```toml
[tool.ruff]
target-version = "py311"
line-length = 88

[tool.ruff.lint]
select = ["E", "F", "I", "N", "UP", "B", "SIM", "RUF"]

[tool.ruff.lint.isort]
known-first-party = ["myapp"]
```

```bash
ruff check .          # lint
ruff check --fix .    # lint + auto-fix
ruff format .         # format (black-compatible)
```

## Type Checking

Use **mypy** or **pyright**. Configure strict mode:

```toml
[tool.mypy]
strict = true
warn_return_any = true
disallow_untyped_defs = true
```

Run: `mypy src/`

## Virtual Environments

Always isolate project dependencies.

```bash
# venv (built-in)
python -m venv .venv
source .venv/bin/activate

# uv (fast alternative)
uv venv
source .venv/bin/activate
```

## Dependency Management

| Tool   | Install deps         | Lock file          |
|--------|---------------------|--------------------|
| pip    | `pip install -e .[dev]` | `pip freeze > requirements.txt` |
| uv     | `uv pip install -e .[dev]` | `uv pip compile pyproject.toml` |
| poetry | `poetry install`    | `poetry.lock`      |

Prefer **uv** for speed. Lock files go in version control.

## Pre-commit Hooks

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.8.0
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format
  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v1.13.0
    hooks:
      - id: mypy
        additional_dependencies: [types-requests]
```

```bash
pre-commit install
pre-commit run --all-files
```

## Key Principles

- One formatter, one linter, one type checker — no overlapping tools
- All config in `pyproject.toml` unless the tool requires its own file
- CI runs the same checks as pre-commit — no surprises on merge
