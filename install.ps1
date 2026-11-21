# Octopus CLI Installer for Windows (PowerShell)
#
# Usage:
#   irm https://github.com/leocosta/octopus/releases/latest/download/install.ps1 | iex
#   # Or with a specific version:
#   & ([scriptblock]::Create((irm https://github.com/leocosta/octopus/releases/latest/download/install.ps1))) -Version v0.15.0
#
# Mirrors the release contract of install.sh (see that file for the reference
# implementation): downloads the signed *release asset* tarball — not the bare
# git archive — verifies its SHA-256 checksum, optionally verifies the detached
# GPG signature, then installs a bash-delegating shim (Git Bash or WSL).

[CmdletBinding()]
param(
    [string]$Version = "",
    [switch]$Force,
    [switch]$Uninstall
)

# `irm … | iex` — the README command — runs this script INSIDE the caller's
# session. A bare `exit` there closes their PowerShell window before they can
# read the error, and script-level StrictMode / ErrorActionPreference would
# stay set in their shell afterwards. So the whole installer runs in a child
# scope (`& { … }`, body deliberately not indented), failures throw through
# Stop-Install, and the only `exit` is at the very end, taken only when this
# runs as a file (.\install.ps1, CI) so the exit code is still reported.
$OctopusInstall = @{ ExitCode = 0 }
try {
& {
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# The marker string has two jobs: it is the sentinel the outer catch recognises
# as an orderly stop, and the text the exit guard at the end searches the running
# file for to know it IS this installer. Rename it in all three places or neither.
function Stop-Install ([int]$Code = 1) {
    $OctopusInstall.ExitCode = $Code
    throw "OCTOPUS_INSTALL_STOP"
}

# Windows PowerShell 5.1 still defaults SecurityProtocol to TLS 1.0/1.1, but
# api.github.com and github.com require TLS 1.2+. Without this the very first
# web call (version resolution / tarball download) fails with
# "Could not create SSL/TLS secure channel" — the reason `irm | iex` breaks on
# stock Windows while the WSL/curl path (OpenSSL) works. Force TLS 1.2 (and 1.3
# where the enum exists) before any network I/O.
try {
    [Net.ServicePointManager]::SecurityProtocol =
        [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    if ([enum]::GetNames([Net.SecurityProtocolType]) -contains 'Tls13') {
        [Net.ServicePointManager]::SecurityProtocol =
            [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls13
    }
} catch {
    # Older .NET without Tls12 in the enum — nothing we can do; continue and let
    # the network call surface a clear error.
}

$CacheRoot      = if ($env:OCTOPUS_CLI_CACHE_ROOT) { $env:OCTOPUS_CLI_CACHE_ROOT } else { Join-Path $HOME ".octopus-cli" }
$BinDir         = if ($env:OCTOPUS_BIN_DIR)         { $env:OCTOPUS_BIN_DIR }         else { Join-Path $HOME ".local\bin" }
$GitHubRepo     = "leocosta/octopus"
$GitHubApi      = "https://api.github.com/repos/$GitHubRepo"
$InstallEndpoint = if ($env:OCTOPUS_INSTALL_ENDPOINT) { $env:OCTOPUS_INSTALL_ENDPOINT.TrimEnd('/') } else { "" }

# Release signing trust anchor. Keep in sync with OCTOPUS_RELEASE_FPR in
# install.sh AND OCTOPUS_FPR in templates/github-actions/code-metrics-writer.yml.
$ReleaseFpr = if ($env:OCTOPUS_GPG_FINGERPRINT) { $env:OCTOPUS_GPG_FINGERPRINT } else { "63C35E66917CE4540CD27592C8BA059A0322F3CD" }
$GpgKeyserver = if ($env:OCTOPUS_GPG_KEYSERVER) { $env:OCTOPUS_GPG_KEYSERVER } else { "hkps://keys.openpgp.org" }

function Write-Info    ($msg) { Write-Host "i  $msg" -ForegroundColor Cyan }
function Write-Success ($msg) { Write-Host "v  $msg" -ForegroundColor Green }
function Write-Warn    ($msg) { Write-Host "!  $msg" -ForegroundColor Yellow }
function Write-Err     ($msg) { Write-Host "x  $msg" -ForegroundColor Red }

# ── Uninstall ──────────────────────────────────────────────────────────────────

if ($Uninstall) {
    Write-Info "Uninstalling Octopus CLI..."
    $shims = @(
        Join-Path $BinDir "octopus.ps1"
        Join-Path $BinDir "octopus.cmd"
        Join-Path $BinDir "octopus"
    )
    foreach ($s in $shims) { if (Test-Path $s) { Remove-Item $s -Force } }
    if (Test-Path $CacheRoot) { Remove-Item $CacheRoot -Recurse -Force }
    Write-Success "Octopus CLI removed."
    Stop-Install 0
}

# ── Prerequisites ──────────────────────────────────────────────────────────────

# `wsl.exe` ships with every Windows 10/11 even when WSL is not installed — it
# then only prints "The Windows Subsystem for Linux is not installed". WSL is a
# usable executor only once a distribution is registered.
function Test-WslDistro {
    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) { return $false }
    # Registered distributions are the subkeys of Lxss. Reading the registry
    # spawns nothing — `wsl.exe --list` can take seconds on a cold WSL service,
    # and the shim runs this on every command.
    $lxss = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss"
    return [bool](Get-ChildItem $lxss -ErrorAction SilentlyContinue | Where-Object { $_.GetValue("DistributionName") })
}

# Keep in sync with Find-Bash in bin/octopus.ps1.
function Find-BashExecutable {
    $gitBash = @(
        "C:\Program Files\Git\bin\bash.exe",
        "C:\Program Files (x86)\Git\bin\bash.exe",
        (Join-Path $env:LOCALAPPDATA "Programs\Git\bin\bash.exe")
    )
    foreach ($c in $gitBash) { if ($c -and (Test-Path $c)) { return $c } }
    # A bash.exe on PATH — except C:\Windows\System32\bash.exe and the
    # WindowsApps alias: those are WSL launchers, not Git Bash.
    foreach ($b in @(Get-Command bash.exe -All -ErrorAction SilentlyContinue)) {
        $src = $b.Source
        if ($src -like "$env:SystemRoot\*" -or $src -like "*\WindowsApps\*") { continue }
        return $src
    }
    if (Test-WslDistro) { return "wsl" }
    return $null
}

# setup and the hooks run on Python 3. `python3` is usually the Microsoft Store
# alias (…\WindowsApps\python3.exe, exits 9009) and python.org only ships
# python.exe. The alias is skipped by location, as cli/lib/python.sh does — never
# run: under the script-wide $ErrorActionPreference = "Stop", Windows PowerShell
# 5.1 turns its stderr into a terminating NativeCommandError (even with 2>$null),
# which aborted the installer right before its banner on a Win11 VM.
function Test-Python {
    $ErrorActionPreference = "Continue"
    $probe = "import sys; sys.exit(0 if sys.version_info[0] == 3 else 1)"
    foreach ($candidate in 'python3', 'python', 'py -3') {
        $exe, $rest = $candidate -split ' '
        $cmd = Get-Command $exe -CommandType Application -ErrorAction SilentlyContinue |
            Where-Object { $_.Source -notlike "*\WindowsApps\*" } | Select-Object -First 1
        if (-not $cmd) { continue }
        & $cmd.Source @rest -c $probe 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { return $true }
    }
    return $false
}

$BashExe = Find-BashExecutable
if (-not $BashExe) {
    Write-Err "No bash executor found."
    Write-Host "Install Git for Windows (https://git-scm.com/download/win), or WSL with a distribution" -ForegroundColor Yellow
    Write-Host "(wsl --install), then open a new terminal and run this installer again." -ForegroundColor Yellow
    Stop-Install 1
}

# ── Download helpers ────────────────────────────────────────────────────────────

function Test-IsHttpUrl ($u) { return $u -match '^https?://' }

# file:///C:/x -> C:/x ; file:///home/x -> /home/x
function Convert-FileUrlToPath ($u) {
    $p = $u -replace '^file://', ''
    if ($p -match '^/[A-Za-z]:') { $p = $p.Substring(1) }
    return $p
}

# Fetch $Url into $Dest. Supports http(s), file:// and bare local paths (the
# latter two back OCTOPUS_INSTALL_ENDPOINT for tests/offline mirrors, mirroring
# install.sh's curl file:// support). Returns $true on success. With -Optional a
# failed fetch returns $false instead of throwing.
function Get-RemoteFile {
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$Dest,
        [switch]$Optional
    )
    try {
        if ($Url -like 'file:*') {
            Copy-Item -LiteralPath (Convert-FileUrlToPath $Url) -Destination $Dest -Force
        } elseif (-not (Test-IsHttpUrl $Url)) {
            Copy-Item -LiteralPath $Url -Destination $Dest -Force
        } else {
            $ProgressPreference = "SilentlyContinue"
            Invoke-WebRequest -Uri $Url -OutFile $Dest -UseBasicParsing -Headers @{ "User-Agent" = "octopus-installer" }
        }
        return $true
    } catch {
        if ($Optional) { return $false }
        throw
    }
}

# ── Release artifact URL resolvers (parity with install.sh) ──────────────────────

# Release asset URL (the tarball bundles fzf binaries incl. windows-amd64 — the
# git archive does not). OCTOPUS_INSTALL_ENDPOINT overrides the base for
# tests/offline mirrors. Suffix is 'tar.gz' | 'sha256' | 'tar.gz.asc'.
function Resolve-AssetUrl ($v, $suffix) {
    $base = if ($InstallEndpoint) { $InstallEndpoint } else { "https://github.com/$GitHubRepo/releases/download" }
    return "$base/$v/octopus-$v.$suffix"
}

function Get-Sha256Field ($path) {
    return ((Get-Content -LiteralPath $path -Raw).Trim() -split '\s+')[0]
}

# ── GPG signature verification (best-effort) ─────────────────────────────────────
#
# The pinned SHA-256 protects transport; the signature protects against a mirror
# serving a tampered tarball with a matching checksum. This implements install.sh's
# DEFAULT pinned-fingerprint path plus OCTOPUS_SKIP_SIGNATURE / OCTOPUS_REQUIRE_SIGNATURE.
# It intentionally does NOT port install.sh's OCTOPUS_GPG_KEYRING /
# OCTOPUS_GPG_IMPORT_KEY trust-root overrides — those advanced knobs stay Unix-only
# for now. Skip when gpg/key unavailable (warn, checksum-only) unless REQUIRE; a
# present-but-wrong signature always fails closed.
function Test-Signature {
    param([Parameter(Mandatory)][string]$Tarball, [Parameter(Mandatory)][string]$Signature)

    # gpg reports progress on stderr ("gpg: Signature made …", "No public key"
    # on a first install). Under the script-wide "Stop", Windows PowerShell 5.1
    # turns that into a terminating NativeCommandError even with 2>$null, so
    # every install with gpg on PATH died here. The verdict comes from the
    # --status-fd output and exit codes below, never from stderr.
    $ErrorActionPreference = "Continue"

    if ($env:OCTOPUS_SKIP_SIGNATURE -eq '1') {
        Write-Warn "Skipping GPG signature verification (OCTOPUS_SKIP_SIGNATURE=1)."
        return $true
    }
    $gpg = Get-Command gpg -ErrorAction SilentlyContinue
    if (-not $gpg) {
        if ($env:OCTOPUS_REQUIRE_SIGNATURE -eq '1') {
            Write-Err "gpg not found - install GnuPG or set OCTOPUS_SKIP_SIGNATURE=1 to bypass."
            return $false
        }
        Write-Warn "gpg not found; continuing with checksum-only verification."
        return $true
    }

    # Self-bootstrap: fetch the pinned release key by full fingerprint if absent.
    & gpg --list-keys $ReleaseFpr 2>$null 1>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Info "Fetching Octopus release key $ReleaseFpr from $GpgKeyserver..."
        & gpg --batch --quiet --keyserver $GpgKeyserver --recv-keys $ReleaseFpr 2>$null 1>$null
    }

    $status = (& gpg --verify --batch --no-auto-key-locate --status-fd 1 $Signature $Tarball 2>$null) -join "`n"
    $validFromPin = $status -match "\[GNUPG:\] VALIDSIG [^\r\n]*$ReleaseFpr"
    $badSig       = $status -match "\[GNUPG:\] BADSIG"
    $anyValidSig  = $status -match "\[GNUPG:\] VALIDSIG"
    $noPubKey     = $status -match "\[GNUPG:\] NO_PUBKEY"

    if ($validFromPin) { Write-Success "Signature valid."; return $true }

    if ($badSig -or $anyValidSig) {
        Write-Err "GPG signature verification failed for $(Split-Path $Tarball -Leaf)."
        Write-Host "  The signature is not a valid Octopus release signature ($ReleaseFpr)." -ForegroundColor Red
        return $false
    }

    if ($noPubKey) {
        if ($env:OCTOPUS_REQUIRE_SIGNATURE -eq '1') {
            Write-Err "Could not obtain the Octopus release key ($ReleaseFpr) from $GpgKeyserver (OCTOPUS_REQUIRE_SIGNATURE=1)."
            return $false
        }
        Write-Warn "Could not obtain the Octopus release key ($ReleaseFpr); continuing with checksum-only verification."
        return $true
    }

    Write-Err "GPG signature verification failed for $(Split-Path $Tarball -Leaf)."
    return $false
}

# ── Version resolution ─────────────────────────────────────────────────────────

# OCTOPUS_API_ENDPOINT — the knob bin/octopus already honours — points "latest"
# at a mirror (http(s), file:// or a path) instead of api.github.com.
function Get-LatestVersion {
    $api = if ($env:OCTOPUS_API_ENDPOINT) { $env:OCTOPUS_API_ENDPOINT } else { "$GitHubApi/releases/latest" }
    if ($api -like 'http://*') {
        Write-Warn "OCTOPUS_API_ENDPOINT is plain http:// - the version lookup is not protected by TLS."
    }
    $tmp = [System.IO.Path]::GetTempFileName()
    try {
        Get-RemoteFile -Url $api -Dest $tmp | Out-Null
        # [string]: ConvertFrom-Json is untyped, and an array would slip past -notmatch.
        return [string](Get-Content -LiteralPath $tmp -Raw | ConvertFrom-Json).tag_name
    } catch {
        Write-Err "Could not fetch the latest version from $api."
        Stop-Install 1
    } finally {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    }
}

if (-not $Version) {
    Write-Info "Resolving latest version..."
    $Version = Get-LatestVersion
}

# $Version becomes $CacheDir\<version> (later removed with Remove-Item -Recurse)
# and part of the download URL. Accept only the tag-or-SHA shape bin/octopus
# enforces on the lockfile, so a mirror's tag_name or -Version cannot point the
# install outside the cache (`..\..\Documents`).
# Case-sensitive and anchored with \z (.NET `$` also matches before a final
# newline); the suffix must end in an alphanumeric, since Win32 drops trailing
# dots and `v1.2.3-rc.` would share the `v1.2.3-rc` cache dir.
$Version = [string]$Version
if ($Version -cnotmatch '^v?[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]*[0-9A-Za-z])?\z' -and $Version -cnotmatch '^[0-9a-f]{7,40}\z') {
    $shown = $Version -replace '[\x00-\x1f\x7f]', '?'   # mirror-supplied: no terminal escapes
    Write-Err "Refusing malformed version '$shown' (expected a release tag such as v1.2.3)."
    Stop-Install 1
}

Write-Success "Installing Octopus $Version"

# ── Download, verify & extract ───────────────────────────────────────────────────

$CacheDir = Join-Path $CacheRoot "cache"
$DestDir  = Join-Path $CacheDir $Version
$Marker   = Join-Path $DestDir ".cache-sha256"
$DownloadedChecksum = ""

# Decide whether the cached copy can be reused. A missing integrity marker forces
# a re-download — this heals installs left by the older installer that fetched the
# git archive (no bundled fzf) and wrote no marker.
$NeedDownload = $true
if ((Test-Path $DestDir) -and -not $Force) {
    if (Test-Path $Marker) {
        $tmpSha  = [System.IO.Path]::GetTempFileName()
        $fetched = Get-RemoteFile -Url (Resolve-AssetUrl $Version 'sha256') -Dest $tmpSha -Optional
        $freshSha = if ($fetched) { Get-Sha256Field $tmpSha } else { "" }
        Remove-Item $tmpSha -Force -ErrorAction SilentlyContinue

        if (-not $fetched) {
            Write-Info "Octopus $Version already cached at $DestDir (no checksum endpoint)"
            $NeedDownload = $false
        } else {
            $cachedSha = (Get-Content -LiteralPath $Marker -Raw).Trim()
            if ($freshSha -and ($freshSha.ToLower() -eq $cachedSha.ToLower())) {
                Write-Info "Octopus $Version already cached at $DestDir (integrity OK)"
                $DownloadedChecksum = $cachedSha
                $NeedDownload = $false
            } else {
                Write-Info "Cache integrity check failed for $Version - re-downloading."
            }
        }
    } else {
        Write-Info "Cache for $Version has no integrity marker - re-downloading."
    }
}

if ($NeedDownload) {
    Write-Info "Downloading Octopus $Version..."

    $TmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "octopus-install-$([System.Guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $TmpDir | Out-Null

    try {
        $TarUrl  = Resolve-AssetUrl $Version 'tar.gz'
        $TarFile = Join-Path $TmpDir "octopus.tar.gz"
        if (-not (Get-RemoteFile -Url $TarUrl -Dest $TarFile -Optional)) {
            Write-Err "Failed to download $Version from $TarUrl."
            Write-Host "Check that the tag exists: https://github.com/$GitHubRepo/releases" -ForegroundColor Yellow
            Stop-Install 1
        }

        # SHA-256 (mandatory) — fail closed on mismatch.
        $ChecksumUrl = Resolve-AssetUrl $Version 'sha256'
        $ShaFile = Join-Path $TmpDir "octopus.sha256"
        if (-not (Get-RemoteFile -Url $ChecksumUrl -Dest $ShaFile -Optional)) {
            Write-Err "Failed to download checksum from $ChecksumUrl."
            Stop-Install 1
        }
        $expected = Get-Sha256Field $ShaFile
        $actual   = (Get-FileHash -Algorithm SHA256 -LiteralPath $TarFile).Hash
        if ($expected.ToLower() -ne $actual.ToLower()) {
            Write-Err "Checksum mismatch for $Version (expected $expected, got $actual)."
            Stop-Install 1
        }
        $DownloadedChecksum = $actual.ToLower()

        # Detached GPG signature (best-effort).
        $SigUrl  = Resolve-AssetUrl $Version 'tar.gz.asc'
        $SigFile = Join-Path $TmpDir "octopus.tar.gz.asc"
        if (Get-RemoteFile -Url $SigUrl -Dest $SigFile -Optional) {
            Write-Info "Verifying GPG signature..."
            if (-not (Test-Signature $TarFile $SigFile)) { Stop-Install 1 }
        } elseif ($env:OCTOPUS_REQUIRE_SIGNATURE -eq '1') {
            Write-Err "No signature published at $SigUrl (OCTOPUS_REQUIRE_SIGNATURE=1)."
            Stop-Install 1
        }

        Write-Info "Extracting..."
        # Windows' own tar.exe (bsdtar, Windows 10 1803+), by absolute path: with
        # Git's "optional Unix tools" on PATH a bare `tar` is MSYS GNU tar,
        # which reads C:\... as host:path ("Cannot connect to C: resolve failed").
        $Tar = Join-Path $env:SystemRoot "System32\tar.exe"
        if (-not (Test-Path $Tar)) { $Tar = "tar" }
        $ExtractDir = Join-Path $TmpDir "extract"
        New-Item -ItemType Directory -Path $ExtractDir | Out-Null
        & $Tar -xzf $TarFile -C $ExtractDir
        if ($LASTEXITCODE -ne 0) {
            Write-Err "Failed to extract the release tarball."
            Stop-Install 1
        }

        # Find extracted directory (octopus-<version>/).
        $ExtractedDir = Get-ChildItem $ExtractDir -Directory | Where-Object { $_.Name -like "octopus-*" } | Select-Object -First 1
        if (-not $ExtractedDir) {
            Write-Err "Unexpected tarball structure."
            Stop-Install 1
        }

        New-Item -ItemType Directory -Path $CacheDir -Force | Out-Null
        if (Test-Path $DestDir) { Remove-Item $DestDir -Recurse -Force }
        Move-Item $ExtractedDir.FullName $DestDir

        # Integrity marker so future runs can detect stale/partial caches.
        Set-Content -Path (Join-Path $DestDir ".cache-sha256") -Value $DownloadedChecksum -Encoding ASCII

        Write-Success "Octopus $Version cached at $DestDir"
    } finally {
        Remove-Item $TmpDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ── current symlink (junction on Windows) ─────────────────────────────────────

$CurrentLink = Join-Path $CacheRoot "current"
Remove-Item $CurrentLink -Force -Recurse -ErrorAction SilentlyContinue
New-Item -ItemType Junction -Path $CurrentLink -Target $DestDir | Out-Null

# ── Write metadata.json ────────────────────────────────────────────────────────

$MetadataFile = Join-Path $CacheRoot "metadata.json"
$Timestamp    = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
@{
    version      = $Version
    checksum     = $DownloadedChecksum
    installed_at = $Timestamp
    release_path = $DestDir
} | ConvertTo-Json | Set-Content -Path $MetadataFile -Encoding UTF8

# ── Install shim ───────────────────────────────────────────────────────────────
#
# Copy the shims shipped in the release tree (bin/octopus.ps1 + octopus.cmd)
# rather than embedding them here — mirrors install.sh's install_shim (RM-019),
# so a shim change ships with the release instead of being frozen into the
# installer. Both delegate to the version-independent `current` link, so they
# need no per-version healing.
$ShimSourceDir = Join-Path $DestDir "bin"
# `octopus` (no extension) is the bash shim itself: Git Bash shares the Windows
# PATH but cannot run .ps1/.cmd, so without it `octopus` is "command not found"
# there. PowerShell and cmd ignore it (not in PATHEXT).
$Shims = @("octopus.ps1", "octopus.cmd", "octopus")

New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
foreach ($name in $Shims) {
    $src = Join-Path $ShimSourceDir $name
    if (-not (Test-Path $src)) {
        Write-Err "Shim not found in extracted release at $src"
        Stop-Install 1
    }
    Copy-Item -LiteralPath $src -Destination (Join-Path $BinDir $name) -Force
}

Write-Success "Installed shim to $BinDir"

# ── PATH check ─────────────────────────────────────────────────────────────────

$UserPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
if ([string]::IsNullOrEmpty($UserPath) -or ($UserPath -notlike "*$BinDir*")) {
    Write-Warn "$BinDir is not in your PATH."
    if ([Environment]::UserInteractive) {
        $addPath = Read-Host "Add it to your user PATH? [Y/n]"
        if ($addPath -ne "n" -and $addPath -ne "N") {
            $newPath = if ([string]::IsNullOrEmpty($UserPath)) { $BinDir } else { "$UserPath;$BinDir" }
            [System.Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
            $env:PATH = "$env:PATH;$BinDir"
            Write-Success "Added $BinDir to PATH. Restart your shell to apply."
        }
    } else {
        # Not `setx PATH "%PATH%;…"`: that copies the MACHINE path into the user
        # path and truncates it at 1024 characters.
        Write-Warn "Add it to your user PATH, then open a new terminal:"
        Write-Host "    [Environment]::SetEnvironmentVariable('PATH', [Environment]::GetEnvironmentVariable('PATH','User') + ';$BinDir', 'User')" -ForegroundColor Yellow
    }
}

# ── Python check ───────────────────────────────────────────────────────────────
# Under WSL the distribution's own Python is used; Git Bash uses Windows Python.
if ($BashExe -ne "wsl" -and -not (Test-Python)) {
    Write-Warn "No working Python 3 found (tried python3, python, py -3)."
    Write-Host "    'octopus setup' and the Claude Code hooks need it. Install Python 3 from" -ForegroundColor Yellow
    Write-Host "    https://www.python.org/downloads/ (tick 'Add python.exe to PATH'), then open a new terminal." -ForegroundColor Yellow
    Write-Host "    ('python3' on Windows is usually the Microsoft Store alias, not Python.)" -ForegroundColor Yellow
}

# ── Welcome banner ─────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "  🐙  OCTOPUS  CLI" -ForegroundColor Green
Write-Host ""
Write-Success "Octopus CLI $Version installed!"
Write-Host ""
Write-Host "  Get started:"
Write-Host "    octopus setup     " -NoNewline; Write-Host "Configure Octopus in the current repository" -ForegroundColor Cyan
Write-Host "    octopus doctor    " -NoNewline; Write-Host "Verify installation health" -ForegroundColor Cyan
Write-Host "    octopus --help    " -NoNewline; Write-Host "Show all available commands" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Docs: https://github.com/leocosta/octopus"
Write-Host ""
Write-Host "  Note: Octopus CLI on Windows runs via Git Bash or WSL."
Write-Host "  Requires: Git for Windows + Python 3, or WSL with a distribution."
Write-Host ""
}
} catch {
    if ("$_" -ne "OCTOPUS_INSTALL_STOP") {
        Write-Host "x  $_" -ForegroundColor Red
        Write-Host $_.InvocationInfo.PositionMessage -ForegroundColor DarkGray
        $OctopusInstall.ExitCode = 1
    }
}
# Exit only when THIS file is the running script (.\install.ps1, CI). Under
# `irm | iex` from inside someone's script, $PSCommandPath is THEIR file —
# exiting would end their script, even after a successful install — so the
# running file must be this installer (it carries the stop marker).
if ($PSCommandPath -and (Select-String -LiteralPath $PSCommandPath -SimpleMatch 'OCTOPUS_INSTALL_STOP' -Quiet)) { exit $OctopusInstall.ExitCode }
$global:LASTEXITCODE = $OctopusInstall.ExitCode
$OctopusInstallCode = $OctopusInstall.ExitCode
Remove-Variable OctopusInstall -ErrorAction SilentlyContinue
# No exit was taken (irm | iex). A failure must still stop a caller's script, so
# throw once: at an interactive prompt that is a red error and the window stays.
if ($OctopusInstallCode -ne 0) {
    Remove-Variable OctopusInstallCode -ErrorAction SilentlyContinue
    throw "Octopus install failed (exit code $global:LASTEXITCODE)."
}
Remove-Variable OctopusInstallCode -ErrorAction SilentlyContinue
