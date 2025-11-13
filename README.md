# PrettyClean — Safe Junk Cleaner (Windows PowerShell)

A safe, colorful, user-mode cleaner for Windows that targets only temp/cache locations. Designed to avoid deleting any important files (koi kaam ki file delete na ho).

## Features

- Safe by default: deletes only whitelisted temp/cache files
- Age filter: skips recent files (default: older than 24 hours)
- Dry-run and WhatIf: preview exactly what would be removed
- Progress + size estimates per target
- UTF‑8 emoji when available; falls back to ASCII automatically
- No admin rights required; works under your user account

## Safety First

- Whitelisted targets only:
  - `%TEMP%`, `%LOCALAPPDATA%\Temp`
  - `%LOCALAPPDATA%\Microsoft\Windows\INetCache`
  - Chrome/Edge/Firefox profile caches
  - Explorer `thumbcache_*.db`
- Personal folders (Documents/Downloads/etc.) are never touched
- Deletes only files by default; avoids removing directories
- Skips files newer than `MinAgeHours` (default 24)

## Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- Windows 10/11
- For emojis, PowerShell 7+ and a UTF‑8 console are recommended; otherwise the script uses ASCII automatically.

## Quick Start

```powershell
cd D:\GIthubRepo\junk-Cleaner-Script
# Optional: if the script was downloaded from the internet
Unblock-File .\clean.ps1

# Preview (safe):
.\clean.ps1 -DryRun

# Actual cleanup (default: only files older than 24 hours):
.\clean.ps1
```

## Usage

```powershell
.\clean.ps1 [-DryRun] [-MinAgeHours <int>] [-NoEmoji] [-WhatIf] [-Confirm]
```

- `-DryRun`: Simulate and show what would be deleted without removing files
- `-MinAgeHours <int>`: Only delete files older than this many hours (default 24)
- `-NoEmoji`: Force ASCII-only output
- `-WhatIf`: Native PowerShell preview (equivalent to DryRun for deletions)
- `-Confirm`: Prompt before deleting

### Examples

```powershell
# Show what would be removed, in ASCII-only
.\clean.ps1 -DryRun -NoEmoji

# Be a bit more aggressive: files older than 6 hours
.\clean.ps1 -MinAgeHours 6

# Use native WhatIf
.\clean.ps1 -WhatIf

# Ask for confirmation per operation
.\clean.ps1 -Confirm
```

## Encoding Notes (mojibake fixes)

If you saw garbled characters like `âœ¨` or `ðŸ§‘`, your console wasn’t decoding UTF‑8.

- The script auto-falls back to ASCII on Windows PowerShell 5.1.
- On PowerShell 7+ (UTF‑8 consoles) you’ll get emoji automatically.
- You can always force ASCII with `-NoEmoji`.

## Schedule (Optional)

You can run this weekly via Windows Task Scheduler:

1. Create Basic Task → Name: PrettyClean
2. Trigger: Weekly
3. Action: Start a Program
4. Program/script: `powershell.exe`
5. Add arguments: `-ExecutionPolicy Bypass -File "D:\GIthubRepo\junk-Cleaner-Script\clean.ps1"`

## Notes

- Recycle Bin (current user) is emptied during cleanup.
- The script respects PowerShell’s `-WhatIf`/`-Confirm` via `SupportsShouldProcess`.
- No admin elevation is required.
