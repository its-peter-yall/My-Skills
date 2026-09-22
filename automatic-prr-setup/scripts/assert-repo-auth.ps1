#Requires -Version 5.1
[CmdletBinding()]
param(
    [string] $RemoteName = "origin"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "repo-auth-helpers.ps1")

$access = Resolve-ActiveGitHubRepoAccess -RemoteName $RemoteName
if (-not $access.Ok) {
    [Console]::Error.WriteLine($access.Reason)
    exit 1
}

Write-Output ("ACTIVE_LOGIN=" + $access.ActiveLogin)
Write-Output ("REPO=" + $access.FullName)
Write-Output ("REPO_URL=" + $access.Url)
Write-Output ("REPO_OWNER=" + $access.OwnerLogin)
if (-not [string]::IsNullOrWhiteSpace($access.OwnerLogin) -and $access.OwnerLogin -ne $access.ActiveLogin) {
    Write-Output "AUTH_NOTE=active account is an admin of this repository, not its owner login"
}
exit 0
