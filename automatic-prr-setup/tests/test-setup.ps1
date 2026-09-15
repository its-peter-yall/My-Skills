#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$skillRoot = Split-Path -Parent $PSScriptRoot
$fixture = Join-Path ([System.IO.Path]::GetTempPath()) ("automatic-prr-test-" + [guid]::NewGuid().ToString("N"))
$repo = Join-Path $fixture "repo"
New-Item -ItemType Directory -Path $repo | Out-Null

try {
    git -C $repo init -q
    git -C $repo config user.name test
    git -C $repo config user.email test@example.com
    git -C $repo switch -q -c feature/setup

    $env:CLAUDE_SKILL_DIR = $skillRoot
    Push-Location $repo
    try {
        & (Join-Path $skillRoot "scripts\setup.ps1") -RunnerLabel "review-box"
        if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw "setup.ps1 failed on first install" }
    } finally {
        Pop-Location
    }

    $workflow = Join-Path $repo ".github\workflows\automatic-prr.yml"
    $prompt = Join-Path $repo ".github\claude\prompts\pr-review.md"
    if (-not (Test-Path -LiteralPath $workflow)) { throw "workflow missing" }
    if (-not (Test-Path -LiteralPath $prompt)) { throw "prompt missing" }

    $workflowText = [System.IO.File]::ReadAllText($workflow)
    $promptText = [System.IO.File]::ReadAllText($prompt)
    foreach ($needle in @(
            'runs-on: [self-hosted, review-box]',
            'github.event.pull_request.head.sha',
            'actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1',
            'MODEL: "sonnet"',
            'shell: pwsh',
            '--model $env:MODEL'
        )) {
        if ($workflowText.IndexOf($needle) -lt 0) {
            throw "workflow missing: $needle"
        }
    }
    if ($promptText.IndexOf("/code-review --comment") -lt 0) {
        throw "prompt missing /code-review --comment"
    }

    Push-Location $repo
    try {
        & (Join-Path $skillRoot "scripts\setup.ps1") -RunnerLabel "review-box"
        if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw "identical reinstall should succeed" }
    } finally {
        Pop-Location
    }

    Add-Content -LiteralPath $workflow -Value "`n# local edit"
    Push-Location $repo
    try {
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        & (Join-Path $skillRoot "scripts\setup.ps1") -RunnerLabel "review-box"
        $code = $LASTEXITCODE
        $ErrorActionPreference = $prevEap
        if ($code -ne 3) {
            throw "Expected conflict exit 3, got $code"
        }
    } finally {
        Pop-Location
    }

    Push-Location $repo
    try {
        & (Join-Path $skillRoot "scripts\setup.ps1") -RunnerLabel "review-box" -Force
        if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw "force install failed" }
    } finally {
        Pop-Location
    }

    $afterForce = [System.IO.File]::ReadAllText((Join-Path $repo ".github\workflows\automatic-prr.yml"))
    if ($afterForce.IndexOf("# local edit") -ge 0) {
        throw "Force install did not replace the conflicting file."
    }

    Write-Output "setup tests passed"
}
finally {
    Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue
}
