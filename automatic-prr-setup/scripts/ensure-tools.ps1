#Requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Fail([int] $Code, [string] $Message) {
    [Console]::Error.WriteLine($Message)
    exit $Code
}

function Test-Command([string] $Name) {
    return [bool] (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Add-UserPath([string] $Directory) {
    if (-not (Test-Path -LiteralPath $Directory -PathType Container)) {
        return
    }
    $current = [Environment]::GetEnvironmentVariable("Path", "User")
    if ([string]::IsNullOrEmpty($current)) {
        $current = ""
    }
    $parts = @($current -split ';' | Where-Object { $_ -ne "" })
    if ($parts -contains $Directory) {
        $env:Path = "$Directory;$env:Path"
        return
    }
    $updated = if ($current) { "$Directory;$current" } else { $Directory }
    [Environment]::SetEnvironmentVariable("Path", $updated, "User")
    $env:Path = "$Directory;$env:Path"
}

if (-not (Test-Command "git")) {
    Fail 1 "Missing prerequisite: git is not available on PATH. Install Git for Windows, then rerun."
}

if (-not (Test-Command "claude")) {
    Fail 1 @"
Missing prerequisite: claude is not available on PATH.
Install Claude Code from https://code.claude.com/docs/en/setup then rerun.
Do not silent-install Claude Code from this skill.
"@
}

if (-not (Test-Command "gh")) {
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) {
        Fail 2 "GitHub CLI (gh) is missing and winget is not available. Install from https://cli.github.com/ then rerun."
    }
    Write-Output "Installing GitHub CLI via winget..."
    & $winget.Source install --id GitHub.cli -e --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
        Fail 2 "winget failed to install GitHub.cli. Install from https://cli.github.com/ then rerun."
    }
    foreach ($candidate in @(
            "${env:ProgramFiles}\GitHub CLI",
            "${env:ProgramFiles(x86)}\GitHub CLI",
            "$env:LOCALAPPDATA\GitHub CLI"
        )) {
        Add-UserPath $candidate
    }
    if (-not (Test-Command "gh")) {
        Fail 2 "GitHub CLI installed but gh is still not on PATH. Open a new terminal and rerun."
    }
}

Write-Output "git: $((Get-Command git).Source)"
Write-Output "gh: $((Get-Command gh).Source)"
Write-Output "claude: $((Get-Command claude).Source)"
Write-Output "Tools OK."
