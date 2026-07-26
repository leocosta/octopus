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
$CacheRoot  = if ($env:OCTOPUS_CLI_CACHE_ROOT) { $env:OCTOPUS_CLI_CACHE_ROOT } else { Join-Path $HOME ".octopus-cli" }
$CurrentDir = Join-Path $CacheRoot "current"

function Find-Bash {
    $bashOnPath = Get-Command bash -ErrorAction SilentlyContinue
    $candidates = @(
        "C:\Program Files\Git\bin\bash.exe",
        "C:\Program Files (x86)\Git\bin\bash.exe",
        $(if ($bashOnPath) { $bashOnPath.Source } else { $null })
    )
    foreach ($c in $candidates) { if ($c -and (Test-Path $c)) { return $c } }
    if (Get-Command wsl -ErrorAction SilentlyContinue) { return "wsl" }
    throw "No bash executor found. Install Git for Windows or enable WSL."
}

$BashExe = Find-Bash
$RawPath = Join-Path $CurrentDir "bin\octopus"

# Normalize backslashes once; each branch then applies its own drive-letter form.
# The translation avoids a scriptblock in -replace so it works on Windows
# PowerShell 5.1 (scriptblock substitution is PS 6+ only).
$ScriptPath = $RawPath -replace '\\', '/'
if ($BashExe -eq "wsl") {
    # WSL expects /mnt/c/...
    if ($ScriptPath -match '^([A-Za-z]):(.*)$') {
        $ScriptPath = "/mnt/" + $Matches[1].ToLower() + $Matches[2]
    }
    wsl bash $ScriptPath @args
} else {
    # Git Bash expects /c/...
    $ScriptPath = $ScriptPath -replace '^([A-Za-z]):', '/$1'
    & $BashExe $ScriptPath @args
}
