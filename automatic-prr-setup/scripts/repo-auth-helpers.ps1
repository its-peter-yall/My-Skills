#Requires -Version 5.1
Set-StrictMode -Version Latest

function New-RepoAuthDecision {
    param(
        [bool] $Ok,
        [string] $Reason,
        [string] $FullName = "",
        [string] $Url = "",
        [string] $ActiveLogin = "",
        [string] $OwnerLogin = "",
        [string] $OwnerType = ""
    )
    return [pscustomobject]@{
        Ok = $Ok
        Reason = $Reason
        FullName = $FullName
        Url = $Url
        ActiveLogin = $ActiveLogin
        OwnerLogin = $OwnerLogin
        OwnerType = $OwnerType
    }
}

function Get-PSObjectPropertyValue {
    param(
        $Object,
        [string] $Name
    )
    if ($null -eq $Object) {
        return $null
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value
}

function ConvertFrom-GitHubRemoteUrl {
    param([string] $Url)
    if ([string]::IsNullOrWhiteSpace($Url)) {
        return $null
    }

    $value = $Url.Trim().TrimEnd("/")
    if ($value.Length -ge 4 -and $value.Substring($value.Length - 4).ToLowerInvariant() -eq ".git") {
        $value = $value.Substring(0, $value.Length - 4).TrimEnd("/")
    }

    $owner = $null
    $name = $null
    if ($value -match '^(?i:https://|ssh://|git://)(?:[^/@\s]+@)?github\.com(?::\d+)?/([^/\s]+)/([^/\s]+)$') {
        $owner = $Matches[1]
        $name = $Matches[2]
    }
    elseif ($value -match '^(?i)git@github\.com:([^/\s]+)/([^/\s]+)$') {
        $owner = $Matches[1]
        $name = $Matches[2]
    }
    else {
        return $null
    }

    if ($owner -notmatch '^[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?$') {
        return $null
    }
    if ($name -notmatch '^[A-Za-z0-9._-]{1,100}$' -or $name -eq "." -or $name -eq "..") {
        return $null
    }

    return [pscustomobject]@{
        Owner = $owner
        Name = $name
        FullName = "$owner/$name"
    }
}

function Get-GitHubRepoAdminDecision {
    param(
        [string] $ExpectedFullName,
        [string] $ActiveLogin,
        $Repository
    )

    $login = ""
    if (-not [string]::IsNullOrWhiteSpace($ActiveLogin)) {
        $login = $ActiveLogin.Trim()
    }
    $expected = ""
    if (-not [string]::IsNullOrWhiteSpace($ExpectedFullName)) {
        $expected = $ExpectedFullName.Trim()
    }

    if ([string]::IsNullOrWhiteSpace($login)) {
        return New-RepoAuthDecision $false "GitHub CLI has no active account for github.com."
    }
    if ($expected -notmatch '^[^/\s]+/[^/\s]+$') {
        return New-RepoAuthDecision $false "origin is not a github.com owner/repo remote. Refusing to trust gh repo view, which follows whichever account is active." -ActiveLogin $login
    }

    $switchHint = "Run gh auth switch --hostname github.com and select an account with admin on $expected, then rerun. gh auth status alone is not enough."
    if ($null -eq $Repository) {
        return New-RepoAuthDecision $false "Active GitHub account '$login' cannot access $expected from origin. $switchHint" -FullName $expected -ActiveLogin $login
    }

    $fullName = [string](Get-PSObjectPropertyValue $Repository "full_name")
    $htmlUrl = [string](Get-PSObjectPropertyValue $Repository "html_url")
    $permissions = Get-PSObjectPropertyValue $Repository "permissions"
    $adminValue = Get-PSObjectPropertyValue $permissions "admin"
    $owner = Get-PSObjectPropertyValue $Repository "owner"
    $ownerLogin = [string](Get-PSObjectPropertyValue $owner "login")
    $ownerType = [string](Get-PSObjectPropertyValue $owner "type")
    $admin = ($adminValue -eq $true)

    if ([string]::IsNullOrWhiteSpace($fullName)) {
        return New-RepoAuthDecision $false "GitHub did not identify a repository for $expected. $switchHint" -FullName $expected -ActiveLogin $login
    }

    $url = $htmlUrl.Trim()
    if ([string]::IsNullOrWhiteSpace($url)) {
        $url = "https://github.com/$fullName"
    }
    $url = $url.TrimEnd("/")

    if (-not $admin) {
        $ownerNote = ""
        if ($ownerType -eq "Organization") {
            $ownerNote = " $expected belongs to organization '$ownerLogin'; sign in as a member with admin, not as the organization."
        }
        elseif (-not [string]::IsNullOrWhiteSpace($ownerLogin) -and $ownerLogin -ne $login) {
            $ownerNote = " The repository owner is '$ownerLogin', not '$login'."
        }
        return New-RepoAuthDecision $false "Active GitHub account '$login' cannot administer $expected.$ownerNote Runner registration and the landing pull request need admin on the repository origin points at. $switchHint" -FullName $fullName -Url $url -ActiveLogin $login -OwnerLogin $ownerLogin -OwnerType $ownerType
    }

    return New-RepoAuthDecision $true "" -FullName $fullName -Url $url -ActiveLogin $login -OwnerLogin $ownerLogin -OwnerType $ownerType
}

function Resolve-ActiveGitHubRepoAccess {
    param(
        [string] $RemoteName = "origin"
    )

    if ($RemoteName -notmatch '^[A-Za-z0-9._-]+$') {
        return New-RepoAuthDecision $false "Invalid git remote name."
    }

    $previousNative = $null
    $hadNative = $false
    if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -Scope Global -ErrorAction SilentlyContinue) {
        $hadNative = $true
        $previousNative = $PSNativeCommandUseErrorActionPreference
        $PSNativeCommandUseErrorActionPreference = $false
    }
    $previousRepo = $env:GH_REPO
    $hadRepo = Test-Path Env:GH_REPO
    try {
        Remove-Item Env:GH_REPO -ErrorAction SilentlyContinue

        $remoteUrl = & git remote get-url $RemoteName 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace([string]$remoteUrl)) {
            return New-RepoAuthDecision $false "Could not read git remote '$RemoteName'. Run from the repository that should host the runner."
        }

        $parsed = ConvertFrom-GitHubRemoteUrl ([string]$remoteUrl)
        if ($null -eq $parsed) {
            return New-RepoAuthDecision $false "Remote '$RemoteName' is not a github.com owner/repo URL. Refusing to resolve the repository through the active gh account."
        }

        & gh auth status --hostname github.com 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            return New-RepoAuthDecision $false "gh is not authenticated for github.com. Run gh auth login --hostname github.com --git-protocol https --web, then rerun." -FullName $parsed.FullName
        }

        $loginText = & gh api user --hostname github.com --jq .login 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace([string]$loginText)) {
            return New-RepoAuthDecision $false "Could not read the active github.com account. $parsed.FullName must be administered by that account." -FullName $parsed.FullName
        }
        $login = ([string]$loginText).Trim()

        $payload = & gh api "repos/$($parsed.FullName)" --hostname github.com 2>$null
        $repository = $null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace([string]$payload)) {
            $repository = $payload | ConvertFrom-Json
        }

        $decision = Get-GitHubRepoAdminDecision -ExpectedFullName $parsed.FullName -ActiveLogin $login -Repository $repository
        if (-not $decision.Ok -and ((Test-Path Env:GH_TOKEN) -or (Test-Path Env:GITHUB_TOKEN))) {
            $decision = New-RepoAuthDecision $false ($decision.Reason + " GH_TOKEN or GITHUB_TOKEN is set and overrides stored gh credentials.") -FullName $decision.FullName -Url $decision.Url -ActiveLogin $decision.ActiveLogin -OwnerLogin $decision.OwnerLogin -OwnerType $decision.OwnerType
        }
        return $decision
    }
    finally {
        if ($hadRepo) {
            $env:GH_REPO = $previousRepo
        }
        elseif (Test-Path Env:GH_REPO) {
            Remove-Item Env:GH_REPO -ErrorAction SilentlyContinue
        }
        if ($hadNative) {
            $PSNativeCommandUseErrorActionPreference = $previousNative
        }
    }
}
