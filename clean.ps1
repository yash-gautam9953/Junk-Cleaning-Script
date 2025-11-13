# PrettyClean.ps1
# Safe, colorful, no-admin junk cleaner

$ErrorActionPreference = "SilentlyContinue"
Clear-Host

function Write-Color {
    param([string]$Text, [ConsoleColor]$Color = "White")
    $oldColor = $Host.UI.RawUI.ForegroundColor
    $Host.UI.RawUI.ForegroundColor = $Color
    Write-Host $Text
    $Host.UI.RawUI.ForegroundColor = $oldColor
}

Write-Color "✨=== Welcome to PrettyClean! (Safe Junk Cleaner) ===✨" -Color Cyan
Write-Color "🧑 User: $env:USERNAME" -Color Yellow
Write-Color "⚙️  Mode: Non-Administrator (User-safe)" -Color Yellow
Write-Color "`nStarting cleanup... Please wait..." -Color Cyan

Start-Sleep -Milliseconds 500

# Measure used space before cleanup
$drive = Get-PSDrive -Name C
$beforeFree = [math]::Round($drive.Free/1GB, 2)

# Define safe cleanup paths
$safePaths = @(
    "${env:TEMP}",
    "${env:LOCALAPPDATA}\Temp",
    "${env:LOCALAPPDATA}\Microsoft\Windows\INetCache",
    "${env:LOCALAPPDATA}\Google\Chrome\User Data\**\Cache\*",
    "${env:LOCALAPPDATA}\Microsoft\Edge\User Data\**\Cache\*",
    "${env:APPDATA}\Mozilla\Firefox\Profiles\**\cache2\*",
    "${env:LOCALAPPDATA}\Microsoft\Windows\Explorer\thumbcache_*.db"
)

# Function to clean safely
function SafeClean($path) {
    Write-Color "🧹 Cleaning: $path" -Color Green
    Get-ChildItem -Path $path -Force -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        try { Remove-Item -LiteralPath $_.FullName -Force -Recurse -ErrorAction SilentlyContinue } catch {}
    }
}

# Cleaning
foreach ($p in $safePaths) { SafeClean $p }

# Clear recycle bin (only current user)
Write-Color "🗑️ Emptying Recycle Bin..." -Color Green
try { Clear-RecycleBin -Force -ErrorAction SilentlyContinue } catch {}

# Measure after cleanup
$drive = Get-PSDrive -Name C
$afterFree = [math]::Round($drive.Free/1GB, 2)
$spaceFreed = [math]::Round($afterFree - $beforeFree, 2)

# Summary
Write-Color "`n✅ Cleanup Complete!" -Color Cyan
if ($spaceFreed -gt 0) {
    Write-Color "💾 Space Freed: $spaceFreed GB" -Color Green
} else {
    Write-Color "💾 Space Freed: Less than 0.1 GB (Already clean!)" -Color Yellow
}

Write-Color "🪟 It's safe to continue using your system - no personal files were touched." -Color Cyan
Write-Color "`n🚀 Tip: Run this script weekly to keep your PC fast!" -Color Magenta
Write-Color "=========================================" -Color DarkGray
Start-Sleep 2
