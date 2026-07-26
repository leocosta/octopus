#!/usr/bin/env bash
# Regression guard for the Windows installer (install.ps1). The .ps1 has no
# runtime coverage in this repo (no pwsh/Windows in CI), so this locks the
# invariants that, when they drifted from install.sh, broke Windows installs:
#
#   1. TLS 1.2 forced BEFORE any web call — the actual crash on Windows
#      PowerShell 5.1 ("Could not create SSL/TLS secure channel").
#   2. Downloads the signed *release asset*, not the bare git archive
#      (the archive lacks bin/fzf/windows-amd64/fzf.exe that `octopus setup` needs).
#   3. SHA-256 verified and the real checksum lands in metadata.json.
#   4. The Windows shims (bin/octopus.ps1 + octopus.cmd) are shipped in the
#      release tree and COPIED by install.ps1 (RM-019), not embedded via a
#      heredoc; the .ps1 path translation is Windows-PowerShell-5.1-safe (no
#      scriptblock substitution in -replace).
#   5. OCTOPUS_INSTALL_ENDPOINT / signature env knobs honored (parity w/ .sh).
#
# Static assertions only — this does not execute PowerShell. A behavioral,
# end-to-end test belongs in a pwsh CI job (mirror tests/test_installer.sh).
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PS1="$DIR/install.ps1"
SHIM_PS1="$DIR/bin/octopus.ps1"
SHIM_CMD="$DIR/bin/octopus.cmd"
PASS=0; FAIL=0
check() { local d="$1"; shift; if "$@"; then echo "PASS: $d"; PASS=$((PASS + 1)); else echo "FAIL: $d"; FAIL=$((FAIL + 1)); fi; }

[[ -f "$PS1" ]] || { echo "FAIL: install.ps1 not found at $PS1"; exit 1; }

# 1. TLS 1.2 forced before the first Invoke-* call.
t_tls_before_web() {
  local tls web
  tls="$(grep -nF 'SecurityProtocolType]::Tls12' "$PS1" | head -1 | cut -d: -f1)"
  web="$(grep -nE 'Invoke-RestMethod|Invoke-WebRequest' "$PS1" | head -1 | cut -d: -f1)"
  [[ -n "$tls" && -n "$web" && "$tls" -lt "$web" ]]
}
check "forces TLS 1.2 before the first network call" t_tls_before_web

# 2. Release asset, not the git archive. The tarball URL is built as
#    octopus-<v>.<suffix> with suffix 'tar.gz', under releases/download/.
t_release_asset() {
  grep -qF 'releases/download' "$PS1" \
    && grep -qF 'octopus-$v.$suffix' "$PS1" \
    && grep -qF "Resolve-AssetUrl \$Version 'tar.gz'" "$PS1"
}
check "resolves the release-asset tarball URL" t_release_asset
t_no_git_archive() { ! grep -qF 'archive/refs/tags' "$PS1"; }
check "does not reference the git archive URL" t_no_git_archive

# 3. SHA-256 verified, fail-closed, and written to metadata (never hardcoded "").
t_checksum() {
  grep -qF 'Get-FileHash' "$PS1" \
    && grep -qE 'Checksum mismatch' "$PS1" \
    && grep -qE 'checksum[[:space:]]*=[[:space:]]*\$DownloadedChecksum' "$PS1" \
    && ! grep -qE 'checksum[[:space:]]*=[[:space:]]*""' "$PS1"
}
check "verifies SHA-256 (fail-closed) and records it in metadata" t_checksum

# 4. Shims are shipped in the release tree and copied (RM-019), not embedded via
#    a heredoc; the .ps1 translation is 5.1-safe (no scriptblock -replace).
t_shims_exist() { [[ -f "$SHIM_PS1" && -f "$SHIM_CMD" ]]; }
check "ships bin/octopus.ps1 and bin/octopus.cmd" t_shims_exist

t_installer_copies_shims() {
  # install.ps1 copies the shipped shims and no longer embeds them via heredoc
  # (the embedded shim's `function Find-Bash {` is gone from the installer).
  grep -qF 'Copy-Item' "$PS1" \
    && grep -qF 'octopus.ps1' "$PS1" \
    && grep -qF 'octopus.cmd' "$PS1" \
    && ! grep -qE '^function Find-Bash \{' "$PS1"
}
check "install.ps1 copies the shipped shims (no embedded heredoc)" t_installer_copies_shims

t_shim_delegates() {
  # The .ps1 delegates to the version-independent current/bin/octopus; the .cmd
  # invokes it through powershell.
  grep -qF 'CurrentDir' "$SHIM_PS1" \
    && grep -qF 'bin\octopus' "$SHIM_PS1" \
    && grep -qF 'octopus.ps1' "$SHIM_CMD"
}
check "shims delegate to current/bin/octopus" t_shim_delegates

t_cmd_crlf_pinned() {
  # octopus.cmd must ship with CRLF (cmd.exe label/goto parsing is LF-fragile);
  # pinned in .gitattributes so it survives regardless of committer platform.
  grep -qE 'bin/octopus\.cmd[[:space:]]+text[[:space:]]+eol=crlf' "$DIR/.gitattributes"
}
check "bin/octopus.cmd is pinned to CRLF in .gitattributes" t_cmd_crlf_pinned

t_shim_51_safe() {
  # No scriptblock substitution in -replace anywhere (installer or shim — PS 6+
  # only); the .ps1 drive-letter translation uses -match/$Matches instead.
  ! grep -qE "\-replace[^#]*,[[:space:]]*\{" "$PS1" \
    && ! grep -qE "\-replace[^#]*,[[:space:]]*\{" "$SHIM_PS1" \
    && grep -qF 'Matches[1].ToLower()' "$SHIM_PS1"
}
check "WSL shim uses 5.1-safe -match/\$Matches (no scriptblock -replace)" t_shim_51_safe

# 5. Endpoint + signature env knobs honored.
t_endpoint()  { grep -qF 'OCTOPUS_INSTALL_ENDPOINT' "$PS1"; }
check "honors OCTOPUS_INSTALL_ENDPOINT" t_endpoint
t_sig_knobs() { grep -qF 'OCTOPUS_SKIP_SIGNATURE' "$PS1" && grep -qF 'OCTOPUS_REQUIRE_SIGNATURE' "$PS1"; }
check "honors OCTOPUS_SKIP_SIGNATURE / OCTOPUS_REQUIRE_SIGNATURE" t_sig_knobs

# 6. Web requests use -UseBasicParsing (avoids IE-engine failure on 5.1).
t_basic_parsing() { grep -qF '-UseBasicParsing' "$PS1"; }
check "web requests use -UseBasicParsing" t_basic_parsing

echo ""
echo "install.ps1 invariants: $PASS passed, $FAIL failed."
[[ "$FAIL" -eq 0 ]]
