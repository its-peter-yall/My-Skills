#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $Harness,
    [string] $SourceDirectory,
    [string] $SnapshotDirectory,
    [switch] $Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Fail([int] $Code, [string] $Message) {
    [Console]::Error.WriteLine($Message)
    exit $Code
}

function Invoke-Git([string[]] $Arguments) {
    # Windows PowerShell turns native stderr into error records, including normal Git progress.
    $oldPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $output = & git @Arguments 2>&1
        return [pscustomobject]@{ Code = $LASTEXITCODE; Output = ($output | Out-String).TrimEnd() }
    }
    finally { $ErrorActionPreference = $oldPreference }
}

function Get-FullPath([string] $Path) {
    return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
}

function Assert-SafePath([string] $Path) {
    # Check every existing ancestor, not just the leaf: neither reads nor writes may follow links.
    $current = Get-FullPath $Path
    $leaf = $true
    while ($current) {
        $item = Get-Item -LiteralPath $current -Force -ErrorAction SilentlyContinue
        if ($null -ne $item) {
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Symbolic link or reparse point is not allowed: $current"
            }
            if (-not $leaf -and -not $item.PSIsContainer) {
                throw "File/directory collision: $current"
            }
        }
        $leaf = $false
        $current = Split-Path -Parent $current
    }
}

function Assert-Directory([string] $Path) {
    Assert-SafePath $Path
    if ((Test-Path -LiteralPath $Path) -and -not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "File/directory collision: $Path"
    }
}

function Get-SkillEntries([string] $Directory) {
    # Deliberately walk one level at a time, checking links before descending.
    foreach ($item in Get-ChildItem -LiteralPath $Directory -Force) {
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Symbolic link or reparse point is not allowed: $($item.FullName)"
        }
        $item
        if ($item.PSIsContainer) { Get-SkillEntries $item.FullName }
    }
}

$Harness = $Harness.Trim().ToLowerInvariant()
if ($Harness -notin @("claude", "opencode", "cursor", "codex")) {
    Fail 2 "Invalid review harness: $Harness"
}
if ($SourceDirectory -and $SnapshotDirectory) {
    Fail 2 "Use either -SourceDirectory (existing snapshot) or -SnapshotDirectory (fresh retained clone), not both."
}
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Fail 1 "Missing prerequisite: git is not available on PATH."
}

$temporarySnapshot = $null
try {
    Assert-SafePath (Get-Location).Path
    $result = Invoke-Git @("rev-parse", "--show-toplevel")
    if ($result.Code -ne 0 -or -not $result.Output) {
        throw "Run this skill from inside the target Git repository."
    }
    $repoRoot = Get-FullPath $result.Output
    Assert-Directory $repoRoot
    $result = Invoke-Git @("-C", $repoRoot, "symbolic-ref", "--quiet", "--short", "HEAD")
    if ($result.Code -ne 0 -or -not $result.Output) {
        throw "Detached HEAD detected. Switch to the setup branch first."
    }
    $branchName = $result.Output

    if (-not $SourceDirectory) {
        $retained = [bool] $SnapshotDirectory
        if (-not $SnapshotDirectory) {
            $tempRoot = Join-Path ([IO.Path]::GetTempPath()) "opencode"
            if (-not (Test-Path -LiteralPath $tempRoot -PathType Container)) { $tempRoot = [IO.Path]::GetTempPath() }
            $SnapshotDirectory = Join-Path $tempRoot ("automatic-prr-skills-" + [guid]::NewGuid().ToString("N"))
        }
        $SnapshotDirectory = Get-FullPath $SnapshotDirectory
        Assert-SafePath $SnapshotDirectory
        if (Test-Path -LiteralPath $SnapshotDirectory) {
            throw "Snapshot directory must not preexist: $SnapshotDirectory"
        }
        $repoPrefix = $repoRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
        if ($SnapshotDirectory.Equals($repoRoot, [StringComparison]::OrdinalIgnoreCase) -or
            $SnapshotDirectory.StartsWith($repoPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Snapshot directory must be outside the target repository: $SnapshotDirectory"
        }
        # Set cleanup ownership before cloning, so failed downloads are also removed.
        $temporarySnapshot = $SnapshotDirectory
        $result = Invoke-Git @("-c", "core.autocrlf=false", "clone", "--quiet", "--depth", "1", "--branch", "master",
            "https://github.com/its-peter-yall/My-Skills.git", $SnapshotDirectory)
        if ($result.Code -ne 0) { throw "Official skill snapshot download failed: $($result.Output)" }
        # Persist byte-preserving checkout settings, including for retained snapshots.
        $result = Invoke-Git @("-C", $SnapshotDirectory, "config", "core.autocrlf", "false")
        if ($result.Code -ne 0) { throw "Could not configure the source snapshot: $($result.Output)" }
        $SourceDirectory = $SnapshotDirectory
        if ($retained) {
            $temporarySnapshot = $null
            Write-Output "Retained snapshot; remove after landing or abort: $SnapshotDirectory"
        }
    }

    $SourceDirectory = Get-FullPath $SourceDirectory
    Assert-Directory $SourceDirectory
    if (-not (Test-Path -LiteralPath $SourceDirectory -PathType Container)) {
        throw "Source snapshot directory is missing: $SourceDirectory"
    }
    Write-Output "SOURCE_DIRECTORY=$SourceDirectory"
    # Only report a SHA from the snapshot's own repository, never an enclosing repository.
    $result = Invoke-Git @("-C", $SourceDirectory, "rev-parse", "--show-toplevel")
    if ($result.Code -eq 0 -and (Get-FullPath $result.Output) -eq $SourceDirectory) {
        $result = Invoke-Git @("-C", $SourceDirectory, "rev-parse", "--verify", "HEAD")
        if ($result.Code -ne 0 -or $result.Output -notmatch '^[0-9a-f]{40,64}$') {
            throw "Cannot resolve source snapshot commit SHA."
        }
        Write-Output "SOURCE_SHA=$($result.Output)"
    } else {
        Write-Output "SOURCE_SHA=unversioned-local-source"
    }

    $prefix = if ($Harness -eq "claude") { ".claude/skills" } else { ".agents/skills" }
    $directories = @()
    $files = @()
    $conflicts = @()
    foreach ($skill in @("pr-code-review", "code-review")) {
        $sourceRoot = Join-Path $SourceDirectory "Code-Review Skills\$skill"
        Assert-Directory $sourceRoot
        $skillFile = Join-Path $sourceRoot "SKILL.md"
        Assert-SafePath $skillFile
        if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) {
            throw "Required skill file is missing: $skillFile"
        }
        $targetRoot = Join-Path $repoRoot "$prefix/$skill"
        Assert-Directory $targetRoot
        $directories += $targetRoot
        foreach ($entry in @(Get-SkillEntries $sourceRoot)) {
            $relative = $entry.FullName.Substring($sourceRoot.Length + 1).Replace('\', '/')
            $managedPath = "$prefix/$skill/$relative"
            $target = Join-Path $repoRoot $managedPath
            Assert-SafePath $target
            if ($entry.PSIsContainer) {
                Assert-Directory $target
                $directories += $target
            } else {
                if (Test-Path -LiteralPath $target -PathType Container) { throw "File/directory collision: $target" }
                $exists = Test-Path -LiteralPath $target -PathType Leaf
                $differs = $exists -and ((Get-FileHash -LiteralPath $entry.FullName -Algorithm SHA256).Hash -ne
                    (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash)
                $file = [pscustomobject]@{ Source = $entry.FullName; Target = $target; ManagedPath = $managedPath; Copy = (-not $exists -or $differs) }
                $files += $file
                if ($differs) { $conflicts += $file }
            }
        }
    }

    # Only these source-backed files may be staged; destination-only extras are never managed.
    foreach ($file in $files) { Write-Output "MANAGED_PATH=$($file.ManagedPath)" }
    if ($conflicts.Count -gt 0) {
        Write-Output "Existing managed file(s) differ (destination -> source):"
        foreach ($file in $conflicts) {
            Write-Output "  $($file.ManagedPath)"
            $result = Invoke-Git @("--no-pager", "diff", "--no-index", "--no-color", "--no-ext-diff", "--no-textconv",
                "--unified=3", "--", $file.Target, $file.Source)
            if ($result.Code -gt 1) { throw "Could not show conflict diff: $($result.Output)" }
            Write-Output $result.Output
        }
        if (-not $Force) {
            Fail 3 "No skill files were written. Review these differences and rerun with -Force only after approval."
        }
    }

    # Both complete trees have passed preflight. Preserve extras and leave identical files untouched.
    foreach ($directory in $directories) { [IO.Directory]::CreateDirectory($directory) | Out-Null }
    foreach ($file in $files) {
        if ($file.Copy) { [IO.File]::Copy($file.Source, $file.Target, $true) }
    }
    Write-Output "Installed pr-code-review and code-review for $Harness on branch $branchName."
    Write-Output "No files were committed or pushed."
}
catch {
    Fail 1 "Skill initialization is not READY: $($_.Exception.Message)"
}
finally {
    if ($temporarySnapshot -and (Test-Path -LiteralPath $temporarySnapshot)) {
        Remove-Item -LiteralPath $temporarySnapshot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
exit 0
