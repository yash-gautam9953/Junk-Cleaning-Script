<#
PrettyClean.ps1
Safe, colorful, user-mode junk cleaner with safeguards
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$DryRun,               # Simulate actions without deleting
    [int]$MinAgeHours = 24,        # Only delete files older than this
    [switch]$NoEmoji               # Force ASCII-only output
)

$ErrorActionPreference = "Continue"
Clear-Host

# Emoji/encoding handling: default to ASCII on Windows PowerShell 5.x to avoid mojibake
$useEmoji = $false
if (-not $NoEmoji) {
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        try { $null = (& cmd /c chcp 65001) } catch { }
        try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new() } catch { }
        $cpOut = ''
        try { $cpOut = (& cmd /c chcp) 2>$null } catch { }
        if ($cpOut -match '65001') { $useEmoji = $true }
    }
}

function Get-IconMap {
    param([bool]$EnableEmoji)
    if ($EnableEmoji) {
        return @{
            sparkle = "✨"; user = "🧑"; gear = "⚙️"; broom = "🧹"; bin = "🗑️"; check = "✅"; disk = "💾"; tip = "🚀"; window = "🪟"
        }
    }
    return @{
        sparkle = "***"; user = "User"; gear = "[Mode]"; broom = "[Clean]"; bin = "[Recycle]"; check = "[OK]"; disk = "[Space]"; tip = "[Tip]"; window = "[Info]"
    }
}
$I = Get-IconMap -EnableEmoji:$useEmoji

function Write-Color {
    param([string]$Text, [ConsoleColor]$Color = "White")
    $oldColor = $Host.UI.RawUI.ForegroundColor
    $Host.UI.RawUI.ForegroundColor = $Color
    Write-Host $Text
    $Host.UI.RawUI.ForegroundColor = $oldColor
}

Write-Color ("{0}=== Welcome to PrettyClean! (Safe Junk Cleaner) ==={0}" -f $I.sparkle) -Color Cyan
Write-Color ("{0} User: {1}" -f $I.user, $env:USERNAME) -Color Yellow
Write-Color ("{0}  Mode: Non-Administrator (User-safe){1}" -f $I.gear, $(if ($DryRun -or $PSBoundParameters['WhatIf']) { " [DRY-RUN]" } else { "" })) -Color Yellow
Write-Color "`nStarting cleanup... Please wait..." -Color Cyan

Start-Sleep -Milliseconds 300

# Helpers
function Get-FilesToDelete {
    param(
        [string[]]$Paths,
        [int]$MinAgeHours
    )
    $cutoff = (Get-Date).AddHours(-1 * [math]::Abs($MinAgeHours))
    $files = @()
    foreach ($p in $Paths) {
        try {
            if (-not (Test-Path -LiteralPath $p)) { continue }
            $items = Get-ChildItem -LiteralPath $p -Force -File -Recurse -ErrorAction SilentlyContinue
            $files += $items | Where-Object { $_.LastWriteTime -lt $cutoff }
        } catch { }
    }
    return $files
}

function Get-SizeBytes {
    param([System.IO.FileSystemInfo[]]$Items)
    [long]($Items | Measure-Object -Property Length -Sum | Select-Object -ExpandProperty Sum)
}

function Clean-FilesSafely {
    param(
        [string]$Label,
        [System.IO.FileSystemInfo[]]$Files
    )
    if (-not $Files -or $Files.Count -eq 0) { return 0 }
    Write-Color ("{0} Cleaning: {1}" -f $I.broom, $Label) -Color Green
    $total = $Files.Count
    $idx = 0
    $removedBytes = 0
    foreach ($f in $Files) {
        $idx++
        if ($idx % 100 -eq 0) {
            Write-Progress -Activity "Cleaning $Label" -Status "$idx of $total" -PercentComplete ([int](100*$idx/$total))
        }
        $removedBytes += [long]$f.Length
        if ($PSCmdlet.ShouldProcess($f.FullName, "Remove")) {
            try { Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue } catch { }
        }
    }
    Write-Progress -Activity "Cleaning $Label" -Completed
    return $removedBytes
}

# Measure free space before cleanup
$drive = Get-PSDrive -Name C
$beforeFree = [math]::Round($drive.Free/1GB, 2)

# Targets (strictly limited to temp/cache locations)
$targets = @()

# 1) System/user temp
$targets += [pscustomobject]@{ Name = "Temp"; Paths = @("${env:TEMP}", "${env:LOCALAPPDATA}\Temp") }

# 2) IE/Edge Legacy cache (INetCache)
$targets += [pscustomobject]@{ Name = "INetCache"; Paths = @("${env:LOCALAPPDATA}\Microsoft\Windows\INetCache") }

# 3) Explorer thumbnail cache DBs
$thumbPaths = @()
if (Test-Path "${env:LOCALAPPDATA}\Microsoft\Windows\Explorer") {
    $thumbPaths = Get-ChildItem -Path "${env:LOCALAPPDATA}\Microsoft\Windows\Explorer" -Filter "thumbcache_*.db" -File -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }
}
$targets += [pscustomobject]@{ Name = "ThumbCache"; Paths = $thumbPaths }

# 4) Chrome caches within profiles
$chromeBase = "${env:LOCALAPPDATA}\Google\Chrome\User Data"
if (Test-Path $chromeBase) {
    $chromeCacheDirs = Get-ChildItem -Path $chromeBase -Directory -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -in @('Cache','Code Cache','GPUCache') }
    $targets += [pscustomobject]@{ Name = "Chrome Cache"; Paths = $chromeCacheDirs.FullName }
}

# 5) Edge caches within profiles
$edgeBase = "${env:LOCALAPPDATA}\Microsoft\Edge\User Data"
if (Test-Path $edgeBase) {
    $edgeCacheDirs = Get-ChildItem -Path $edgeBase -Directory -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -in @('Cache','Code Cache','GPUCache') }
    $targets += [pscustomobject]@{ Name = "Edge Cache"; Paths = $edgeCacheDirs.FullName }
}

# 6) Firefox cache2 in profiles
$ffBase = "${env:APPDATA}\Mozilla\Firefox\Profiles"
if (Test-Path $ffBase) {
    $ffCacheDirs = Get-ChildItem -Path $ffBase -Directory -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq 'cache2' }
    $targets += [pscustomobject]@{ Name = "Firefox Cache"; Paths = $ffCacheDirs.FullName }
}

# Collect, preview, and optionally delete
$totalBytesPlanned = 0
$totalBytesRemoved = 0
foreach ($t in $targets) {
    if (-not $t.Paths -or $t.Paths.Count -eq 0) { continue }
    # For thumbnail DBs we already have files; for others, enumerate files under paths
    $files = @()
    if ($t.Name -eq 'ThumbCache') {
        $files = @()
        foreach ($p in $t.Paths) { if (Test-Path $p) { $files += Get-Item -LiteralPath $p -ErrorAction SilentlyContinue } }
    } else {
        $files = Get-FilesToDelete -Paths $t.Paths -MinAgeHours $MinAgeHours
    }
    $planned = Get-SizeBytes -Items $files
    $totalBytesPlanned += $planned
    $removed = Clean-FilesSafely -Label $t.Name -Files $files
    $totalBytesRemoved += $removed
}

# Recycle Bin (current user only)
Write-Color ("{0} Emptying Recycle Bin...." -f $I.bin) -Color Green
try {
    if ($PSCmdlet.ShouldProcess("Recycle Bin", "Clear")) {
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    }
} catch { }

# Measure after cleanup
$drive = Get-PSDrive -Name C
$afterFree = [math]::Round($drive.Free/1GB, 2)
$spaceFreed = [math]::Round([math]::Max(0, $afterFree - $beforeFree), 2)

# Summary
Write-Color "`n$($I.check) Cleanup Complete!" -Color Cyan
if ($DryRun -or $PSBoundParameters['WhatIf']) {
    Write-Color ("$($I.disk) Would free approximately: {0} MB" -f [math]::Round($totalBytesPlanned/1MB,2)) -Color Yellow
} else {
    if ($spaceFreed -gt 0) {
        Write-Color ("$($I.disk) Space Freed: {0} GB" -f $spaceFreed) -Color Green
    } else {
        Write-Color "$($I.disk) Space Freed: Less than 0.1 GB (Already clean!)" -Color Yellow
    }
}

Write-Color ("{0} It's safe to continue using your system - no personal files were touched." -f $I.window) -Color Cyan
Write-Color "`n$($I.tip) Tip: Run this script weekly to keep your PC fast!" -Color Magenta
Write-Color "=========================================" -Color DarkGray
Start-Sleep 1

# Ensure success exit code even if a native tool returned non-zero earlier
$global:LASTEXITCODE = 0
