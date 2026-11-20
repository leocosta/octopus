# Octopus CLI shim — delegates to bash (Git Bash or WSL).
#
# Shipped in the release tree and copied to the bin dir by install.ps1 (mirrors
# install.sh copying bin/octopus — RM-019). It points at the version-independent
# `current` link, so it needs no per-version healing: `octopus update` swaps
# `current` and this delegator keeps working unchanged. The one exception is a
# change to the delegation contract itself (bash discovery / path translation) —
# `octopus update` is bash-driven and won't refresh these Windows shims, so such
# a change requires re-running install.ps1. (A future `doctor` drift-check could
# surface that automatically.)
#
# Keep Find-Bash in sync with Find-BashExecutable in install.ps1.
$CacheRoot  = if ($env:OCTOPUS_CLI_CACHE_ROOT) { $env:OCTOPUS_CLI_CACHE_ROOT } else { Join-Path $HOME ".octopus-cli" }
$CurrentDir = Join-Path $CacheRoot "current"

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

function Find-Bash {
    $gitBash = @(
        "C:\Program Files\Git\bin\bash.exe",
        "C:\Program Files (x86)\Git\bin\bash.exe",
        (Join-Path $env:LOCALAPPDATA "Programs\Git\bin\bash.exe")
    )
    foreach ($c in $gitBash) { if ($c -and (Test-Path $c)) { return $c } }
    # A bash.exe on PATH — except C:\Windows\System32\bash.exe and the
    # WindowsApps alias: those are WSL launchers, not Git Bash, and handing them
    # a Git-Bash-style /c/... path fails every command.
    foreach ($b in @(Get-Command bash.exe -All -ErrorAction SilentlyContinue)) {
        $src = $b.Source
        if ($src -like "$env:SystemRoot\*" -or $src -like "*\WindowsApps\*") { continue }
        return $src
    }
    if (Test-WslDistro) { return "wsl" }
    throw "No bash executor found. Install Git for Windows (https://git-scm.com/download/win) or a WSL distribution (wsl --install)."
}

# C:\x\y -> /mnt/c/x/y. -match/$Matches rather than a scriptblock -replace,
# which is PS 6+ only.
function ConvertTo-WslPath ($p) {
    $p = $p -replace '\\', '/'
    if ($p -match '^([A-Za-z]):(.*)$') { return "/mnt/" + $Matches[1].ToLower() + $Matches[2] }
    return $p
}

$BashExe = Find-Bash
$RawPath = Join-Path $CurrentDir "bin\octopus"

if ($BashExe -eq "wsl") {
    $ScriptPath = ConvertTo-WslPath $RawPath
    # The cache lives on the Windows side; without this, bin/octopus inside WSL
    # would look for it under the Linux $HOME and find nothing.
    $env:OCTOPUS_CLI_CACHE_ROOT = ConvertTo-WslPath $CacheRoot
    $env:WSLENV = (@($env:WSLENV, "OCTOPUS_CLI_CACHE_ROOT") | Where-Object { $_ }) -join ':'
    # --exec runs bash directly: no second pass through the default shell, so
    # arguments with spaces reach the CLI intact.
    & wsl.exe --exec bash $ScriptPath @args
} else {
    # Git Bash expects /c/...
    $ScriptPath = ($RawPath -replace '\\', '/') -replace '^([A-Za-z]):', '/$1'
    & $BashExe $ScriptPath @args
}
exit $LASTEXITCODE
