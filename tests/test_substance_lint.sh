#!/usr/bin/env bash
# Static + behavioral guard for the shared substance-voice gate.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LINT="$DIR/skills/_shared/substance-lint.sh"
PASS=0; FAIL=0
check() { local d="$1"; shift; if "$@"; then echo "PASS: $d"; PASS=$((PASS+1)); else echo "FAIL: $d"; FAIL=$((FAIL+1)); fi; }

[[ -f "$LINT" ]] || { echo "FAIL: substance-lint.sh missing"; exit 1; }
chmod +x "$LINT" 2>/dev/null || true

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/hype.md" <<'EOF'
Our revolutionary, game-changer platform. Don't miss out — last chance!
Uma solução simplesmente incrível. Não perca, vagas limitadas!
EOF
cat > "$tmp/sober.md" <<'EOF'
Exports run in 1.4s (was 4.2s). See what changed and adopt it in two lines.
Os relatórios saem em 1,4s. Veja o que mudou e ative no painel.
EOF

t_flags_hype() { local out; out=$("$LINT" "$tmp/hype.md"); grep -qiE 'revolutionary|game.changer|last chance|incrível|não perca|vagas limitadas' <<<"$out"; }
check "flags hype/FOMO terms (EN + PT)" t_flags_hype

t_summary() { local out; out=$("$LINT" "$tmp/hype.md"); grep -qE 'potential hype/FOMO' <<<"$out"; }
check "prints a non-zero hit summary on hype copy" t_summary

t_clean() { local out; out=$("$LINT" "$tmp/sober.md"); grep -q 'substance-lint: clean' <<<"$out"; }
check "passes clean on sober copy" t_clean

t_advisory() { "$LINT" "$tmp/hype.md" >/dev/null; [[ $? -eq 0 ]]; }
check "advisory by default (exit 0 on hits)" t_advisory

t_strict_fail() { "$LINT" --strict "$tmp/hype.md" >/dev/null; [[ $? -ne 0 ]]; }
check "exits non-zero under --strict on hits" t_strict_fail

t_strict_after_target() { "$LINT" "$tmp/hype.md" --strict >/dev/null; [[ $? -ne 0 ]]; }
check "recognizes --strict after the target" t_strict_after_target

t_strict_clean() { "$LINT" --strict "$tmp/sober.md" >/dev/null; [[ $? -eq 0 ]]; }
check "exits zero under --strict on clean copy" t_strict_clean

t_release_wired() {
  grep -qF 'substance-voice.md' "$DIR/skills/launch-release/SKILL.md" \
    && grep -qF 'substance-lint.sh' "$DIR/skills/launch-release/SKILL.md"
}
check "launch-release wires substance-voice + lint" t_release_wired

t_feature_wired() {
  grep -qF 'substance-voice.md' "$DIR/skills/launch-feature/SKILL.md" \
    && grep -qF 'substance-lint.sh' "$DIR/skills/launch-feature/SKILL.md"
}
check "launch-feature wires substance-voice + lint" t_feature_wired

# --- RM-167: the anti-tell class -------------------------------------------
# Hype and AI-tells are independent axes. This copy carries a dozen tells and
# zero hype — it returned "clean" before RM-167, which is the whole point.
cat > "$tmp/tells.md" <<'EOF'
Smart Sync stands as a testament to our work, marking a pivotal moment.
It serves as the foundation for a better workflow.
It's not just a sync engine, it's a rethinking of state.
Additionally, the feature delves into the intricate interplay of state.
Despite these challenges, Smart Sync continues to evolve. The future looks bright.
EOF

t_flags_tells() {
  local out; out=$("$LINT" "$tmp/tells.md")
  grep -qiE 'testament|pivotal|serves as|delve|intricate' <<<"$out"
}
check "flags AI tells in hype-free copy" t_flags_tells

# The two classes must stay separately diagnosable — a hype hit and a tell hit
# call for different revisions.
t_labels_separately() {
  local out; out=$("$LINT" "$tmp/tells.md")
  grep -qiE 'tell' <<<"$out"
}
check "reports tells under their own label" t_labels_separately

t_hype_label_intact() { local out; out=$("$LINT" "$tmp/hype.md"); grep -qE 'hype/FOMO' <<<"$out"; }
check "hype label unchanged by the new class" t_hype_label_intact

t_strict_tells() { "$LINT" --strict "$tmp/tells.md" >/dev/null; [[ $? -ne 0 ]]; }
check "exits non-zero under --strict on tells" t_strict_tells

# Precision over recall: a noisy lint is a lint the team switches off. These
# words are legitimate in technical copy and must not fire.
cat > "$tmp/technical.md" <<'EOF'
Rotate the API key before the critical path runs. Align the payload with the spec.
Highlight the failing row. This release enhances export throughput by 40%.
EOF
t_no_false_positives() { local out; out=$("$LINT" "$tmp/technical.md"); grep -q 'substance-lint: clean' <<<"$out"; }
check "no false positives on legitimate technical copy" t_no_false_positives

t_sober_still_clean() { local out; out=$("$LINT" "$tmp/sober.md"); grep -q 'substance-lint: clean' <<<"$out"; }
check "sober copy still clean under both classes" t_sober_still_clean

# Mention vs use: naming a banned term inside backticks is documentation, not a
# violation. Found by running the lint against this change's own PR body.
cat > "$tmp/mentions.md" <<'EOF'
Avoid `testament` and `pivotal` in copy; `serves as` is copula avoidance.
The phrase `not just X, it's Y` is a negative parallelism, and `revolutionary` is hype.
EOF
t_mentions_not_flagged() { local out; out=$("$LINT" "$tmp/mentions.md"); grep -q 'substance-lint: clean' <<<"$out"; }
check "quoted terms are mentions, not violations" t_mentions_not_flagged

# ...but the same words outside backticks still fire.
cat > "$tmp/uses.md" <<'EOF'
This release is a testament to the team and marks a pivotal moment.
EOF
t_unquoted_still_flagged() { local out; out=$("$LINT" "$tmp/uses.md"); grep -qi 'testament' <<<"$out"; }
check "the same terms unquoted still fire" t_unquoted_still_flagged

# --- pt-br tells -----------------------------------------------------------
# The hype axis was already bilingual; the tell axis shipped EN-only, leaving a
# Portuguese-language project with half a gate. PT tells are not translations —
# they are their own constructions (linking gerunds, signposting connectives,
# reflexive copula avoidance).
cat > "$tmp/tells-pt.md" <<'EOF'
O Smart Sync se destaca como um marco importante para a plataforma.
Ele desempenha um papel fundamental no fluxo, garantindo mais confiabilidade.
Não é apenas um motor de sincronização, mas também uma nova forma de pensar estado.
Nesse sentido, vale ressaltar que o futuro é promissor.
EOF

t_flags_tells_pt() {
  local out; out=$("$LINT" "$tmp/tells-pt.md")
  grep -qiE 'se destaca como|papel fundamental|garantindo|futuro é promissor' <<<"$out"
}
check "flags AI tells in pt-br copy" t_flags_tells_pt

# Precision matters more in PT: garantir, destacar, fundamental and robusto are
# ordinary words in Brazilian technical writing. The patterns anchor on syntactic
# position (comma + gerund, reflexive + "como") rather than the bare word.
cat > "$tmp/technical-pt.md" <<'EOF'
Garanta a consistência antes de aplicar a migração. O caminho crítico é robusto.
Destaque a linha com erro. Este release melhora a exportação em 40%.
A skill é fundamental para o fluxo e busca reduzir o custo de contexto.
EOF
t_no_false_positives_pt() { local out; out=$("$LINT" "$tmp/technical-pt.md"); grep -q 'substance-lint: clean' <<<"$out"; }
check "no false positives on legitimate pt-br technical copy" t_no_false_positives_pt

# Regression guard against a noisy PT list: the repo's own published pt-br docs
# are 89k words of Portuguese the project considers shippable. A pattern that
# fires here is either wrong or the docs need work — either way, a signal.
t_ptbr_corpus_quiet() {
  local out n
  out=$("$LINT" "$DIR/docs/site/pt-br/" 2>/dev/null)
  n=$(grep -c '\[tell\]' <<<"$out" || true)
  [[ "$n" -le 2 ]]
}
check "published pt-br docs stay under 3 tell hits" t_ptbr_corpus_quiet

t_human_voice_pt() { grep -qiE 'se destaca como|papel fundamental|Nesse sentido' "$DIR/skills/_shared/human-voice.md"; }
check "human-voice.md documents the pt-br constructions" t_human_voice_pt

t_human_voice_exists() { [[ -f "$DIR/skills/_shared/human-voice.md" ]]; }
check "human-voice.md fragment exists" t_human_voice_exists

t_human_voice_wired() {
  grep -qF 'human-voice.md' "$DIR/skills/launch-release/SKILL.md" \
    && grep -qF 'human-voice.md' "$DIR/skills/launch-feature/SKILL.md"
}
check "both launch skills wire human-voice.md" t_human_voice_wired

echo ""
echo "substance-lint: $PASS passed, $FAIL failed."
[[ "$FAIL" -eq 0 ]]
