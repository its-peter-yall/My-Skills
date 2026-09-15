#Requires -Version 5.1
[CmdletBinding()]
param(
    [string] $RunnerLabel = "claude-review",
    [string] $RunnerRoot = $(Join-Path $env:USERPROFILE "actions-runners\automatic-prr"),
    [switch] $Replace
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Fail([int] $Code, [string] $Message) {
    [Console]::Error.WriteLine($Message)
    exit $Code
}

if ($RunnerLabel -notmatch '^[A-Za-z0-9_.-]+$') {
    Fail 2 "Invalid runner label: $RunnerLabel"
}

foreach ($name in @("git", "gh")) {
    if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
        Fail 1 "Missing prerequisite: $name is not available on PATH."
    }
}

gh auth status 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Fail 1 "gh is not authenticated. Run gh auth login, then rerun."
}

$repoJson = gh repo view --json nameWithOwner,url 2>$null
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($repoJson)) {
    Fail 1 "Could not resolve the GitHub repository. Run from a repo with origin set and gh auth."
}
$repo = $repoJson | ConvertFrom-Json
$nameWithOwner = $repo.nameWithOwner
$repoUrl = $repo.url
$runnerApi = "repos/$nameWithOwner/actions/runners"

function Get-MatchingOnlineRunner {
    $payload = gh api $runnerApi 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($payload)) {
        return $null
    }
    $parsed = $payload | ConvertFrom-Json
    if (-not $parsed.runners) {
        return $null
    }
    foreach ($runner in @($parsed.runners)) {
        $labelNames = @($runner.labels | ForEach-Object { $_.name })
        $online = ($runner.status -eq "online")
        if ($online -and ($labelNames -contains "self-hosted") -and ($labelNames -contains $RunnerLabel)) {
            return $runner
        }
    }
    return $null
}

$existing = Get-MatchingOnlineRunner
if ($existing) {
    Write-Output "Matching online runner already present: $($existing.name) (id $($existing.id))."
    Write-Output "Skipping registration."
    Write-Output "READY_RUNNER=$($existing.name)"
    Write-Output "READY_STATUS=online"
    exit 0
}

$runnerName = "$env:COMPUTERNAME-$RunnerLabel"
$configCmd = Join-Path $RunnerRoot "config.cmd"
$runCmd = Join-Path $RunnerRoot "run.cmd"
$runnerConfig = Join-Path $RunnerRoot ".runner"

if ((Test-Path -LiteralPath $runnerConfig -PathType Leaf) -and -not $Replace) {
    Write-Output "Runner directory is already configured at $RunnerRoot. Starting run.cmd..."
} elseif (-not (Test-Path -LiteralPath $configCmd -PathType Leaf) -or $Replace) {
    New-Item -ItemType Directory -Force -Path $RunnerRoot | Out-Null
    Write-Output "Downloading latest GitHub Actions win-x64 runner..."
    $release = gh api repos/actions/runner/releases/latest | ConvertFrom-Json
    $asset = $release.assets | Where-Object { $_.name -match '^actions-runner-win-x64-\d+\.\d+\.\d+\.zip$' } | Select-Object -First 1
    if (-not $asset) {
        Fail 1 "Could not find actions-runner-win-x64 zip on the latest runner release."
    }
    $zipPath = Join-Path $RunnerRoot $asset.name
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath
    if ($Replace -and (Test-Path -LiteralPath $runnerConfig) -and (Test-Path -LiteralPath $configCmd)) {
        $removeJson = gh api --method POST "$runnerApi/remove-token"
        if ($LASTEXITCODE -eq 0 -and $removeJson) {
            $removeToken = ($removeJson | ConvertFrom-Json).token
            try {
                Push-Location $RunnerRoot
                & .\config.cmd remove --unattended --token $removeToken | Out-Null
            } finally {
                $removeToken = $null
                Pop-Location
            }
        }
    }
    Expand-Archive -LiteralPath $zipPath -DestinationPath $RunnerRoot -Force
    Remove-Item -LiteralPath $zipPath -Force

    $tokenJson = gh api --method POST "$runnerApi/registration-token"
    if ($LASTEXITCODE -ne 0) {
        Fail 1 "Failed to create a runner registration token. Repository admin access is required."
    }
    $token = ($tokenJson | ConvertFrom-Json).token
    try {
        Push-Location $RunnerRoot
        $argList = @(
            "--unattended",
            "--url", $repoUrl,
            "--token", $token,
            "--name", $runnerName,
            "--labels", "self-hosted,$RunnerLabel",
            "--work", "_work"
        )
        if ($Replace) {
            $argList += "--replace"
        }
        & .\config.cmd @argList
        if ($LASTEXITCODE -ne 0) {
            Fail 1 "config.cmd failed. No registration token was written to the repository."
        }
    } finally {
        $token = $null
        Pop-Location
    }
}

$gitCmd = Split-Path -Parent (Get-Command git).Source
$ghCmd = Split-Path -Parent (Get-Command gh).Source
$claudeCmd = $null
$claude = Get-Command claude -ErrorAction SilentlyContinue
if ($claude) {
    $claudeCmd = Split-Path -Parent $claude.Source
}
$localBin = Join-Path $env:USERPROFILE ".local\bin"
$pathPrefix = @(
    $localBin,
    $claudeCmd,
    $ghCmd,
    $gitCmd,
    "C:\Program Files\Git\cmd",
    "C:\Program Files\GitHub CLI"
) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) } | Select-Object -Unique
$startCmd = Join-Path $RunnerRoot "start-runner.cmd"
$startLines = @(
    "@echo off",
    "set `"PATH=$($pathPrefix -join ';');%PATH%`"",
    "cd /d `"%~dp0`"",
    "run.cmd"
)
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllLines($startCmd, $startLines, $utf8)

$taskName = "GitHubActions-automatic-prr"
$action = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c `"$startCmd`"" -WorkingDirectory $RunnerRoot
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
Write-Output "Scheduled task $taskName registered for logon of $env:USERNAME."

Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$startCmd`"" -WorkingDirectory $RunnerRoot -WindowStyle Hidden
Write-Output "Started run.cmd in the background."

$online = $null
for ($i = 0; $i -lt 12; $i++) {
    Start-Sleep -Seconds 5
    $online = Get-MatchingOnlineRunner
    if ($online) {
        break
    }
}

if (-not $online) {
    Fail 1 "Runner did not become online. Keep this Windows user logged in and confirm git, gh, and claude are on PATH."
}

Write-Output "Runner online: $($online.name) (id $($online.id))."
Write-Output "READY_RUNNER=$($online.name)"
Write-Output "READY_STATUS=online"
