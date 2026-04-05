# Troubleshooting

## Installation issues

**`octopus setup` fails: `cli/octopus.sh: No such file or directory`**
Run `octopus doctor` to check the installation state. If the cache is corrupted, reinstall:
```bash
curl -fsSL https://github.com/leocosta/octopus/releases/latest/download/install.sh | bash -s -- --force
```

**`curl: (22)` or HTTP 404 when installing**
Ensure you're using the official release URL:
```bash
curl -fsSL https://github.com/leocosta/octopus/releases/latest/download/install.sh | bash
```

**`octopus: command not found` after installation**
Add `~/.local/bin` to your PATH:
```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc  # or ~/.zshrc
source ~/.bashrc
```

## Setup issues

**`syntax error` or associative arrays not working**
Ensure you're running Bash 4+. macOS ships with Bash 3 — install a newer version:
```bash
brew install bash
bash ./octopus/setup.sh   # use explicit bash
```

**`command not found: python3`**
Python 3 is required for JSON merging (MCP injection and hooks):
```bash
brew install python3      # macOS
sudo apt install python3  # Linux
```

**`gh: command not found` when `workflow: true`**
Install GitHub CLI from https://cli.github.com, then authenticate:
```bash
gh auth login
```

**Symlinks not created (rules/skills missing from `.claude/`)**
Always run `setup.sh` from your repo root, not from inside the `octopus/` directory:
```bash
# Correct
./octopus/setup.sh

# Wrong — will fail to locate PROJECT_ROOT
cd octopus && ./setup.sh
```

**MCP environment variables not substituted**
Ensure `.env.octopus` exists in your repo root with the required variables before running `setup.sh`. Copy from the generated template:
```bash
cp .env.octopus.example .env.octopus
```

**Hooks not injected into `.claude/settings.json`**
Requires Python 3 for JSON merging. Also verify `hooks: true` is set in `.octopus.yml`:
```bash
python3 --version
```
