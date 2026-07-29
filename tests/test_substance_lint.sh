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

t_summary() { "$LINT" "$tmp/hype.md" | grep -qE 'potential hype/FOMO'; }
check "prints a non-zero hit summary on hype copy" t_summary

t_clean() { "$LINT" "$tmp/sober.md" | grep -q 'substance-lint: clean'; }
check "passes clean on sober copy" t_clean

t_advisory() { "$LINT" "$tmp/hype.md" >/dev/null; [[ $? -eq 0 ]]; }
check "advisory by default (exit 0 on hits)" t_advisory

t_strict_fail() { "$LINT" --strict "$tmp/hype.md" >/dev/null; [[ $? -ne 0 ]]; }
check "exits non-zero under --strict on hits" t_strict_fail

t_strict_clean() { "$LINT" --strict "$tmp/sober.md" >/dev/null; [[ $? -eq 0 ]]; }
check "exits zero under --strict on clean copy" t_strict_clean

echo ""
echo "substance-lint: $PASS passed, $FAIL failed."
[[ "$FAIL" -eq 0 ]]
