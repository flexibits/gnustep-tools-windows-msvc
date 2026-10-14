# Caches the files a phase installs, so later builds can skip rebuilding it.
# Called through common.bat's cache_restore and cache_store.
#
# The cache key covers:
#   - the contents of the -Inputs files (the phase script, the scripts it uses, its patches)
#   - the -Extra strings (target, build type, toolset versions)
#   - the commit -Ref (a tag or branch; the default branch if empty) resolves to in -Repo
#   - the keys of the phases cached earlier in this build, so a change to a dependency
#     also rebuilds everything cached after it
#
#   -Action Restore  on a hit, copies the cached files into -InstallPrefix and exits 0. On a miss,
#                    records the files in -InstallPrefix and exits 1, so the phase builds normally.
#   -Action Store    after a miss, caches the files the phase added or changed in -InstallPrefix.
#
# -StateDir holds the keys and file lists of this build's phases. -Inputs and -Extra are
# ';'-separated lists, and -Inputs entries may contain wildcards.
param(
    [Parameter(Mandatory=$true)][ValidateSet('Restore', 'Store')][string]$Action,
    [Parameter(Mandatory=$true)][string]$CacheDir,
    [Parameter(Mandatory=$true)][string]$Name,
    [Parameter(Mandatory=$true)][string]$InstallPrefix,
    [Parameter(Mandatory=$true)][string]$StateDir,
    [string]$Inputs = '',
    [string]$Extra = '',
    [string]$Repo = '',
    [string]$Ref = ''
)

$ErrorActionPreference = 'Stop'

$keyFile = Join-Path $StateDir "$Name.key"
$filesFile = Join-Path $StateDir "$Name.files"

function Get-RemoteCommit {
    if (-not $Repo) { return '' }
    $ref = if ($Ref) { $Ref } else { 'HEAD' }
    # Run outside any repository: the phases run inside tools-windows-msvc, whose .git may not be usable here
    $lines = @(git -C $env:TEMP ls-remote $Repo $ref "$ref^{}" 2>$null)
    if ($LASTEXITCODE -ne 0 -or $lines.Count -eq 0) {
        throw "Couldn't resolve $ref in $Repo"
    }
    # Prefer the peeled commit of an annotated tag
    $peeled = $lines | Where-Object { $_ -match '\^\{\}$' } | Select-Object -First 1
    $line = if ($peeled) { $peeled } else { $lines[0] }
    return ($line -split '\s+')[0]
}

function Get-CacheKey {
    $text = New-Object System.Text.StringBuilder
    foreach ($pattern in ($Inputs -split ';' | Where-Object { $_ })) {
        foreach ($file in @(Get-ChildItem -Path $pattern -File -ErrorAction SilentlyContinue | Sort-Object Name)) {
            [void]$text.AppendLine("$($file.Name) $((Get-FileHash -Path $file.FullName -Algorithm SHA256).Hash)")
        }
    }
    foreach ($value in ($Extra -split ';')) {
        [void]$text.AppendLine($value)
    }
    [void]$text.AppendLine("commit $(Get-RemoteCommit)")
    foreach ($earlier in @(Get-ChildItem -Path $StateDir -Filter '*.key' -File -ErrorAction SilentlyContinue | Sort-Object Name)) {
        if ($earlier.FullName -ne $keyFile) {
            [void]$text.AppendLine("$($earlier.BaseName) $((Get-Content -Path $earlier.FullName -Raw).Trim())")
        }
    }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $bytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($text.ToString()))
    return (-join ($bytes | ForEach-Object { $_.ToString('x2') })).Substring(0, 16)
}

# Relative path -> "length lastWriteTicks" for every file in the install prefix
function Get-InstalledFiles {
    $files = @{}
    if (Test-Path $InstallPrefix) {
        $prefix = (Resolve-Path $InstallPrefix).Path.TrimEnd('\')
        foreach ($file in @(Get-ChildItem -Path $prefix -Recurse -File -Force)) {
            $files[$file.FullName.Substring($prefix.Length + 1)] = "$($file.Length) $($file.LastWriteTimeUtc.Ticks)"
        }
    }
    return $files
}

New-Item -ItemType Directory -Force -Path $StateDir | Out-Null

if ($Action -eq 'Restore') {
    try {
        $key = Get-CacheKey
    } catch {
        # Build without the cache, and give this phase a key no cache entry can have, so the
        # phases cached after it don't reuse builds made against a different version of it
        Set-Content -Path $keyFile -Value ([guid]::NewGuid().ToString('N'))
        Write-Host "### Build cache unavailable for ${Name}: $_"
        exit 2
    }
    # Record the key even on a miss, so the phases cached after this one depend on it
    Set-Content -Path $keyFile -Value $key
    $entry = Join-Path $CacheDir "$Name-$key"
    if (Test-Path (Join-Path $entry '.complete')) {
        Write-Host "### Build cache hit: $Name-$key"
        # robocopy rather than Get-ChildItem -Recurse, which fails on deeper directories in the
        # VirtualBox shared folder the cache lives in ("The given path's format is not supported")
        & robocopy $entry $InstallPrefix /E /XF .complete /NFL /NDL /NJH /NJS /NP | Out-Null
        if ($LASTEXITCODE -ge 8) {
            throw "robocopy failed restoring $Name ($LASTEXITCODE)"
        }
        Write-Host "Restored $Name from the build cache"
        exit 0
    }
    Write-Host "### Build cache miss: $Name-$key"
    # Written even when empty (the first phase starts with no install prefix)
    $lines = @((Get-InstalledFiles).GetEnumerator() | ForEach-Object { "$($_.Value)|$($_.Key)" })
    [System.IO.File]::WriteAllLines($filesFile, [string[]]$lines)
    exit 1
}

# Store
if (-not (Test-Path $filesFile)) {
    throw "No file list from a cache miss for $Name"
}
$key = (Get-Content -Path $keyFile -Raw).Trim()
$before = @{}
foreach ($line in @(Get-Content -Path $filesFile)) {
    $value, $relative = $line -split '\|', 2
    $before[$relative] = $value
}
$changed = @((Get-InstalledFiles).GetEnumerator() | Where-Object { $before[$_.Key] -ne $_.Value } | ForEach-Object { $_.Key })
if ($changed.Count -eq 0) {
    throw "$Name didn't install any files"
}

# Copy into a temporary directory first and rename it into place, so an interrupted store
# never leaves an entry that looks complete
New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null
$entry = Join-Path $CacheDir "$Name-$key"
$temporary = "$entry.tmp-$PID"
if (Test-Path $temporary) { Remove-Item -Recurse -Force $temporary }
New-Item -ItemType Directory -Path $temporary | Out-Null
$prefix = (Resolve-Path $InstallPrefix).Path.TrimEnd('\')
foreach ($relative in $changed) {
    $destination = Join-Path $temporary $relative
    New-Item -ItemType Directory -Force -Path (Split-Path $destination) | Out-Null
    Copy-Item -Path (Join-Path $prefix $relative) -Destination $destination -Force
}
Set-Content -Path (Join-Path $temporary '.complete') -Value $key
if (Test-Path $entry) { Remove-Item -Recurse -Force $entry }
Rename-Item -Path $temporary -NewName (Split-Path $entry -Leaf)
Remove-Item -Path $filesFile

# Only keep the newest entry for this name
Get-ChildItem -Path $CacheDir -Directory -Filter "$Name-*" | Where-Object { $_.FullName -ne $entry } | ForEach-Object {
    Remove-Item -Recurse -Force $_.FullName
}

Write-Host "### Stored $($changed.Count) files in the build cache: $Name-$key"
exit 0
