#Requires -Version 5.1
[CmdletBinding()]
param(
    [string] $RunnerLabel = "automatic-prr",
    [string] $Harness = "claude",
    [string] $RunnerRoot = $(Join-Path $env:USERPROFILE "actions-runners\automatic-prr"),
    [switch] $Replace
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "runner-helpers.ps1")

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
}
catch {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

function Fail([int] $Code, [string] $Message) {
    [Console]::Error.WriteLine($Message)
    exit $Code
}

if ($RunnerLabel -notmatch '^[A-Za-z0-9_.-]+$') {
    Fail 2 "Invalid runner label: $RunnerLabel"
}

$Harness = $Harness.Trim().ToLowerInvariant()
if ($Harness -notin @("claude", "opencode", "cursor", "codex")) {
    Fail 2 "Invalid review harness: $Harness"
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

function Get-HarnessCommand {
    switch ($Harness) {
        "claude" { return Get-Command claude -ErrorAction SilentlyContinue }
        "opencode" { return Get-Command opencode -ErrorAction SilentlyContinue }
        "codex" { return Get-Command codex -ErrorAction SilentlyContinue }
        "cursor" {
            $cursor = Get-Command cursor-agent -ErrorAction SilentlyContinue
            if ($cursor) { return $cursor }
            $candidate = Get-Command agent -ErrorAction SilentlyContinue
            if ($candidate) {
                $helpText = (& $candidate.Source --help 2>&1 | Out-String)
                if ($LASTEXITCODE -eq 0 -and $helpText -match 'Cursor Agent') { return $candidate }
            }
            return $null
        }
    }
}

function Get-CurlExe {
    $systemCurl = Join-Path $env:SystemRoot "System32\curl.exe"
    if (Test-Path -LiteralPath $systemCurl -PathType Leaf) {
        return $systemCurl
    }
    $command = Get-Command curl.exe -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }
    Fail 1 "curl.exe is required to download the GitHub Actions runner."
}

function Invoke-CurlGetFile {
    param(
        [string] $Uri,
        [string] $OutFile,
        [switch] $IPv4
    )
    $curl = Get-CurlExe
    $argList = Get-CurlDownloadArgumentList -Uri $Uri -OutFile $OutFile -IPv4:$IPv4
    $previous = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $output = & $curl @argList 2>&1 | Out-String
        return [pscustomobject]@{ Code = $LASTEXITCODE; Output = $output }
    }
    finally {
        $ErrorActionPreference = $previous
    }
}

function Save-VerifiedRunnerZip {
    param(
        [string] $OfficialUrl,
        [string] $ProxyUrl,
        [string] $ZipPath,
        [string] $ExpectedDigest
    )
    $expected = ConvertTo-UnprefixedSha256 $ExpectedDigest
    if ([string]::IsNullOrWhiteSpace($expected)) {
        Fail 1 "Runner release asset is missing a sha256 digest from GitHub. Refusing to keep an unverified zip at $ZipPath."
    }
    if (Test-Path -LiteralPath $ZipPath) {
        Remove-Item -LiteralPath $ZipPath -Force
    }

    $attempts = @(
        [pscustomobject]@{ Uri = $OfficialUrl; IPv4 = $false; Label = "official CDN" },
        [pscustomobject]@{ Uri = $OfficialUrl; IPv4 = $true; Label = "official CDN IPv4" },
        [pscustomobject]@{ Uri = $ProxyUrl; IPv4 = $false; Label = "hash-checked gh-proxy fallback" }
    )

    $lastError = ""
    foreach ($attempt in $attempts) {
        Write-Output "Downloading GitHub Actions runner ($($attempt.Label))..."
        try {
            $result = Invoke-CurlGetFile -Uri $attempt.Uri -OutFile $ZipPath -IPv4:$attempt.IPv4
            if ($result.Code -ne 0 -or -not (Test-Path -LiteralPath $ZipPath -PathType Leaf)) {
                $lastError = "curl.exe exit $($result.Code) for $($attempt.Label): $($result.Output)"
                if (Test-Path -LiteralPath $ZipPath) {
                    Remove-Item -LiteralPath $ZipPath -Force
                }
                if (Test-TlsOrConnectionResetMessage $lastError) {
                    Write-Output "Official download hit a TLS/connection reset; trying the next method."
                }
                else {
                    Write-Output $lastError
                }
                continue
            }

            $actual = (Get-FileHash -LiteralPath $ZipPath -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($actual -ne $expected) {
                Remove-Item -LiteralPath $ZipPath -Force
                $lastError = "SHA256 mismatch for $($attempt.Label). Expected $expected, got $actual. Deleted zip."
                Write-Output $lastError
                continue
            }

            Write-Output "Verified runner zip SHA256 $actual."
            return
        }
        catch {
            $lastError = $_.Exception.Message
            if (Test-Path -LiteralPath $ZipPath) {
                Remove-Item -LiteralPath $ZipPath -Force
            }
            if (Test-TlsOrConnectionResetMessage $lastError) {
                Write-Output "Download error ($($attempt.Label)): $lastError"
            }
            else {
                Write-Output "Download error ($($attempt.Label)): $lastError"
            }
        }
    }

    Fail 1 @"
Could not download the GitHub Actions runner. The official CDN may be blocked (TLS connection reset on release-assets.githubusercontent.com).
Expected SHA256: $expected
Destination: $ZipPath
Last error: $lastError
"@
}

function Get-RunnerListenerProcesses([string] $Root) {
    $resolved = $Root
    try {
        $resolved = [System.IO.Path]::GetFullPath($Root)
    }
    catch {
        $resolved = $Root
    }
    $found = @()
    foreach ($proc in @(Get-Process -Name "Runner.Listener" -ErrorAction SilentlyContinue)) {
        $path = $null
        try {
            $path = $proc.Path
        }
        catch {
            $path = $null
        }
        if ($path -and $path.StartsWith($resolved, [System.StringComparison]::OrdinalIgnoreCase)) {
            $found += $proc
        }
    }
    return @($found)
}

function Get-LatestRunnerLogPath([string] $Root) {
    $diag = Join-Path $Root "_diag"
    if (-not (Test-Path -LiteralPath $diag -PathType Container)) {
        return $null
    }
    $log = Get-ChildItem -LiteralPath $diag -File -Filter "Runner_*.log" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1
    if ($log) {
        return $log.FullName
    }
    return $null
}

function Get-LocalRunnerListenState([string] $Root) {
    $result = [pscustomobject]@{
        Listening        = $false
        SessionConflict  = $false
        HasLog           = $false
        ListenerRunning  = $false
        LogPath          = $null
    }
    $result.ListenerRunning = (@(Get-RunnerListenerProcesses $Root).Count -gt 0)
    $logPath = Get-LatestRunnerLogPath $Root
    if (-not $logPath) {
        return $result
    }
    $result.HasLog = $true
    $result.LogPath = $logPath
    $text = ""
    try {
        $text = [System.IO.File]::ReadAllText($logPath)
    }
    catch {
        $text = ""
    }
    $listenIdx = $text.LastIndexOf("Listening for Jobs")
    $conflictIdx = $text.LastIndexOf("TaskAgentSessionConflictException")
    $result.Listening = ($listenIdx -ge 0 -and $listenIdx -gt $conflictIdx)
    $result.SessionConflict = ($conflictIdx -ge 0 -and $conflictIdx -gt $listenIdx)
    return $result
}

function Test-LocalRunnerAcceptingWork([string] $Root) {
    $state = Get-LocalRunnerListenState $Root
    if ($state.SessionConflict) {
        return $false
    }
    if ($state.Listening) {
        return $true
    }
    if ($state.ListenerRunning) {
        return $true
    }
    return $false
}

function Stop-RunnerListenerGracefully([string] $Root) {
    foreach ($proc in @(Get-RunnerListenerProcesses $Root)) {
        Write-Output "Stopping Runner.Listener PID $($proc.Id) gracefully (no force kill)..."
        try {
            & taskkill.exe /PID $proc.Id 2>$null | Out-Null
        }
        catch {
        }
        try {
            $null = $proc.WaitForExit(20000)
        }
        catch {
        }
        $still = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
        if ($still) {
            Write-Output "Runner.Listener PID $($proc.Id) is still running; leaving it (will not force-kill)."
        }
    }
}

$harnessCommand = Get-HarnessCommand
if (-not $harnessCommand) {
    Fail 1 "$Harness CLI is not available on PATH. Run ensure-harness.ps1 first."
}
$harnessCommandDirectory = Split-Path -Parent $harnessCommand.Source

$existing = Get-MatchingOnlineRunner
if (-not $existing -and (Test-Path -LiteralPath (Join-Path $RunnerRoot ".runner") -PathType Leaf)) {
    try {
        $configured = Get-Content -Raw -LiteralPath (Join-Path $RunnerRoot ".runner") | ConvertFrom-Json
        $allRunners = (gh api $runnerApi | ConvertFrom-Json).runners
        $existing = @($allRunners | Where-Object { $_.name -eq $configured.agentName -and $_.status -eq "online" }) | Select-Object -First 1
        if ($existing) {
            $labelNames = @($existing.labels | ForEach-Object { $_.name })
            if ($labelNames -notcontains $RunnerLabel) {
                @{ labels = @($RunnerLabel) } | ConvertTo-Json -Compress |
                    gh api --method POST "repos/$nameWithOwner/actions/runners/$($existing.id)/labels" --input - | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    Fail 1 "Could not add runner label $RunnerLabel to $($existing.name)."
                }
                $existing = Get-MatchingOnlineRunner
                Write-Output "Added label $RunnerLabel to configured runner."
            }
        }
    }
    catch {
        Fail 1 "Could not inspect or relabel the configured runner: $($_.Exception.Message)"
    }
}
if ($existing) {
    $hasLocalConfig = Test-Path -LiteralPath (Join-Path $RunnerRoot ".runner") -PathType Leaf
    $localReady = Test-LocalRunnerAcceptingWork $RunnerRoot
    if (-not $hasLocalConfig -or $localReady) {
        $state = Get-LocalRunnerListenState $RunnerRoot
        if ($state.SessionConflict) {
            Write-Output "GitHub lists $($existing.name) as online, but the local listener is in a session-conflict loop. Not treating the stale API row as READY."
        }
        else {
            Write-Output "Matching online runner already present: $($existing.name) (id $($existing.id))."
            Write-Output "Skipping registration."
            Write-Output "READY_RUNNER=$($existing.name)"
            Write-Output "READY_STATUS=online"
            Write-Output "HARNESS_COMMAND=$($harnessCommand.Source)"
            exit 0
        }
    }
    else {
        Write-Output "GitHub lists a matching runner as online, but the local listener is not accepting work. Starting it."
    }
}

$runnerName = "$env:COMPUTERNAME-$RunnerLabel"
$configCmd = Join-Path $RunnerRoot "config.cmd"
$runCmd = Join-Path $RunnerRoot "run.cmd"
$runnerConfig = Join-Path $RunnerRoot ".runner"
$hasConfigCmd = Test-Path -LiteralPath $configCmd -PathType Leaf
$hasRunnerFile = Test-Path -LiteralPath $runnerConfig -PathType Leaf

if ($hasRunnerFile -and -not $Replace) {
    Write-Output "Runner directory is already configured at $RunnerRoot. Starting run.cmd..."
}
else {
    if (-not $hasConfigCmd -or $Replace) {
        New-Item -ItemType Directory -Force -Path $RunnerRoot | Out-Null
        Write-Output "Downloading latest GitHub Actions win-x64 runner..."
        $release = gh api repos/actions/runner/releases/latest | ConvertFrom-Json
        if ($LASTEXITCODE -ne 0 -or -not $release) {
            Fail 1 "Could not read repos/actions/runner/releases/latest."
        }
        $asset = $release.assets | Where-Object { $_.name -match '^actions-runner-win-x64-\d+\.\d+\.\d+\.zip$' } | Select-Object -First 1
        if (-not $asset) {
            Fail 1 "Could not find actions-runner-win-x64 zip on the latest runner release."
        }
        $expectedDigest = ""
        if ($asset.PSObject.Properties.Name -contains "digest") {
            $expectedDigest = [string] $asset.digest
        }
        $zipPath = Join-Path $RunnerRoot $asset.name
        $proxyUrl = Get-GitHubRunnerProxyUrl -Tag $release.tag_name -AssetName $asset.name
        Save-VerifiedRunnerZip -OfficialUrl $asset.browser_download_url -ProxyUrl $proxyUrl -ZipPath $zipPath -ExpectedDigest $expectedDigest

        if ($Replace -and (Test-Path -LiteralPath $runnerConfig) -and (Test-Path -LiteralPath $configCmd)) {
            $removeJson = gh api --method POST "$runnerApi/remove-token"
            if ($LASTEXITCODE -eq 0 -and $removeJson) {
                $removeToken = ($removeJson | ConvertFrom-Json).token
                try {
                    Push-Location $RunnerRoot
                    & .\config.cmd remove --unattended --token $removeToken | Out-Null
                }
                finally {
                    $removeToken = $null
                    Pop-Location
                }
            }
        }
        Expand-Archive -LiteralPath $zipPath -DestinationPath $RunnerRoot -Force
        Remove-Item -LiteralPath $zipPath -Force
        $hasConfigCmd = Test-Path -LiteralPath $configCmd -PathType Leaf
    }

    if (-not $hasConfigCmd) {
        Fail 1 "config.cmd is missing at $RunnerRoot after download."
    }

    if ($Replace -or -not (Test-Path -LiteralPath $runnerConfig -PathType Leaf)) {
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
        }
        finally {
            $token = $null
            Pop-Location
        }
    }
}

$gitCmd = Split-Path -Parent (Get-Command git).Source
$ghCmd = Split-Path -Parent (Get-Command gh).Source
$localBin = Join-Path $env:USERPROFILE ".local\bin"
$pwshDirectory = Resolve-RealPwshDirectory
$windowsAppsPwsh = $null
if (-not $pwshDirectory) {
    $windowsAppsPwsh = Test-WindowsAppsPwshDirectory
}

$pathPrefix = @(
    $localBin,
    $harnessCommandDirectory,
    $pwshDirectory,
    $ghCmd,
    $gitCmd,
    "C:\Program Files\Git\cmd",
    "C:\Program Files\GitHub CLI",
    $windowsAppsPwsh
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
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit ([TimeSpan]::Zero)
$settings.ExecutionTimeLimit = [TimeSpan]::Zero
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
Write-Output "Scheduled task $taskName registered for logon of $env:USERNAME."

$listenState = Get-LocalRunnerListenState $RunnerRoot
if ($listenState.Listening -and $listenState.ListenerRunning -and -not $listenState.SessionConflict) {
    Write-Output "Local runner is already listening for jobs."
}
else {
    if ($listenState.ListenerRunning -and ($listenState.SessionConflict -or -not $listenState.Listening)) {
        Stop-RunnerListenerGracefully $RunnerRoot
    }
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$startCmd`"" -WorkingDirectory $RunnerRoot -WindowStyle Hidden
    Write-Output "Started run.cmd in the background."
}

$online = $null
for ($i = 0; $i -lt 24; $i++) {
    Start-Sleep -Seconds 5
    $online = Get-MatchingOnlineRunner
    $listenState = Get-LocalRunnerListenState $RunnerRoot
    if ($listenState.SessionConflict) {
        Write-Output "Runner diag log shows TaskAgentSessionConflictException; waiting instead of treating a stale online API row as READY..."
        continue
    }
    if ($online -and $listenState.Listening) {
        break
    }
    if ($online -and $listenState.ListenerRunning) {
        break
    }
}

$listenState = Get-LocalRunnerListenState $RunnerRoot
if ($listenState.SessionConflict) {
    Fail 1 "Runner API may show online, but the local listener is stuck in TaskAgentSessionConflictException. Do not treat a stale online row as READY. Keep this user logged in and rerun; do not force-kill Runner.Listener."
}
if (-not $online) {
    Fail 1 "Runner did not become online. Keep this Windows user logged in and confirm git, gh, pwsh, and $Harness are on PATH."
}
if (-not $listenState.Listening -and -not $listenState.ListenerRunning) {
    Fail 1 "Runner API is online but the local listener is not accepting work (no Listening for Jobs). Not READY."
}

Write-Output "Runner online: $($online.name) (id $($online.id))."
Write-Output "READY_RUNNER=$($online.name)"
Write-Output "READY_STATUS=online"
Write-Output "HARNESS_COMMAND=$($harnessCommand.Source)"
