# Octopus CLI Installer for Windows (PowerShell)
#
# Usage:
#   irm https://github.com/leocosta/octopus/releases/latest/download/install.ps1 | iex
#   # Or with a specific version:
#   & ([scriptblock]::Create((irm https://github.com/leocosta/octopus/releases/latest/download/install.ps1))) -Version v0.15.0

[CmdletBinding()]
param(
    [string]$Version = "",
    [switch]$Force,
    [switch]$Uninstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$CacheRoot  = if ($env:OCTOPUS_CLI_CACHE_ROOT) { $env:OCTOPUS_CLI_CACHE_ROOT } else { Join-Path $HOME ".octopus-cli" }
$BinDir     = if ($env:OCTOPUS_BIN_DIR)         { $env:OCTOPUS_BIN_DIR }         else { Join-Path $HOME ".local\bin" }
$GitHubRepo = "leocosta/octopus"
$GitHubApi  = "https://api.github.com/repos/$GitHubRepo"

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

# ── Version resolution ─────────────────────────────────────────────────────────

function Get-LatestVersion {
    try {
        $response = Invoke-RestMethod -Uri "$GitHubApi/releases/latest" -Headers @{ "User-Agent" = "octopus-installer" }
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

# ── Download & extract ─────────────────────────────────────────────────────────

$CacheDir = Join-Path $CacheRoot "cache"
$DestDir  = Join-Path $CacheDir $Version

if ((Test-Path $DestDir) -and -not $Force) {
    Write-Info "Octopus $Version already cached at $DestDir"
} else {
    Write-Info "Downloading Octopus $Version..."

    $TmpDir  = Join-Path ([System.IO.Path]::GetTempPath()) "octopus-install-$(Get-Random)"
    New-Item -ItemType Directory -Path $TmpDir | Out-Null

    try {
        $TarUrl  = "https://github.com/$GitHubRepo/archive/refs/tags/$Version.tar.gz"
        $TarFile = Join-Path $TmpDir "octopus.tar.gz"

        # Use curl if available (faster progress), otherwise Invoke-WebRequest
        $curlCmd = Get-Command curl -ErrorAction SilentlyContinue
        if ($curlCmd -and $curlCmd.Source -notlike "*system32*") {
            & curl -fL --progress-bar $TarUrl -o $TarFile
        } else {
            $ProgressPreference = "SilentlyContinue"
            Invoke-WebRequest -Uri $TarUrl -OutFile $TarFile
        }

        Write-Info "Extracting..."
        # tar is available natively on Windows 10+
        $ExtractDir = Join-Path $TmpDir "extract"
        New-Item -ItemType Directory -Path $ExtractDir | Out-Null
        tar -xzf $TarFile -C $ExtractDir

        # Find extracted directory (octopus-<version>/)
        $ExtractedDir = Get-ChildItem $ExtractDir -Directory | Where-Object { $_.Name -like "octopus-*" } | Select-Object -First 1
        if (-not $ExtractedDir) {
            Write-Err "Unexpected tarball structure."
            exit 1
        }

        New-Item -ItemType Directory -Path $CacheDir -Force | Out-Null
        if (Test-Path $DestDir) { Remove-Item $DestDir -Recurse -Force }
        Move-Item $ExtractedDir.FullName $DestDir

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
    checksum     = ""
    installed_at = $Timestamp
    release_path = $DestDir
} | ConvertTo-Json | Set-Content -Path $MetadataFile -Encoding UTF8

# ── Install shim ───────────────────────────────────────────────────────────────

New-Item -ItemType Directory -Path $BinDir -Force | Out-Null

# PowerShell shim
$ShimPs1 = Join-Path $BinDir "octopus.ps1"
@"
# Octopus CLI shim — delegates to bash (Git Bash or WSL)
`$CacheRoot  = if (`$env:OCTOPUS_CLI_CACHE_ROOT) { `$env:OCTOPUS_CLI_CACHE_ROOT } else { Join-Path `$HOME ".octopus-cli" }
`$MetaFile   = Join-Path `$CacheRoot "metadata.json"
`$CurrentDir = Join-Path `$CacheRoot "current"

function Find-Bash {
    `$bashOnPath = Get-Command bash -ErrorAction SilentlyContinue
    `$candidates = @(
        "C:\Program Files\Git\bin\bash.exe",
        "C:\Program Files (x86)\Git\bin\bash.exe",
        `$(if (`$bashOnPath) { `$bashOnPath.Source } else { `$null })
    )
    foreach (`$c in `$candidates) { if (`$c -and (Test-Path `$c)) { return `$c } }
    if (Get-Command wsl -ErrorAction SilentlyContinue) { return "wsl" }
    throw "No bash executor found. Install Git for Windows or enable WSL."
}

`$BashExe    = Find-Bash
`$RawPath    = Join-Path `$CurrentDir "bin\octopus"

if (`$BashExe -eq "wsl") {
    # WSL expects /mnt/c/... format
    `$ScriptPath = `$RawPath -replace '\\', '/'
    `$ScriptPath = `$ScriptPath -replace '^([A-Za-z]):', { "/mnt/" + `$_.Groups[1].Value.ToLower() }
    wsl bash `$ScriptPath @args
} else {
    # Git Bash expects /c/... format
    `$ScriptPath = `$RawPath -replace '\\', '/'
    `$ScriptPath = `$ScriptPath -replace '^([A-Za-z]):', '/$1'
    & `$BashExe `$ScriptPath @args
}
"@ | Set-Content -Path $ShimPs1 -Encoding UTF8

# CMD wrapper so `octopus` works in cmd.exe too
$ShimCmd = Join-Path $BinDir "octopus.cmd"
@"
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0octopus.ps1" %*
"@ | Set-Content -Path $ShimCmd -Encoding ASCII

Write-Success "Installed shim to $BinDir"

# ── PATH check ─────────────────────────────────────────────────────────────────

$UserPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
if ($UserPath -notlike "*$BinDir*") {
    Write-Warn "$BinDir is not in your PATH."
    $addPath = Read-Host "Add it to your user PATH? [Y/n]"
    if ($addPath -ne "n" -and $addPath -ne "N") {
        [System.Environment]::SetEnvironmentVariable("PATH", "$UserPath;$BinDir", "User")
        $env:PATH = "$env:PATH;$BinDir"
        Write-Success "Added $BinDir to PATH. Restart your shell to apply."
    }
}

# ── Welcome banner ─────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "        ___" -ForegroundColor Green
Write-Host "       /   \" -ForegroundColor Green
Write-Host "      | o o |" -ForegroundColor Green
Write-Host "       \_^_/" -ForegroundColor Green
Write-Host "      /||||||\" -ForegroundColor Green
Write-Host "     / |||||| \" -ForegroundColor Green
Write-Host "    /  ||||||  \" -ForegroundColor Green
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
