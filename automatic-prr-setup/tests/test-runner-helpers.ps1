#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$skillRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $skillRoot "scripts\runner-helpers.ps1")

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

$digest = ConvertTo-UnprefixedSha256 "sha256:1150692afa94e71f872017e254ea55b6eece1eece3fe7e3a6d4c93d0a1b85cfc"
Assert-Equal $digest "1150692afa94e71f872017e254ea55b6eece1eece3fe7e3a6d4c93d0a1b85cfc" "strip sha256 prefix"
Assert-Equal (ConvertTo-UnprefixedSha256 "SHA256:ABCDef") "abcdef" "case-insensitive prefix"
Assert-Equal (ConvertTo-UnprefixedSha256 "  deadbeef  ") "deadbeef" "bare digest"
Assert-Equal (ConvertTo-UnprefixedSha256 "") "" "empty digest"
Assert-Equal (ConvertTo-UnprefixedSha256 $null) "" "null digest"

$proxy = Get-GitHubRunnerProxyUrl -Tag "v2.337.0" -AssetName "actions-runner-win-x64-2.337.0.zip"
Assert-Equal $proxy "https://gh-proxy.com/https://github.com/actions/runner/releases/download/v2.337.0/actions-runner-win-x64-2.337.0.zip" "proxy URL"
Assert-Equal (Get-GitHubRunnerProxyUrl -Tag "" -AssetName "x.zip") "" "empty tag"

$plain = [string[]]@(Get-CurlDownloadArgumentList -Uri "https://example.test/file.zip" -OutFile "C:\tmp\file.zip")
if ($plain -contains "--ipv4") { throw "default curl args must not include --ipv4" }
foreach ($needle in @("--fail", "--location", "--tlsv1.2", "--output", "C:\tmp\file.zip", "--url", "https://example.test/file.zip")) {
    if ($plain -notcontains $needle) {
        throw "curl args missing $needle"
    }
}
$ipv4 = [string[]]@(Get-CurlDownloadArgumentList -Uri "https://example.test/file.zip" -OutFile "C:\tmp\file.zip" -IPv4)
if ($ipv4[0] -ne "--ipv4") { throw "IPv4 curl args must start with --ipv4" }
if ($ipv4 -notcontains "--tlsv1.2") { throw "IPv4 curl args must still pin TLS 1.2" }

Assert-True (Test-TlsOrConnectionResetMessage "Unable to connect: connection reset") "connection reset"
Assert-True (Test-TlsOrConnectionResetMessage "schannel: failed to receive handshake") "handshake"
Assert-True (Test-TlsOrConnectionResetMessage "SSL timeout") "tls timeout"
Assert-False (Test-TlsOrConnectionResetMessage "HTTP 404 Not Found") "404 is not a TLS reset"
Assert-False (Test-TlsOrConnectionResetMessage "") "empty error"

$fixture = Join-Path ([System.IO.Path]::GetTempPath()) ("automatic-prr-helpers-" + [guid]::NewGuid().ToString("N"))
try {
    New-Item -ItemType Directory -Path $fixture | Out-Null
    $real = Join-Path $fixture "pwsh.exe"
    [System.IO.File]::WriteAllText($real, "not-empty-pwsh-stub")
    Assert-True (Test-WorkingPwshFile -ExePath $real) "non-empty pwsh.exe is working"
    $empty = Join-Path $fixture "empty-pwsh.exe"
    [System.IO.File]::WriteAllBytes($empty, [byte[]]@())
    Assert-False (Test-WorkingPwshFile -ExePath $empty) "0-byte pwsh.exe is not working"
    Assert-False (Test-WorkingPwshFile -ExePath (Join-Path $fixture "missing.exe")) "missing exe"
}
finally {
    Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output "runner helper tests passed"
