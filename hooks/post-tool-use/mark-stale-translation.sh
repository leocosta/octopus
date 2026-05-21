#!/usr/bin/env bash
# Mark the pt-BR counterpart of an edited English doc as stale.
#
# Fires on PostToolUse Write|Edit. If the touched file lives under
# docs/site/ (and not under docs/site/pt-br/), compute its SHA-256 and
# write needs_retranslation: true + source_hash into the pt-BR pair's
# frontmatter. Append the pt-BR path to ~/.octopus/translation-queue.txt
# for batch processing.
#
# Never blocks: any failure logs to stderr and exits 0.

set -uo pipefail

input=$(cat)

file_path=$(printf '%s' "$input" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('file_path', '') or d.get('file_path', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")

[[ -z "$file_path" || ! -f "$file_path" ]] && exit 0

# Normalize to absolute path for matching.
abs="$(cd "$(dirname "$file_path")" 2>/dev/null && pwd)/$(basename "$file_path")" || exit 0

# Only act on docs/site/* markdown.
case "$abs" in
  */docs/site/*) ;;
  *) exit 0 ;;
esac
case "$abs" in
  */docs/site/pt-br/*) exit 0 ;;  # guard: never recurse on translations
esac
case "$abs" in
  *.md|*.mdx) ;;
  *) exit 0 ;;
esac

# Derive the project root (everything up to /docs/site/) and the relative path.
project_root="${abs%/docs/site/*}"
rel="${abs#"$project_root/docs/site/"}"
ptbr_path="$project_root/docs/site/pt-br/$rel"

# If pt-BR pair does not exist yet, nothing to mark; bootstrap will create it.
[[ ! -f "$ptbr_path" ]] && exit 0

sha=$(sha256sum "$abs" | awk '{print $1}')
[[ -z "$sha" ]] && exit 0

# Update frontmatter in-place: ensure needs_retranslation: true and source_hash: sha256:<sha>.
python3 - "$ptbr_path" "$sha" <<'PY' 2>/dev/null || exit 0
import re, sys, pathlib

path = pathlib.Path(sys.argv[1])
sha = sys.argv[2]
text = path.read_text()

m = re.match(r"^---\n(.*?)\n---\n", text, re.DOTALL)
if not m:
    # No frontmatter — prepend a minimal one.
    fm = f"---\nsource_hash: \"sha256:{sha}\"\nneeds_retranslation: true\n---\n"
    path.write_text(fm + text)
    sys.exit(0)

body = m.group(1)
lines = body.split("\n")
have_hash = have_flag = False
new_lines = []
for line in lines:
    if line.startswith("source_hash:"):
        new_lines.append(f'source_hash: "sha256:{sha}"')
        have_hash = True
    elif line.startswith("needs_retranslation:"):
        new_lines.append("needs_retranslation: true")
        have_flag = True
    else:
        new_lines.append(line)
if not have_hash:
    new_lines.append(f'source_hash: "sha256:{sha}"')
if not have_flag:
    new_lines.append("needs_retranslation: true")

new_body = "\n".join(new_lines)
path.write_text(f"---\n{new_body}\n---\n" + text[m.end():])
PY

# Append to dedupe-aware queue.
queue_dir="${HOME}/.octopus"
queue_file="$queue_dir/translation-queue.txt"
mkdir -p "$queue_dir" 2>/dev/null || exit 0

if [[ -f "$queue_file" ]]; then
  grep -Fxq "$ptbr_path" "$queue_file" 2>/dev/null || echo "$ptbr_path" >> "$queue_file"
else
  echo "$ptbr_path" > "$queue_file"
fi

echo "[mark-stale-translation] queued $rel" >&2
exit 0
