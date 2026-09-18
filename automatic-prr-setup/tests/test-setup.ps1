#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$skillRoot = Split-Path -Parent $PSScriptRoot
$setupScript = Join-Path $skillRoot "scripts\setup.ps1"
$fixture = Join-Path ([System.IO.Path]::GetTempPath()) ("automatic-prr-test-" + [guid]::NewGuid().ToString("N"))

function New-TestRepo([string] $Name) {
    $repo = Join-Path $fixture $Name
    New-Item -ItemType Directory -Path $repo | Out-Null
    git -C $repo init -q
    git -C $repo config user.name test
    git -C $repo config user.email test@example.com
    git -C $repo switch -q -c feature/setup
    return $repo
}

function Invoke-Setup(
    [string] $Repo,
    [string] $Harness,
    [AllowEmptyString()][string] $Model,
    [switch] $Force
) {
    $arguments = @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $setupScript,
        "-RunnerLabel", "review-box", "-Harness", $Harness
    )
    if ($Model) { $arguments += @("-Model", $Model) }
    if ($Force) { $arguments += "-Force" }
    Push-Location $Repo
    try {
        $null = & powershell @arguments
        $exitCode = $LASTEXITCODE
        return $exitCode
    }
    finally {
        Pop-Location
    }
}

function Assert-Contains([string] $Text, [string] $Needle) {
    if ($Text.IndexOf($Needle) -lt 0) {
        throw "Expected text missing: $Needle"
    }
}

function Assert-NotContains([string] $Text, [string] $Needle) {
    if ($Text.IndexOf($Needle) -ge 0) {
        throw "Unexpected text present: $Needle"
    }
}

try {
    New-Item -ItemType Directory -Path $fixture | Out-Null
    $env:AUTOMATIC_PRR_SKILL_DIR = $skillRoot

    $expectedHarnessMarkers = @{
        claude   = "& claude @arguments"
        opencode = "& opencode @arguments"
        cursor   = '& $cursorCommand.Source @arguments'
        codex    = "& codex @arguments"
    }

    foreach ($harness in @("claude", "opencode", "cursor", "codex")) {
        $repo = New-TestRepo "repo-$harness"
        $model = if ($harness -eq "opencode") { "openai/gpt-5.2#high" } else { "model-1.2:test[effort=high,fast=false]" }
        $code = Invoke-Setup -Repo $repo -Harness $harness -Model $model
        if ($code -ne 0) { throw "setup.ps1 failed for $harness with exit $code" }

        $workflow = Join-Path $repo ".github\workflows\automatic-prr.yml"
        $prompt = Join-Path $repo ".github\automatic-prr\pr-review.md"
        if (-not (Test-Path -LiteralPath $workflow)) { throw "workflow missing for $harness" }
        if (-not (Test-Path -LiteralPath $prompt)) { throw "generic prompt missing for $harness" }

        $workflowText = [System.IO.File]::ReadAllText($workflow)
        $promptText = [System.IO.File]::ReadAllText($prompt)
        foreach ($needle in @(
                "name: Automatic PR Review",
                "runs-on: [self-hosted, review-box]",
                "github.event.pull_request.head.sha",
                "actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1",
                "persist-credentials: false",
                "REVIEW_HARNESS: `"$harness`"",
                "REVIEW_MODEL: `"$model`"",
                ".github/automatic-prr/pr-review.md",
                "contents: write",
                "pull-requests: write",
                "Land reports and comment",
                "chore(review): reports for",
                "slack-report.md",
                $expectedHarnessMarkers[$harness]
            )) {
            Assert-Contains $workflowText $needle
        }
        Assert-NotContains $workflowText "contents: read"
        Assert-NotContains $workflowText "issues: write"
        Assert-NotContains $workflowText "gh auth status"
        Assert-Contains $promptText "pr-code-review"
        Assert-Contains $promptText "reviews/{{PR_NUMBER}}/"
        Assert-Contains $promptText "slack-report.md"
        Assert-NotContains $promptText "post the final findings to the pull request"
        Assert-NotContains $promptText "/code-review --comment"
        Assert-NotContains $promptText "Do not edit files"
        Assert-Contains $promptText "{{PR_NUMBER}}"
    }

    $blankRepo = New-TestRepo "repo-default-model"
    $code = Invoke-Setup -Repo $blankRepo -Harness "codex" -Model ""
    if ($code -ne 0) { throw "blank model install failed with exit $code" }
    $blankWorkflow = [System.IO.File]::ReadAllText((Join-Path $blankRepo ".github\workflows\automatic-prr.yml"))
    Assert-Contains $blankWorkflow 'REVIEW_MODEL: ""'
    Assert-Contains $blankWorkflow '$hasModel = -not [string]::IsNullOrWhiteSpace($env:REVIEW_MODEL)'

    $escapedRepo = New-TestRepo "repo-escaped-model"
    $escapedModel = 'provider/model\path&x|y'
    $code = Invoke-Setup -Repo $escapedRepo -Harness "cursor" -Model $escapedModel
    if ($code -ne 0) { throw "escaped model install failed with exit $code" }
    $escapedWorkflow = [System.IO.File]::ReadAllText((Join-Path $escapedRepo ".github\workflows\automatic-prr.yml"))
    Assert-Contains $escapedWorkflow 'REVIEW_MODEL: "provider/model\\path&x|y"'

    $legacyRepo = New-TestRepo "repo-legacy"
    $legacyPrompt = Join-Path $legacyRepo ".github\claude\prompts\pr-review.md"
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $legacyPrompt) | Out-Null
    Copy-Item -LiteralPath (Join-Path $skillRoot "templates\prompts\pr-review.md") -Destination $legacyPrompt
    $code = Invoke-Setup -Repo $legacyRepo -Harness "claude" -Model ""
    if ($code -ne 0) { throw "legacy migration failed with exit $code" }
    if (Test-Path -LiteralPath $legacyPrompt) { throw "exact managed legacy prompt was not deleted" }

    $modifiedLegacyRepo = New-TestRepo "repo-modified-legacy"
    $modifiedLegacyPrompt = Join-Path $modifiedLegacyRepo ".github\claude\prompts\pr-review.md"
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $modifiedLegacyPrompt) | Out-Null
    [System.IO.File]::WriteAllText($modifiedLegacyPrompt, "custom legacy prompt")
    $code = Invoke-Setup -Repo $modifiedLegacyRepo -Harness "cursor" -Model ""
    if ($code -ne 0) { throw "modified legacy install failed with exit $code" }
    if (-not (Test-Path -LiteralPath $modifiedLegacyPrompt)) { throw "modified legacy prompt was deleted" }

    $conflictRepo = New-TestRepo "repo-conflict"
    $code = Invoke-Setup -Repo $conflictRepo -Harness "opencode" -Model "openai/gpt-5.2#high"
    if ($code -ne 0) { throw "initial conflict test install failed" }
    $conflictWorkflow = Join-Path $conflictRepo ".github\workflows\automatic-prr.yml"
    Add-Content -LiteralPath $conflictWorkflow -Value "`n# local edit"
    $code = Invoke-Setup -Repo $conflictRepo -Harness "opencode" -Model "openai/gpt-5.2#high"
    if ($code -ne 3) { throw "Expected conflict exit 3, got $code" }
    $code = Invoke-Setup -Repo $conflictRepo -Harness "opencode" -Model "openai/gpt-5.2#high" -Force
    if ($code -ne 0) { throw "force install failed with exit $code" }
    Assert-NotContains ([System.IO.File]::ReadAllText($conflictWorkflow)) "# local edit"

    $invalidRepo = New-TestRepo "repo-invalid"
    $code = Invoke-Setup -Repo $invalidRepo -Harness "unknown" -Model ""
    if ($code -ne 2) { throw "Expected invalid harness exit 2, got $code" }
    $code = Invoke-Setup -Repo $invalidRepo -Harness "claude" -Model "bad`nmodel"
    if ($code -ne 2) { throw "Expected multiline model exit 2, got $code" }

    $skillMd = [System.IO.File]::ReadAllText((Join-Path $skillRoot "SKILL.md"))
    $readme = [System.IO.File]::ReadAllText((Join-Path $skillRoot "README.md"))
    $design = [System.IO.File]::ReadAllText((Join-Path $skillRoot "DESIGN.md"))
    foreach ($doc in @($skillMd, $readme, $design)) {
        foreach ($needle in @(
                '$env:Path',
                'Start-Process powershell',
                'gh auth login --hostname github.com --git-protocol https --web',
                'Listening for Jobs',
                'gh-proxy.com',
                'ExecutionTimeLimit',
                '.runner',
                'claude-review',
                '.github/automatic-prr/pr-review.md',
                'Skill Initialization',
                'scripts/initialize-skills.ps1',
                'pr-code-review',
                '.claude/skills/',
                '.agents/skills/',
                'MANAGED_PATH'
            )) {
            Assert-Contains $doc $needle
        }
        Assert-NotContains $doc "you must install pwsh yourself"
    }
    Assert-Contains $skillMd "prepend the printed ``gh:`` and ``pwsh:`` directories"
    Assert-Contains $design "scripts/ensure-tools.ps1"
    $installStep = $skillMd.IndexOf('7. Install or verify')
    $initializeStep = $skillMd.IndexOf('8. **Skill Initialization**')
    $workflowStep = $skillMd.IndexOf('10. Install files')
    if ($installStep -lt 0 -or $initializeStep -le $installStep -or $workflowStep -le $initializeStep) {
        throw 'Skill Initialization must follow harness installation and precede workflow installation.'
    }
    Assert-Contains $skillMd '-SourceDirectory $snapshot'
    Assert-Contains $readme 'powershell -NoProfile -File tests\test-initialize-skills.ps1'

    Write-Output "setup tests passed"
}
finally {
    Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue
}
