#!/usr/bin/env bash
# Windows `current` link handling (bin/octopus + install.sh).
#
# Reproduced on a real Windows 11 VM: under Git Bash `ln -s` does not create a
# link — MSYS silently COPIES the target tree (rc 0). `octopus update` then
# turned the `current` junction into a 1000-file copy, wrote that copy into
# metadata.json, and every later update died on `rm: cannot remove 'current':
# Is a directory` — the install was stuck on the old release for good.
#
# Windows branches cannot execute here, so uname/cygpath/powershell.exe are
# faked and the PowerShell the helper would run is captured and asserted.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
check() { local d="$1"; shift; if "$@"; then echo "PASS: $d"; PASS=$((PASS + 1)); else echo "FAIL: $d"; FAIL=$((FAIL + 1)); fi; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

extract() { sed -n '/^# ── Windows `current` junction/,/^# The shared epilogue\|^# Update the "current" symlink/p' "$1" | sed '$d'; }

# 1. The helper block is byte-identical in both files (install.sh runs standalone).
t_identical() { diff <(extract "$DIR/bin/octopus") <(extract "$DIR/install.sh") >/dev/null; }
check "junction helpers identical in bin/octopus and install.sh" t_identical
t_nonempty() { [[ "$(extract "$DIR/bin/octopus" | grep -c '^_relink_junction()')" == 1 ]]; }
check "helper block is found" t_nonempty

extract "$DIR/bin/octopus" > "$tmp/helpers.sh"

# fakes <uname -s output>
fakes() {
  local d="$tmp/fake-$1"; mkdir -p "$d"
  printf '#!/bin/sh\necho %s\n' "$1" > "$d/uname"
  # cygpath -w <p> -> C:\fake<p> (printf %s: sh's echo would eat the backslash)
  printf '#!/bin/sh\nprintf "%%s\\n" "C:\\\\fake$2"\n' > "$d/cygpath"
  printf '#!/bin/sh\nprintf "%%s\\n" "$@" > "%s/ps.log"\n' "$tmp" > "$d/powershell.exe"
  chmod +x "$d"/*
  echo "$d"
}

# needs <uname> <path> [no-ps] → echoes yes/no
needs() {
  local d; d="$(fakes "$1")"
  [[ "${3:-}" == no-ps ]] && rm -f "$d/powershell.exe"
  PATH="$d:$PATH" bash -c "source '$tmp/helpers.sh'; _current_needs_junction '$2' && echo yes || echo no"
}

# 2. Platform detection.
t_mingw()   { [[ "$(needs MINGW64_NT-10.0 /c/Users/u/.octopus-cli/current)" == yes ]]; }
t_msys()    { [[ "$(needs MSYS_NT-10.0 /c/Users/u/.octopus-cli/current)" == yes ]]; }
t_linux()   { [[ "$(needs Linux /home/u/.octopus-cli/current)" == no ]]; }
t_wsl_mnt() { [[ "$(needs Linux /mnt/c/Users/u/.octopus-cli/current)" == yes ]]; }
t_wsl_mnt_no_interop() { [[ "$(needs Linux /mnt/c/Users/u/.octopus-cli/current no-ps)" == no ]]; }
t_darwin()  { [[ "$(needs Darwin /Users/u/.octopus-cli/current)" == no ]]; }
check "Git Bash (MINGW) uses a junction" t_mingw
check "MSYS uses a junction" t_msys
check "Linux keeps ln -s" t_linux
check "macOS keeps ln -s" t_darwin
check "WSL on a /mnt/<drive> cache uses a junction" t_wsl_mnt
check "WSL without Windows interop keeps ln -s" t_wsl_mnt_no_interop

# 3. The PowerShell it runs: removes a link non-recursively, makes a junction.
d="$(fakes MINGW64_NT-10.0)"
PATH="$d:$PATH" bash -c "source '$tmp/helpers.sh'; _relink_junction /c/Users/o\\'brien/.octopus-cli/current /c/Users/o\\'brien/.octopus-cli/cache/v2"
ps="$(cat "$tmp/ps.log" 2>/dev/null)"
t_junction()   { grep -qF 'New-Item -ItemType Junction' <<<"$ps"; }
t_link_safe()  { grep -qF '[IO.Directory]::Delete($l)' <<<"$ps"; }
t_copy_heal()  { grep -qE 'else \{ Remove-Item -LiteralPath \$l -Recurse' <<<"$ps"; }
t_paths()      { grep -qF "\$l = 'C:\\fake/c/Users/o''brien/.octopus-cli/current'" <<<"$ps"; }
t_noninteractive() { grep -qx -- '-NonInteractive' <<<"$ps"; }
check "creates an NTFS junction" t_junction
check "drops an existing link with Directory.Delete (never recurses into the release)" t_link_safe
check "only recurses into a real directory (a stale copy from ln -s)" t_copy_heal
check "passes Windows paths, single quotes escaped" t_paths
check "runs PowerShell non-interactively" t_noninteractive

# 4. No `ln -s` reaches `current` on the Windows path of either file.
t_update_current_guarded() {
  sed -n '/^update_current()/,/^}/p' "$DIR/bin/octopus" | awk '/_current_needs_junction/{g=1} /ln -sfn/{ if(!g) bad=1 } END{exit bad}'
}
t_update_symlink_guarded() {
  sed -n '/^update_symlink()/,/^}/p' "$DIR/install.sh" | awk '/_current_needs_junction/{g=1} /ln -sf/{ if(!g) bad=1 } END{exit bad}'
}
check "bin/octopus update_current checks for a junction before ln -sfn" t_update_current_guarded
check "install.sh update_symlink checks for a junction before ln -sf" t_update_symlink_guarded

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
