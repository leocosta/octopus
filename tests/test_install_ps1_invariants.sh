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

# 7. Bash discovery — each assertion is a failure reproduced on a Windows 11 VM.
# Body of a PowerShell function (from `function <name> {` to the next `^}`).
ps_fn() { sed -n "/^function $2 {/,/^}/p" "$1"; }

t_skips_wsl_launchers() {
  # C:\Windows\System32\bash.exe and the WindowsApps alias are WSL launchers;
  # picking them sent a Git-Bash /c/... path into WSL and every command failed.
  local f
  for f in "$PS1:Find-BashExecutable" "$SHIM_PS1:Find-Bash"; do
    ps_fn "${f%%:*}" "${f##*:}" | grep -qF 'SystemRoot' || return 1
    ps_fn "${f%%:*}" "${f##*:}" | grep -qF 'WindowsApps' || return 1
  done
}
check "bash discovery skips the WSL launchers (System32 / WindowsApps)" t_skips_wsl_launchers

t_wsl_needs_distro() {
  # wsl.exe exists on every Windows even WITHOUT WSL; it is an executor only
  # once a distribution is registered (a DistributionName under Lxss).
  local f
  for f in "$PS1" "$SHIM_PS1"; do
    ps_fn "$f" Test-WslDistro | grep -qF 'Lxss' || return 1
    ps_fn "$f" Test-WslDistro | grep -qF 'DistributionName' || return 1
  done
  ps_fn "$PS1" Find-BashExecutable | grep -qF 'Test-WslDistro' \
    && ps_fn "$SHIM_PS1" Find-Bash | grep -qF 'Test-WslDistro'
}
check "WSL is only chosen when a distribution is registered" t_wsl_needs_distro

t_same_discovery() {
  # install.ps1 and the shim must agree on the executor, or install succeeds
  # with one bash and every command runs with another.
  diff <(ps_fn "$PS1" Test-WslDistro) <(ps_fn "$SHIM_PS1" Test-WslDistro) >/dev/null \
    && diff <(ps_fn "$PS1" Find-BashExecutable | sed '1d;$d' | grep -vE '^[[:space:]]*#|return \$null') \
            <(ps_fn "$SHIM_PS1" Find-Bash | sed '1d;$d' | grep -vE '^[[:space:]]*#|^    throw ') >/dev/null
}
check "install.ps1 and the shim share the same bash discovery" t_same_discovery

t_wsl_passes_cache() {
  # Inside WSL, $HOME is the Linux home: the Windows-side cache must be handed
  # over, through WSLENV, or bin/octopus finds no install.
  grep -qF 'WSLENV' "$SHIM_PS1" && grep -qF 'OCTOPUS_CLI_CACHE_ROOT' "$SHIM_PS1"
}
check "the WSL branch hands the Windows cache root to bin/octopus" t_wsl_passes_cache

t_shim_exit_code() { grep -qE '^exit \$LASTEXITCODE' "$SHIM_PS1"; }
check "the .ps1 shim propagates the CLI exit code" t_shim_exit_code

# 8. Git Bash cannot run .ps1/.cmd: the extensionless bash shim is installed too.
t_ships_bash_shim() { grep -qE '\$Shims = @\("octopus\.ps1", "octopus\.cmd", "octopus"\)' "$PS1"; }
check "installs the extensionless 'octopus' shim for Git Bash" t_ships_bash_shim
t_uninstall_bash_shim() { sed -n '/^if (\$Uninstall)/,/^}/p' "$PS1" | grep -qF 'Join-Path $BinDir "octopus"'; }
check "uninstall removes the extensionless shim too" t_uninstall_bash_shim

# 9. Python: probed by RUNNING it (the Store alias passes Get-Command).
t_python_probe() {
  ps_fn "$PS1" Test-Python | grep -qF "'py -3'" && ps_fn "$PS1" Test-Python | grep -qF -- '-c $probe'
}

# The Store alias must never be RUN: under $ErrorActionPreference = "Stop" its
# stderr is a terminating error on PS 5.1 and the installer died before its banner.
t_python_skips_alias() {
  ps_fn "$PS1" Test-Python | grep -qF 'WindowsApps' \
    && ps_fn "$PS1" Test-Python | grep -qE '\$ErrorActionPreference = "Continue"'
}
check "Python probe skips the Store alias instead of running it" t_python_skips_alias
check "warns when no working Python 3 runs (python3 / python / py -3)" t_python_probe

# 11. Windows PowerShell 5.1 reads a BOM-less .ps1 FILE as cp1252, where the
#     UTF-8 bytes of "—" (E2 80 94) include 0x94 = ”, which PowerShell accepts as
#     a quote: the string closes early and the whole script fails to parse
#     ("Missing closing '}'"). Reproduced running .\install.ps1 on a Win11 VM;
#     `irm | iex` hid it (irm decodes UTF-8). bin/octopus.ps1 ALWAYS runs as a
#     file. Comments are safe; code lines must not decode to smart quotes.
t_cp1252_safe() {
  python3 - "$PS1" "$SHIM_PS1" <<'PY'
import sys
bad = []
for path in sys.argv[1:]:
    for n, raw in enumerate(open(path, 'rb').read().split(b'\n'), 1):
        if raw.decode('utf-8').lstrip().startswith('#'):
            continue
        if any(c in '‘’“”' for c in raw.decode('cp1252', 'replace')):
            bad.append(f"{path.rsplit('/', 1)[-1]}:{n}")
if bad:
    print("  smart-quote bytes on code lines:", ", ".join(bad))
sys.exit(1 if bad else 0)
PY
}
check "no code line turns into a smart quote when PS 5.1 reads the file as cp1252" t_cp1252_safe

# 12. `irm … | iex` (the README command) runs the installer INSIDE the user's
#     session. A bare `exit` there closes their PowerShell window before they
#     can read the error, and script-level Set-StrictMode / ErrorActionPreference
#     leak into their session. So: the body runs in a child scope, failures go
#     through Stop-Install (a throw), and the single `exit` is guarded to fire
#     only when the installer runs as a FILE (exit code for CI/tests).
t_iex_no_bare_exit() {
  local exits
  exits="$(grep -vE '^[[:space:]]*#' "$PS1" | grep -cE '(^|[;{[:space:]])exit([[:space:]]|$)')"
  [[ "$exits" == "1" ]] && grep -qE '^if \(\$PSCommandPath -and \(Select-String -LiteralPath \$PSCommandPath -SimpleMatch .OCTOPUS_INSTALL_STOP. -Quiet\)\) \{ exit ' "$PS1"
}
check "irm | iex: no bare exit — one exit, only when run as a file" t_iex_no_bare_exit

t_iex_scoped_prefs() {
  # Strict mode / EAP are set inside the child scope (after the `& {` line), not at top level.
  local open strict
  open="$(grep -nE '^& \{' "$PS1" | head -1 | cut -d: -f1)"
  strict="$(grep -nE '^Set-StrictMode' "$PS1" | head -1 | cut -d: -f1)"
  [[ -n "$open" && -n "$strict" && "$strict" -gt "$open" ]]
}
check "irm | iex: StrictMode/ErrorActionPreference scoped to the installer" t_iex_scoped_prefs

t_iex_stop_install() { grep -qE '^function Stop-Install' "$PS1" && grep -qF 'Stop-Install 1' "$PS1"; }
check "failures go through Stop-Install instead of exit" t_iex_stop_install

t_latest_endpoint() { ps_fn "$PS1" Get-LatestVersion | grep -qF 'OCTOPUS_API_ENDPOINT'; }
check "latest-version lookup honours OCTOPUS_API_ENDPOINT (parity with bin/octopus)" t_latest_endpoint

# 13. Under the installer's ErrorActionPreference = "Stop", Windows PowerShell
#     5.1 turns ANY stderr line from a native command into a terminating
#     NativeCommandError — even with 2>$null. `gpg --verify` always writes to
#     stderr ("gpg: Signature made …"), and `gpg --list-keys` does on a first
#     install, so with gpg on PATH (Git's Unix tools, Gpg4win) every install
#     died inside signature verification. Every function that runs a native
#     tool whose stderr is expected must relax the preference locally.
t_native_stderr_safe() {
  local fn bad=0
  for fn in Test-Signature Test-Python; do
    ps_fn "$PS1" "$fn" | grep -qE '^\s+\$ErrorActionPreference = "Continue"' || { echo "  $fn runs native tools under EAP=Stop"; bad=1; }
  done
  return $bad
}
check "native tools with expected stderr (gpg, python probe) run with a local EAP=Continue" t_native_stderr_safe

# 14. Extraction uses Windows' own tar.exe by absolute path. With Git's
#     "optional Unix tools" on PATH, a bare `tar` is MSYS GNU tar, which reads
#     `C:\…` as host:path and fails with "Cannot connect to C: resolve failed"
#     — reproduced on a Win11 VM right after the gpg fix let installs get there.
t_windows_tar() {
  ! grep -vE '^[[:space:]]*#' "$PS1" | grep -qE '^[[:space:]]*tar[[:space:]]' \
    && grep -qF 'System32\tar.exe' "$PS1"
}
check "extracts with System32\\tar.exe, never the first tar on PATH (MSYS GNU tar)" t_windows_tar

# 10. Never suggest `setx PATH "%PATH%;…"` (copies the machine PATH, truncates at 1024).
t_no_setx() { ! grep -vE '^[[:space:]]*#' "$PS1" | grep -qE 'setx[[:space:]]+PATH'; }
check "does not suggest the truncating 'setx PATH' recipe" t_no_setx

echo ""
echo "install.ps1 invariants: $PASS passed, $FAIL failed."
[[ "$FAIL" -eq 0 ]]
