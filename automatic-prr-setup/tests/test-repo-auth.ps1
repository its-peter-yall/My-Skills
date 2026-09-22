#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$skillRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $skillRoot "scripts\repo-auth-helpers.ps1")

function Assert-Equal($Actual, $Expected, [string] $Label) {
    if ($Actual -ne $Expected) {
        throw "${Label}: expected '$Expected', got '$Actual'"
    }
}

function Assert-True([bool] $Value, [string] $Label) {
    if (-not $Value) {
        throw "${Label}: expected true"
    }
}

function Assert-False([bool] $Value, [string] $Label) {
    if ($Value) {
        throw "${Label}: expected false"
    }
}

function Assert-Contains([string] $Text, [string] $Needle, [string] $Label) {
    if ($Text.IndexOf($Needle) -lt 0) {
        throw "${Label}: missing '$Needle'"
    }
}

$https = ConvertFrom-GitHubRemoteUrl "https://github.com/Actual-Owner/repo-name.git"
Assert-Equal $https.FullName "Actual-Owner/repo-name" "https remote"
$ssh = ConvertFrom-GitHubRemoteUrl "git@github.com:Actual-Owner/repo-name.git"
Assert-Equal $ssh.FullName "Actual-Owner/repo-name" "ssh remote"
$scp = ConvertFrom-GitHubRemoteUrl "ssh://git@github.com:22/Actual-Owner/repo-name"
Assert-Equal $scp.FullName "Actual-Owner/repo-name" "ssh port remote"
$tokenUrl = "https://x-access-token:secret-token@github.com/Actual-Owner/repo-name.git"
$tokenRemote = ConvertFrom-GitHubRemoteUrl $tokenUrl
Assert-Equal $tokenRemote.FullName "Actual-Owner/repo-name" "token remote"
Assert-False ($tokenRemote.FullName.Contains("secret-token")) "token not retained"
Assert-Equal (ConvertFrom-GitHubRemoteUrl "https://gitlab.com/Actual-Owner/repo-name.git") $null "non-github host"
Assert-Equal (ConvertFrom-GitHubRemoteUrl "https://github.com/Actual-Owner") $null "missing repo"
Assert-Equal (ConvertFrom-GitHubRemoteUrl "") $null "empty remote"

$adminRepo = [pscustomobject]@{
    full_name = "Actual-Owner/repo-name"
    html_url = "https://github.com/Actual-Owner/repo-name"
    permissions = [pscustomobject]@{ admin = $true; push = $true }
    owner = [pscustomobject]@{ login = "Actual-Owner"; type = "User" }
}
$granted = Get-GitHubRepoAdminDecision -ExpectedFullName "Actual-Owner/repo-name" -ActiveLogin "Actual-Owner" -Repository $adminRepo
Assert-True $granted.Ok "owner admin"
Assert-Equal $granted.Url "https://github.com/Actual-Owner/repo-name" "canonical url"

$memberRepo = [pscustomobject]@{
    full_name = "Actual-Org/repo-name"
    html_url = "https://github.com/Actual-Org/repo-name/"
    permissions = [pscustomobject]@{ admin = $true }
    owner = [pscustomobject]@{ login = "Actual-Org"; type = "Organization" }
}
$member = Get-GitHubRepoAdminDecision -ExpectedFullName "Actual-Org/repo-name" -ActiveLogin "member-user" -Repository $memberRepo
Assert-True $member.Ok "org member admin"
Assert-Equal $member.OwnerLogin "Actual-Org" "org owner preserved"
Assert-Equal $member.Url "https://github.com/Actual-Org/repo-name" "trailing slash stripped"

$wrongAccount = Get-GitHubRepoAdminDecision -ExpectedFullName "Actual-Owner/repo-name" -ActiveLogin "other-user" -Repository $null
Assert-False $wrongAccount.Ok "missing repo access"
Assert-Contains $wrongAccount.Reason "other-user" "names active account"
Assert-Contains $wrongAccount.Reason "Actual-Owner/repo-name" "names origin repo"
Assert-Contains $wrongAccount.Reason "gh auth switch --hostname github.com" "switch hint"
Assert-Contains $wrongAccount.Reason "gh auth status alone is not enough" "status is insufficient"

$collaborator = [pscustomobject]@{
    full_name = "Actual-Owner/repo-name"
    html_url = "https://github.com/Actual-Owner/repo-name"
    permissions = [pscustomobject]@{ admin = $false; push = $true }
    owner = [pscustomobject]@{ login = "Actual-Owner"; type = "User" }
}
$notAdmin = Get-GitHubRepoAdminDecision -ExpectedFullName "Actual-Owner/repo-name" -ActiveLogin "other-user" -Repository $collaborator
Assert-False $notAdmin.Ok "push without admin"
Assert-Contains $notAdmin.Reason "cannot administer" "admin required"
Assert-Contains $notAdmin.Reason "repository owner is 'Actual-Owner'" "owner mismatch"

$orgDeny = [pscustomobject]@{
    full_name = "Actual-Org/repo-name"
    html_url = "https://github.com/Actual-Org/repo-name"
    permissions = [pscustomobject]@{ admin = $false }
    owner = [pscustomobject]@{ login = "Actual-Org"; type = "Organization" }
}
$orgNoAdmin = Get-GitHubRepoAdminDecision -ExpectedFullName "Actual-Org/repo-name" -ActiveLogin "member-user" -Repository $orgDeny
Assert-False $orgNoAdmin.Ok "org without admin"
Assert-Contains $orgNoAdmin.Reason "organization" "org hint"

$noLogin = Get-GitHubRepoAdminDecision -ExpectedFullName "Actual-Owner/repo-name" -ActiveLogin "  " -Repository $adminRepo
Assert-False $noLogin.Ok "blank login"

$registerText = [System.IO.File]::ReadAllText((Join-Path $skillRoot "scripts\register-runner.ps1"))
Assert-Contains $registerText "Resolve-ActiveGitHubRepoAccess" "register uses repo auth"
if ($registerText.IndexOf("gh repo view") -ge 0) {
    throw "register-runner.ps1 must not resolve the repository with gh repo view"
}

$workflowText = [System.IO.File]::ReadAllText((Join-Path $skillRoot "templates\workflows\automatic-prr.yml"))
Assert-Contains $workflowText "workflow token" "workflow documents token auth"
if ($workflowText.IndexOf("gh auth status") -ge 0) {
    throw "workflow must not check gh auth status"
}
if ($workflowText.IndexOf("gh auth switch") -ge 0) {
    throw "workflow must not switch GitHub accounts"
}

Write-Output "repo auth tests passed"
