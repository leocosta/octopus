#!/usr/bin/env bash
# substance-lint — flag two independent copy failures in generated marketing text:
#   hype — superlatives, FOMO, manufactured urgency (skills/_shared/substance-voice.md)
#   tell — constructions that mark text as LLM-generated (skills/_shared/human-voice.md)
# The axes are separate on purpose: copy can be entirely hype-free and still read as
# machine-written, and each finding calls for a different revision. Findings are
# labelled so the two stay distinguishable.
# Advisory by default (reports file:line, exit 0); pass --strict to exit non-zero.
set -uo pipefail

STRICT=0
args=()
for a in "$@"; do
  if [[ "$a" == "--strict" ]]; then STRICT=1; else args+=("$a"); fi
done
TARGET="${args[0]:-.}"

# Superlative/hype + FOMO/urgency terms (EN + PT). Accented and plain variants are
# listed explicitly to avoid multibyte chars inside bracket expressions.
PATTERN_HYPE='revolutioniz|revolutionary|\bunlock|seamless|game[ -]?changer|cutting[ -]?edge|world[ -]?class|\bpowerful\b|effortless|\bsynergy|don.t miss|last chance|act now|limited spots|only today|revolucion|incrível|incrivel|poderos[oa]|definitiv[oa]|imperdível|imperdivel|sensacional|simplesmente|não perca|nao perca|última chance|ultima chance|agora ou nunca|vagas limitadas|só hoje|so hoje|\bcorra\b'

# AI tells, calibrated for PRECISION over recall: a lint that cries wolf is a lint the
# team switches off. Words that are legitimate in technical copy are deliberately
# absent — `key` (API key), `critical` (critical path), `align` (align with the spec),
# `highlight` (highlight a row), `enhance` (a real improvement). Judgement calls that
# regex cannot make live in human-voice.md.
PATTERN_TELL='testament|pivotal|\bdelve|intricate|serves as|stands as|\bboasts\b|not just .{1,40} it.s|Despite these challenges|future looks bright|^Additionally,|tapestry|\brealm\b|underscor|fostering|showcas'

# PT tells are not translations of the EN list — Portuguese has its own: reflexive
# copula avoidance (`se destaca como`), linking gerunds after a finished clause,
# and signposting connectives. Precision matters more here, because `garantir`,
# `destacar`, `fundamental` and `robusto` are ordinary words in Brazilian technical
# writing. Every pattern below therefore anchors on syntactic position — a comma
# before the gerund, the reflexive before `como` — never on the bare word.
# Calibrated against the repo's own 89k-word pt-br docs: 1 hit, and that one legitimate.
PATTERN_TELL_PT='se destaca como|se consolida como|configura-se como|desempenha um papel (fundamental|crucial|essencial)|um marco (importante|histórico)|divisor de águas|não (apenas|só) .{1,50}(mas também|mas sim)|^Além disso,|Nesse sentido,|Dessa forma,|Vale (ressaltar|destacar) que|, (garantindo|visando|proporcionando|refletindo|ressaltando)|futuro (é|se mostra) (promissor|animador)|[Aa]pesar (desses|destes) desafios'

if [[ -d "$TARGET" ]]; then
  mapfile -t files < <(find "$TARGET" -type f \( -name '*.md' -o -name '*.html' -o -name '*.txt' \) 2>/dev/null)
else
  files=("$TARGET")
fi

# Mention vs use: a term quoted inside backticks is being named, not employed —
# documentation about this lint would otherwise flag itself on every example.
# Blanking the span (rather than deleting the line) keeps line numbers intact.
strip_code_spans() { sed 's/`[^`]*`//g' "$1" 2>/dev/null; }

hype=0; tell=0
for f in "${files[@]}"; do
  [[ -f "$f" ]] || continue
  while IFS=: read -r line text; do
    [[ -n "$line" ]] || continue
    printf '  [hype] %s:%s: %s\n' "$f" "$line" "$(printf '%s' "$text" | sed 's/^[[:space:]]*//')"
    hype=$((hype+1))
  done < <(strip_code_spans "$f" | grep -niE "$PATTERN_HYPE" 2>/dev/null)
  while IFS=: read -r line text; do
    [[ -n "$line" ]] || continue
    printf '  [tell] %s:%s: %s\n' "$f" "$line" "$(printf '%s' "$text" | sed 's/^[[:space:]]*//')"
    tell=$((tell+1))
  done < <(strip_code_spans "$f" | grep -niE "$PATTERN_TELL" 2>/dev/null)
  while IFS=: read -r line text; do
    [[ -n "$line" ]] || continue
    printf '  [tell] %s:%s: %s\n' "$f" "$line" "$(printf '%s' "$text" | sed 's/^[[:space:]]*//')"
    tell=$((tell+1))
  done < <(strip_code_spans "$f" | grep -nE "$PATTERN_TELL_PT" 2>/dev/null)
done

if [[ $((hype + tell)) -gt 0 ]]; then
  [[ "$hype" -gt 0 ]] && printf '\nsubstance-lint: %d potential hype/FOMO term(s) — revise or confirm (see skills/_shared/substance-voice.md).\n' "$hype"
  [[ "$tell" -gt 0 ]] && printf '\nsubstance-lint: %d AI tell(s) — revise or confirm (see skills/_shared/human-voice.md).\n' "$tell"
  [[ "$STRICT" == "1" ]] && exit 1
else
  echo "substance-lint: clean."
fi
exit 0
