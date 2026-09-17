#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$skillRoot = Split-Path -Parent $PSScriptRoot
$baseScript = Join-Path $skillRoot "scripts\ensure-tools.ps1"
$harnessScript = Join-Path $skillRoot "scripts\ensure-harness.ps1"
$registerScript = Join-Path $skillRoot "scripts\register-runner.ps1"
$fixture = Join-Path ([System.IO.Path]::GetTempPath()) ("automatic-prr-tools-test-" + [guid]::NewGuid().ToString("N"))
$bin = Join-Path $fixture "bin"
$powershellExe = (Get-Command powershell).Source
$originalUserPath = [Environment]::GetEnvironmentVariable("Path", "User")

function Write-FakeCommand([string] $Name, [string] $Output) {
    $path = Join-Path $bin "$Name.cmd"
    [System.IO.File]::WriteAllText($path, "@echo off`r`necho $Output`r`nexit /b 0`r`n")
}

function Invoke-WithFakePath([string] $Script, [string[]] $Arguments) {
    $oldPath = $env:Path
    $oldPreference = $ErrorActionPreference
    try {
        $env:Path = $bin
        $ErrorActionPreference = "Continue"
        $output = & $powershellExe -NoProfile -ExecutionPolicy Bypass -File $Script @Arguments 2>&1
        return [pscustomobject]@{ Code = $LASTEXITCODE; Output = ($output | Out-String) }
    }
    finally {
        $env:Path = $oldPath
        $ErrorActionPreference = $oldPreference
    }
}

try {
    New-Item -ItemType Directory -Path $bin -Force | Out-Null
    Write-FakeCommand "git" "git version test"
    Write-FakeCommand "gh" "gh version test"
    Write-FakeCommand "claude" "1.0 Claude Code"
    Write-FakeCommand "opencode" "opencode v2.0.0"
    Write-FakeCommand "cursor-agent" "Cursor Agent 1.0"
    Write-FakeCommand "codex" "codex-cli 1.0"
    [System.IO.File]::WriteAllText((Join-Path $bin "pwsh.exe"), "fake-pwsh-not-empty")

    $base = Invoke-WithFakePath -Script $baseScript -Arguments @()
    if ($base.Code -ne 0) { throw "base tool setup failed without real Claude: $($base.Output)" }
    if ($base.Output.IndexOf("claude") -ge 0) { throw "base tool setup still depends on Claude" }
    if ($base.Output.IndexOf("git:") -lt 0) { throw "base tool setup did not print git source" }
    if ($base.Output.IndexOf("gh:") -lt 0) { throw "base tool setup did not print gh source" }
    if ($base.Output.IndexOf("pwsh:") -lt 0) { throw "base tool setup did not print pwsh source" }
    [Environment]::SetEnvironmentVariable("Path", $originalUserPath, "User")

    foreach ($harness in @("claude", "opencode", "cursor", "codex")) {
        $result = Invoke-WithFakePath -Script $harnessScript -Arguments @("-Harness", $harness)
        if ($result.Code -ne 0) { throw "harness setup failed for ${harness}: $($result.Output)" }
        if ($result.Output.IndexOf("HARNESS=$harness") -lt 0) {
            throw "harness setup did not report normalized harness $harness"
        }
        if ($result.Output.IndexOf("HARNESS_COMMAND=") -lt 0) {
            throw "harness setup did not report its resolved command"
        }
    }
    if ([Environment]::GetEnvironmentVariable("Path", "User") -ne $originalUserPath) {
        throw "checking preinstalled harnesses must not modify the user PATH"
    }

    $invalid = Invoke-WithFakePath -Script $harnessScript -Arguments @("-Harness", "unknown")
    if ($invalid.Code -ne 2) { throw "Expected invalid harness exit 2, got $($invalid.Code)" }

    $helperScript = Join-Path $skillRoot "scripts\runner-helpers.ps1"
    $registerText = [System.IO.File]::ReadAllText($registerScript) + "`n" + [System.IO.File]::ReadAllText($helperScript)
    foreach ($needle in @(
            '[string] $RunnerLabel = "automatic-prr"',
            '[string] $Harness',
            'actions/runners/$($existing.id)/labels',
            'HARNESS_COMMAND',
            '[Net.ServicePointManager]::SecurityProtocol',
            'curl.exe',
            'gh-proxy.com',
            'asset.digest',
            'ExecutionTimeLimit',
            'Listening for Jobs',
            'TaskAgentSessionConflictException',
            'Microsoft\WindowsApps'
        )) {
        if ($registerText.IndexOf($needle) -lt 0) {
            throw "register-runner.ps1 missing harness-neutral behavior: $needle"
        }
    }
    if ($registerText.IndexOf('$claudeCmd') -ge 0) {
        throw "register-runner.ps1 still hard-codes the Claude executable path"
    }
    if ($registerText.IndexOf('Invoke-WebRequest -Uri $asset.browser_download_url') -ge 0) {
        throw "register-runner.ps1 still downloads the runner zip with Invoke-WebRequest"
    }
    if ($registerText.IndexOf('Stop-Process -Force') -ge 0) {
        throw "register-runner.ps1 must not force-kill Runner.Listener"
    }
    if ($registerText.IndexOf('elseif (-not (Test-Path -LiteralPath $configCmd -PathType Leaf) -or $Replace)') -ge 0) {
        throw "register-runner.ps1 still skips config when config.cmd exists without .runner"
    }

    $toolsText = [System.IO.File]::ReadAllText($baseScript)
    foreach ($needle in @(
            'Microsoft.PowerShell',
            'Resolve-RealPwshDirectory',
            'Add-UserPath',
            'pwsh:'
        )) {
        if ($toolsText.IndexOf($needle) -lt 0) {
            throw "ensure-tools.ps1 missing pwsh PATH behavior: $needle"
        }
    }

    Write-Output "tool tests passed"
}
finally {
    [Environment]::SetEnvironmentVariable("Path", $originalUserPath, "User")
    Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue
}
