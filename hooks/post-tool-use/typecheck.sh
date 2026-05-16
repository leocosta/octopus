#!/usr/bin/env bash
# Run type checking after editing typed files

set -euo pipefail

input=$(cat)
file_path=$(echo "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path','') or d.get('file_path',''))" 2>/dev/null || echo "")

[[ -z "$file_path" || ! -f "$file_path" ]] && exit 0

ext="${file_path##*.}"

case "$ext" in
  ts|tsx)
    if command -v tsc &>/dev/null; then
      tsc --noEmit --pretty 2>&1 | head -20 || true
    elif command -v npx &>/dev/null; then
      npx --yes tsc --noEmit --pretty 2>&1 | head -20 || true
    fi
    ;;
  py|pyi)
    if command -v mypy &>/dev/null; then
      mypy "$file_path" --no-error-summary 2>&1 | head -10 || true
    elif command -v pyright &>/dev/null; then
      pyright "$file_path" 2>&1 | head -10 || true
    fi
    ;;
  cs)
    if command -v dotnet &>/dev/null; then
      proj_dir=$(dirname "$file_path")
      while [[ "$proj_dir" != "/" ]]; do
        if compgen -G "$proj_dir"/*.sln &>/dev/null || compgen -G "$proj_dir"/*.csproj &>/dev/null; then
          break
        fi
        proj_dir=$(dirname "$proj_dir")
      done
      [[ "$proj_dir" == "/" ]] && proj_dir=$(dirname "$file_path")
      (cd "$proj_dir" && dotnet build --no-restore 2>&1 | tail -5) || true
    fi
    ;;
esac

exit 0
