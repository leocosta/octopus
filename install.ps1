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

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

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
    )
    foreach ($s in $shims) { if (Test-Path $s) { Remove-Item $s -Force } }
    if (Test-Path $CacheRoot) { Remove-Item $CacheRoot -Recurse -Force }
    Write-Success "Octopus CLI removed."
    exit 0
}

# ── Prerequisites ──────────────────────────────────────────────────────────────

function Find-BashExecutable {
    $bashOnPath = Get-Command bash -ErrorAction SilentlyContinue
    $candidates = @(
        "C:\Program Files\Git\bin\bash.exe",
        "C:\Program Files (x86)\Git\bin\bash.exe",
        $(if ($bashOnPath) { $bashOnPath.Source } else { $null })
    )
    foreach ($c in $candidates) {
        if ($c -and (Test-Path $c)) { return $c }
    }
    if (Get-Command wsl -ErrorAction SilentlyContinue) { return "wsl" }
    return $null
}

$BashExe = Find-BashExecutable
if (-not $BashExe) {
    Write-Err "No bash executor found."
    Write-Host "Install Git for Windows (https://git-scm.com) or enable WSL to use Octopus CLI." -ForegroundColor Yellow
    exit 1
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

    if ($env:OCTOPUS_SKIP_SIGNATURE -eq '1') {
        Write-Warn "Skipping GPG signature verification (OCTOPUS_SKIP_SIGNATURE=1)."
        return $true
    }
    $gpg = Get-Command gpg -ErrorAction SilentlyContinue
    if (-not $gpg) {
        if ($env:OCTOPUS_REQUIRE_SIGNATURE -eq '1') {
            Write-Err "gpg not found — install GnuPG or set OCTOPUS_SKIP_SIGNATURE=1 to bypass."
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

function Get-LatestVersion {
    try {
        $response = Invoke-RestMethod -Uri "$GitHubApi/releases/latest" -UseBasicParsing -Headers @{ "User-Agent" = "octopus-installer" }
        return $response.tag_name
    } catch {
        Write-Err "Could not fetch latest version from GitHub."
        exit 1
    }
}

if (-not $Version) {
    Write-Info "Resolving latest version..."
    $Version = Get-LatestVersion
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
                Write-Info "Cache integrity check failed for $Version — re-downloading."
            }
        }
    } else {
        Write-Info "Cache for $Version has no integrity marker — re-downloading."
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
            exit 1
        }

        # SHA-256 (mandatory) — fail closed on mismatch.
        $ChecksumUrl = Resolve-AssetUrl $Version 'sha256'
        $ShaFile = Join-Path $TmpDir "octopus.sha256"
        if (-not (Get-RemoteFile -Url $ChecksumUrl -Dest $ShaFile -Optional)) {
            Write-Err "Failed to download checksum from $ChecksumUrl."
            exit 1
        }
        $expected = Get-Sha256Field $ShaFile
        $actual   = (Get-FileHash -Algorithm SHA256 -LiteralPath $TarFile).Hash
        if ($expected.ToLower() -ne $actual.ToLower()) {
            Write-Err "Checksum mismatch for $Version (expected $expected, got $actual)."
            exit 1
        }
        $DownloadedChecksum = $actual.ToLower()

        # Detached GPG signature (best-effort).
        $SigUrl  = Resolve-AssetUrl $Version 'tar.gz.asc'
        $SigFile = Join-Path $TmpDir "octopus.tar.gz.asc"
        if (Get-RemoteFile -Url $SigUrl -Dest $SigFile -Optional) {
            Write-Info "Verifying GPG signature..."
            if (-not (Test-Signature $TarFile $SigFile)) { exit 1 }
        } elseif ($env:OCTOPUS_REQUIRE_SIGNATURE -eq '1') {
            Write-Err "No signature published at $SigUrl (OCTOPUS_REQUIRE_SIGNATURE=1)."
            exit 1
        }

        Write-Info "Extracting..."
        # tar is available natively on Windows 10+.
        $ExtractDir = Join-Path $TmpDir "extract"
        New-Item -ItemType Directory -Path $ExtractDir | Out-Null
        tar -xzf $TarFile -C $ExtractDir
        if ($LASTEXITCODE -ne 0) {
            Write-Err "Failed to extract the release tarball."
            exit 1
        }

        # Find extracted directory (octopus-<version>/).
        $ExtractedDir = Get-ChildItem $ExtractDir -Directory | Where-Object { $_.Name -like "octopus-*" } | Select-Object -First 1
        if (-not $ExtractedDir) {
            Write-Err "Unexpected tarball structure."
            exit 1
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
$Shims = @("octopus.ps1", "octopus.cmd")

New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
foreach ($name in $Shims) {
    $src = Join-Path $ShimSourceDir $name
    if (-not (Test-Path $src)) {
        Write-Err "Shim not found in extracted release at $src"
        exit 1
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
        Write-Warn "Add it manually, e.g.:  setx PATH `"%PATH%;$BinDir`""
    }
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
Write-Host "  Requires: Git for Windows (https://git-scm.com) or WSL."
Write-Host ""
