#Requires -Version 5.1
Set-StrictMode -Version Latest

function ConvertTo-UnprefixedSha256([string] $Digest) {
    if ([string]::IsNullOrWhiteSpace($Digest)) {
        return ""
    }
    $value = $Digest.Trim()
    if ($value.Length -ge 7 -and $value.Substring(0, 7).ToLowerInvariant() -eq "sha256:") {
        $value = $value.Substring(7).Trim()
    }
    return $value.ToLowerInvariant()
}

function Get-GitHubRunnerProxyUrl([string] $Tag, [string] $AssetName) {
    if ([string]::IsNullOrWhiteSpace($Tag) -or [string]::IsNullOrWhiteSpace($AssetName)) {
        return ""
    }
    return "https://gh-proxy.com/https://github.com/actions/runner/releases/download/$Tag/$AssetName"
}

function Get-CurlDownloadArgumentList {
    param(
        [Parameter(Mandatory = $true)][string] $Uri,
        [Parameter(Mandatory = $true)][string] $OutFile,
        [switch] $IPv4
    )
    $arguments = @()
    if ($IPv4) {
        $arguments += "--ipv4"
    }
    $arguments += @(
        "--fail",
        "--location",
        "--silent",
        "--show-error",
        "--retry", "3",
        "--retry-delay", "2",
        "--tlsv1.2",
        "--output", $OutFile,
        "--url", $Uri
    )
    return $arguments
}

function Test-TlsOrConnectionResetMessage([string] $Message) {
    if ([string]::IsNullOrWhiteSpace($Message)) {
        return $false
    }
    return [bool] ($Message -match '(?i)connection reset|connection was reset|tls|handshake|timed? ?out|could not resolve|failed to connect|ssl|schannel|forcibly closed')
}

function Test-WorkingPwshFile {
    param(
        [string] $ExePath,
        [switch] $AllowWindowsAppsAlias
    )
    if ([string]::IsNullOrWhiteSpace($ExePath) -or -not (Test-Path -LiteralPath $ExePath -PathType Leaf)) {
        return $false
    }
    try {
        $item = Get-Item -LiteralPath $ExePath
        if ($item.Length -le 0) {
            return $false
        }
        $aliasDir = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps"
        $fullName = $item.FullName
        if (-not $AllowWindowsAppsAlias -and $aliasDir -and $fullName.StartsWith($aliasDir, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $false
        }
        return $true
    }
    catch {
        return $false
    }
}

function Resolve-RealPwshDirectory {
    $directories = New-Object System.Collections.Generic.List[string]
    foreach ($candidate in @(
            (Join-Path $env:ProgramFiles "PowerShell\7"),
            (Join-Path ${env:ProgramFiles(x86)} "PowerShell\7")
        )) {
        if ($candidate) {
            $directories.Add($candidate) | Out-Null
        }
    }

    try {
        $packages = @(Get-AppxPackage -Name Microsoft.PowerShell -ErrorAction SilentlyContinue)
        foreach ($package in $packages) {
            if ($package -and $package.InstallLocation) {
                $directories.Add([string] $package.InstallLocation) | Out-Null
            }
        }
    }
    catch {
    }

    $command = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($command -and $command.Source) {
        $directories.Add((Split-Path -Parent $command.Source)) | Out-Null
    }

    foreach ($directory in $directories) {
        if ([string]::IsNullOrWhiteSpace($directory)) {
            continue
        }
        $exe = Join-Path $directory "pwsh.exe"
        if (Test-WorkingPwshFile -ExePath $exe) {
            return $directory
        }
    }
    return $null
}

function Test-WindowsAppsPwshDirectory {
    $directory = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps"
    $exe = Join-Path $directory "pwsh.exe"
    if (Test-WorkingPwshFile -ExePath $exe -AllowWindowsAppsAlias) {
        return $directory
    }
    return $null
}
