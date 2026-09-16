#Requires -Version 5.1
[CmdletBinding()]
param(
    [string] $RunnerLabel = "automatic-prr",
    [string] $Harness = "claude",
    [AllowEmptyString()][string] $Model = "",
    [switch] $Force
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

$Harness = $Harness.Trim().ToLowerInvariant()
if ($Harness -notin @("claude", "opencode", "cursor", "codex")) {
    Fail 2 "Invalid review harness: $Harness"
}

$Model = $Model.Trim()
if ($Model.Length -gt 256 -or $Model.IndexOf("`r") -ge 0 -or $Model.IndexOf("`n") -ge 0) {
    Fail 2 "Invalid review model: use a single line of at most 256 characters."
}
foreach ($character in $Model.ToCharArray()) {
    if ([char]::IsControl($character)) {
        Fail 2 "Invalid review model: control characters are not allowed."
    }
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Fail 1 "Missing prerequisite: git is not available on PATH."
}

$repoRoot = (git rev-parse --show-toplevel 2>$null)
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($repoRoot)) {
    Fail 1 "Run this skill from inside the target Git repository."
}
$repoRoot = $repoRoot.Trim()

$branchName = (git -C $repoRoot symbolic-ref --quiet --short HEAD 2>$null)
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($branchName)) {
    Fail 1 "Detached HEAD detected. Switch to the setup branch first."
}
$branchName = $branchName.Trim()

$skillDir = if ($env:AUTOMATIC_PRR_SKILL_DIR) {
    $env:AUTOMATIC_PRR_SKILL_DIR
} elseif ($env:CLAUDE_SKILL_DIR) {
    $env:CLAUDE_SKILL_DIR
} else {
    Split-Path -Parent $PSScriptRoot
}
$workflowSource = Join-Path $skillDir "templates\workflows\automatic-prr.yml"
$promptSource = Join-Path $skillDir "templates\prompts\pr-review.md"
$workflowTarget = Join-Path $repoRoot ".github\workflows\automatic-prr.yml"
$promptTarget = Join-Path $repoRoot ".github\automatic-prr\pr-review.md"
$legacyPromptTarget = Join-Path $repoRoot ".github\claude\prompts\pr-review.md"

foreach ($sourcePath in @($workflowSource, $promptSource)) {
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        Fail 1 "Skill asset is missing: $sourcePath"
    }
}

$yamlModel = $Model.Replace('\', '\\').Replace('"', '\"')
$utf8 = New-Object System.Text.UTF8Encoding $false
$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("automatic-prr-setup-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tmpDir | Out-Null
try {
    $workflowRendered = Join-Path $tmpDir "automatic-prr.yml"
    $promptRendered = Join-Path $tmpDir "pr-review.md"
    $rendered = [System.IO.File]::ReadAllText($workflowSource)
    $rendered = $rendered.Replace("__RUNNER_LABEL__", $RunnerLabel)
    $rendered = $rendered.Replace("__REVIEW_HARNESS__", $Harness)
    $rendered = $rendered.Replace("__REVIEW_MODEL__", $yamlModel)
    [System.IO.File]::WriteAllText($workflowRendered, $rendered, $utf8)
    Copy-Item -LiteralPath $promptSource -Destination $promptRendered -Force

    $conflicts = @()
    if ((Test-Path -LiteralPath $workflowTarget -PathType Leaf) -and
        ((Get-FileHash -LiteralPath $workflowRendered -Algorithm SHA256).Hash -ne
         (Get-FileHash -LiteralPath $workflowTarget -Algorithm SHA256).Hash)) {
        $conflicts += $workflowTarget
    }
    if ((Test-Path -LiteralPath $promptTarget -PathType Leaf) -and
        ((Get-FileHash -LiteralPath $promptRendered -Algorithm SHA256).Hash -ne
         (Get-FileHash -LiteralPath $promptTarget -Algorithm SHA256).Hash)) {
        $conflicts += $promptTarget
    }

    if ($conflicts.Count -gt 0 -and -not $Force) {
        [Console]::Error.WriteLine("Existing managed file(s) differ:")
        foreach ($path in $conflicts) {
            [Console]::Error.WriteLine("  $path")
        }
        [Console]::Error.WriteLine("Inspect the differences and rerun with -Force only after approval.")
        exit 3
    }

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $workflowTarget) | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $promptTarget) | Out-Null
    Copy-Item -LiteralPath $workflowRendered -Destination $workflowTarget -Force
    Copy-Item -LiteralPath $promptRendered -Destination $promptTarget -Force

    if ((Test-Path -LiteralPath $legacyPromptTarget -PathType Leaf) -and
        ((Get-FileHash -LiteralPath $legacyPromptTarget -Algorithm SHA256).Hash -eq
         (Get-FileHash -LiteralPath $promptRendered -Algorithm SHA256).Hash)) {
        Remove-Item -LiteralPath $legacyPromptTarget -Force
        Write-Output "Removed exact managed legacy prompt: $legacyPromptTarget"
    } elseif (Test-Path -LiteralPath $legacyPromptTarget -PathType Leaf) {
        Write-Output "Preserved modified legacy prompt: $legacyPromptTarget"
    }
}
finally {
    Remove-Item -LiteralPath $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
}

$modelDisplay = if ($Model) { $Model } else { "default" }
Write-Output "Installed automatic PR review on branch $branchName."
Write-Output "Runner label: $RunnerLabel"
Write-Output "Review harness: $Harness"
Write-Output "Review model: $modelDisplay"
Write-Output "Workflow: $workflowTarget"
Write-Output "Prompt:   $promptTarget"
Write-Output "No files were committed or pushed."
exit 0
