# cli/lib/uninstall.sh — Remove Octopus artifacts from the current repository.
#
# Sourced by cli/octopus.sh after CLI_DIR is set.
# PWD is the project root (set by bin/octopus via run_subcommand).

# shellcheck source=./ui.sh
source "$CLI_DIR/lib/ui.sh"

# ── Helpers ──────────────────────────────────────────────────────────────────

_ask_confirm() {
  local prompt="$1"
  if [[ ! -t 0 ]]; then return 1; fi
  local reply
  read -r -p "$prompt [y/N] " reply
  [[ "${reply,,}" == "y" || "${reply,,}" == "yes" ]]
}

_remove_if_exists() {
  local path="$1"
  if [[ -e "$path" || -L "$path" ]]; then
    rm -rf "$path"
    ui_detail "  removed: $path"
    return 0
  fi
}

_remove_glob() {
  local pattern="$1"
  local found=0
  for f in $pattern; do
    [[ -e "$f" || -L "$f" ]] || continue
    rm -f "$f"
    ui_detail "  removed: $f"
    found=1
  done
  return 0
}

# Parse roles from .octopus.yml (simple grep — no full YAML parser needed)
_parse_roles() {
  local manifest="$1"
  local in_roles=0
  while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]*roles:[[:space:]]*$ ]]; then
      in_roles=1; continue
    fi
    if (( in_roles )); then
      if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*([a-z_-]+) ]]; then
        echo "${BASH_REMATCH[1]}"
      elif [[ "$line" =~ ^[^[:space:]-] ]]; then
        in_roles=0
      fi
    fi
  done < "$manifest"
}

# ── Main ─────────────────────────────────────────────────────────────────────

PROJECT_ROOT="$PWD"
MANIFEST_PATH="$PROJECT_ROOT/.octopus.yml"

# Parse --scope flag
UNINSTALL_SCOPE="repo"
for _arg in "$@"; do
  case "$_arg" in
    --scope=*) UNINSTALL_SCOPE="${_arg#--scope=}" ;;
  esac
done

if [[ "$UNINSTALL_SCOPE" == "user" ]]; then
  USER_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/octopus"
  MANIFEST_PATH="$USER_CONFIG_DIR/.octopus.yml"
  INSTALL_ROOT="$HOME"
else
  INSTALL_ROOT="$PROJECT_ROOT"
fi

# Derive known artifact paths
RULES_DIR="$INSTALL_ROOT/.claude/rules"
SKILLS_DIR="$INSTALL_ROOT/.claude/skills"
AGENTS_DIR="$INSTALL_ROOT/.claude/agents"
COMMANDS_DIR="$INSTALL_ROOT/.claude/commands"
SETTINGS_FILE="$INSTALL_ROOT/.claude/settings.json"
GITIGNORE="$INSTALL_ROOT/.gitignore"
ENV_FILE="$INSTALL_ROOT/.env.octopus"
GITHUB_ACTION="$INSTALL_ROOT/.github/workflows/claude.yml"

# Parse roles from manifest (if it exists)
ROLES=()
if [[ -f "$MANIFEST_PATH" ]]; then
  while IFS= read -r role; do
    ROLES+=("$role")
  done < <(_parse_roles "$MANIFEST_PATH")
fi

# Check dream and github action flags
DREAM_ENABLED=false
GITHUB_ACTION_ENABLED=false
if [[ -f "$MANIFEST_PATH" ]]; then
  grep -q "dream:[[:space:]]*true" "$MANIFEST_PATH" && DREAM_ENABLED=true
  grep -q "githubAction:[[:space:]]*true" "$MANIFEST_PATH" && GITHUB_ACTION_ENABLED=true
fi

# ── Preview ───────────────────────────────────────────────────────────────────

echo ""
ui_warn "Octopus uninstall — the following will be removed:"
echo ""

# Always-removed artifacts
[[ -d "$RULES_DIR"  || -L "$RULES_DIR"  ]] && echo "  Symlink : $RULES_DIR"
[[ -d "$SKILLS_DIR" || -L "$SKILLS_DIR" ]] && echo "  Symlink : $SKILLS_DIR"

if [[ "$DREAM_ENABLED" == "true" && -f "$AGENTS_DIR/dream.md" ]]; then
  echo "  Agent   : $AGENTS_DIR/dream.md"
fi

for role in "${ROLES[@]}"; do
  [[ -f "$AGENTS_DIR/${role}.md" ]] && echo "  Agent   : $AGENTS_DIR/${role}.md"
done

for cmd in "$COMMANDS_DIR"/octopus:*.md; do
  [[ -f "$cmd" ]] && echo "  Command : $cmd"
done

[[ -f "$SETTINGS_FILE" ]] && echo "  Settings: hooks + permissions keys in $SETTINGS_FILE"

if grep -q "# octopus (auto-generated)" "$GITIGNORE" 2>/dev/null; then
  echo "  Gitignore: octopus-managed entries in $GITIGNORE"
fi

echo ""

# ── Confirmation ─────────────────────────────────────────────────────────────

if ! _ask_confirm "Proceed?"; then
  ui_info "Aborted — nothing was changed."
  exit 0
fi

echo ""
ui_info "Removing Octopus artifacts..."

# ── Remove symlinks and agent files ──────────────────────────────────────────

_remove_if_exists "$RULES_DIR"
_remove_if_exists "$SKILLS_DIR"

if [[ "$DREAM_ENABLED" == "true" ]]; then
  _remove_if_exists "$AGENTS_DIR/dream.md"
fi

for role in "${ROLES[@]}"; do
  _remove_if_exists "$AGENTS_DIR/${role}.md"
done

_remove_glob "$COMMANDS_DIR/octopus:*.md"

# ── Clean settings.json ──────────────────────────────────────────────────────

if [[ -f "$SETTINGS_FILE" ]]; then
  python3 - "$SETTINGS_FILE" << 'PYEOF'
import json, sys

path = sys.argv[1]
with open(path) as f:
    settings = json.load(f)

removed = []
for key in ("hooks", "permissions"):
    if key in settings:
        del settings[key]
        removed.append(key)

with open(path, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")

if removed:
    print(f"  cleaned settings.json: removed {', '.join(removed)}")
PYEOF
fi

# ── Clean .gitignore ─────────────────────────────────────────────────────────

if [[ -f "$GITIGNORE" ]] && grep -q "# octopus (auto-generated)" "$GITIGNORE" 2>/dev/null; then
  python3 - "$GITIGNORE" << 'PYEOF'
import sys

path = sys.argv[1]
with open(path) as f:
    lines = f.readlines()

out = []
skip = False
for line in lines:
    stripped = line.rstrip()
    if stripped == "# octopus (auto-generated)":
        # Drop the preceding blank line if present
        if out and out[-1].strip() == "":
            out.pop()
        skip = True
        continue
    if skip and stripped == "":
        skip = False
        continue
    if not skip:
        out.append(line)

with open(path, "w") as f:
    f.writelines(out)

print("  cleaned .gitignore: removed octopus-managed entries")
PYEOF
fi

# ── Optional artifacts ────────────────────────────────────────────────────────

echo ""
ui_info "Optional artifacts (each requires confirmation):"

if [[ -f "$ENV_FILE" ]]; then
  if _ask_confirm "  Remove $ENV_FILE (may contain secrets)?"; then
    rm -f "$ENV_FILE"
    ui_detail "  removed: $ENV_FILE"
  fi
fi

if [[ -f "$GITHUB_ACTION" ]]; then
  if _ask_confirm "  Remove $GITHUB_ACTION?"; then
    _remove_if_exists "$GITHUB_ACTION"
  fi
fi

if [[ -f "$MANIFEST_PATH" ]]; then
  if _ask_confirm "  Remove manifest $MANIFEST_PATH?"; then
    rm -f "$MANIFEST_PATH"
    ui_detail "  removed: $MANIFEST_PATH"
  fi
fi

echo ""
ui_success "Octopus uninstalled. Run 'octopus setup' to reinstall."
