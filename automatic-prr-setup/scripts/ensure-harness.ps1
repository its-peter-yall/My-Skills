#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $Harness
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Fail([int] $Code, [string] $Message) {
    [Console]::Error.WriteLine($Message)
    exit $Code
}

function Add-UserPath([string] $Directory) {
    if (-not $Directory -or -not (Test-Path -LiteralPath $Directory -PathType Container)) {
        return
    }
    $current = [Environment]::GetEnvironmentVariable("Path", "User")
    if ([string]::IsNullOrEmpty($current)) { $current = "" }
    $parts = @($current -split ';' | Where-Object { $_ -ne "" })
    if ($parts -notcontains $Directory) {
        $updated = if ($current) { "$Directory;$current" } else { $Directory }
        [Environment]::SetEnvironmentVariable("Path", $updated, "User")
    }
    if (@($env:Path -split ';') -notcontains $Directory) {
        $env:Path = "$Directory;$env:Path"
    }
}

function Get-CursorCommand {
    $cursor = Get-Command cursor-agent -ErrorAction SilentlyContinue
    if ($cursor) { return $cursor }

    $candidate = Get-Command agent -ErrorAction SilentlyContinue
    if ($candidate) {
        $helpText = (& $candidate.Source --help 2>&1 | Out-String)
        if ($LASTEXITCODE -eq 0 -and $helpText -match 'Cursor Agent') {
            return $candidate
        }
    }
    return $null
}

function Get-HarnessCommand([string] $Name) {
    switch ($Name) {
        "claude" { return Get-Command claude -ErrorAction SilentlyContinue }
        "opencode" { return Get-Command opencode -ErrorAction SilentlyContinue }
        "cursor" { return Get-CursorCommand }
        "codex" { return Get-Command codex -ErrorAction SilentlyContinue }
    }
    return $null
}

function Invoke-RemotePowerShellInstaller([string] $Uri) {
    $content = Invoke-RestMethod -Uri $Uri
    if ([string]::IsNullOrWhiteSpace($content)) {
        Fail 1 "Installer returned no content: $Uri"
    }
    & ([scriptblock]::Create([string] $content))
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        Fail 1 "Installer failed with exit code ${LASTEXITCODE}: $Uri"
    }
}

$Harness = $Harness.Trim().ToLowerInvariant()
if ($Harness -notin @("claude", "opencode", "cursor", "codex")) {
    Fail 2 "Invalid review harness: $Harness"
}

$command = Get-HarnessCommand $Harness
$installed = $false
if (-not $command) {
    $installed = $true
    Write-Output "Installing $Harness CLI from its official distribution..."
    switch ($Harness) {
        "claude" {
            Invoke-RemotePowerShellInstaller "https://claude.ai/install.ps1"
        }
        "opencode" {
            $npm = Get-Command npm -ErrorAction SilentlyContinue
            if (-not $npm) {
                $winget = Get-Command winget -ErrorAction SilentlyContinue
                if (-not $winget) {
                    Fail 1 "OpenCode requires npm, and winget is unavailable to install Node.js LTS."
                }
                & $winget.Source install --id OpenJS.NodeJS.LTS -e --accept-package-agreements --accept-source-agreements
                if ($LASTEXITCODE -ne 0) {
                    Fail 1 "winget failed to install Node.js LTS for OpenCode."
                }
                Add-UserPath "$env:ProgramFiles\nodejs"
                $npm = Get-Command npm -ErrorAction SilentlyContinue
                if (-not $npm) {
                    Fail 1 "Node.js installed but npm is not on PATH. Open a new terminal and rerun."
                }
            }
            & $npm.Source install --global '@opencode/cli'
            if ($LASTEXITCODE -ne 0) {
                Fail 1 "npm failed to install @opencode/cli."
            }
        }
        "cursor" {
            Invoke-RemotePowerShellInstaller "https://cursor.com/install?win32=true"
        }
        "codex" {
            $previous = $env:CODEX_NON_INTERACTIVE
            try {
                $env:CODEX_NON_INTERACTIVE = "1"
                Invoke-RemotePowerShellInstaller "https://chatgpt.com/codex/install.ps1"
            }
            finally {
                $env:CODEX_NON_INTERACTIVE = $previous
            }
        }
    }

    foreach ($candidate in @(
            (Join-Path $env:USERPROFILE ".local\bin"),
            (Join-Path $env:LOCALAPPDATA "cursor-agent"),
            (Join-Path $env:LOCALAPPDATA "Programs\OpenAI\Codex\bin"),
            (Join-Path $env:APPDATA "npm"),
            (Join-Path $env:ProgramFiles "nodejs")
        )) {
        Add-UserPath $candidate
    }
    $command = Get-HarnessCommand $Harness
}

if (-not $command) {
    Fail 1 "$Harness installation completed, but its CLI is not available on PATH. Open a new terminal and rerun."
}

& $command.Source --version | Out-Host
if ($LASTEXITCODE -ne 0) {
    Fail 1 "$Harness CLI version check failed with exit code $LASTEXITCODE."
}

$commandDirectory = Split-Path -Parent $command.Source
if ($installed) {
    Add-UserPath $commandDirectory
}
Write-Output "HARNESS=$Harness"
Write-Output "HARNESS_COMMAND=$($command.Source)"
Write-Output "Harness CLI installed and available. Authentication was not checked."
