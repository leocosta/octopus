#!/usr/bin/env bash
# substance-lint — flag hype / FOMO / manufactured-urgency vocabulary in generated
# marketing copy. Advisory by default (reports file:line, exit 0); pass --strict to
# exit non-zero when hits are found. Case-insensitive, EN + PT. The governing rules
# live in skills/_shared/substance-voice.md.
set -uo pipefail

STRICT=0
args=()
for a in "$@"; do
  if [[ "$a" == "--strict" ]]; then STRICT=1; else args+=("$a"); fi
done
TARGET="${args[0]:-.}"

# Superlative/hype + FOMO/urgency terms (EN + PT). Accented and plain variants are
# listed explicitly to avoid multibyte chars inside bracket expressions.
PATTERN='revolutioniz|revolutionary|\bunlock|seamless|game[ -]?changer|cutting[ -]?edge|world[ -]?class|\bpowerful\b|effortless|\bsynergy|don.t miss|last chance|act now|limited spots|only today|revolucion|incrível|incrivel|poderos[oa]|definitiv[oa]|imperdível|imperdivel|sensacional|simplesmente|não perca|nao perca|última chance|ultima chance|agora ou nunca|vagas limitadas|só hoje|so hoje|\bcorra\b'

if [[ -d "$TARGET" ]]; then
  mapfile -t files < <(find "$TARGET" -type f \( -name '*.md' -o -name '*.html' -o -name '*.txt' \) 2>/dev/null)
else
  files=("$TARGET")
fi

hits=0
for f in "${files[@]}"; do
  [[ -f "$f" ]] || continue
  while IFS=: read -r line text; do
    [[ -n "$line" ]] || continue
    printf '  %s:%s: %s\n' "$f" "$line" "$(printf '%s' "$text" | sed 's/^[[:space:]]*//')"
    hits=$((hits+1))
  done < <(grep -niE "$PATTERN" "$f" 2>/dev/null)
done

if [[ "$hits" -gt 0 ]]; then
  printf '\nsubstance-lint: %d potential hype/FOMO term(s) — revise or confirm (see skills/_shared/substance-voice.md).\n' "$hits"
  [[ "$STRICT" == "1" ]] && exit 1
else
  echo "substance-lint: clean."
fi
exit 0
