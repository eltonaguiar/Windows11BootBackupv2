PURPOSE (Updated v14.1 / QA v16.9) [cite: 8]

This kit is for surgical repair of Windows boot failures WITHOUT doing a full disk restore. [cite: 8]
Targets problems like:
- INACCESSIBLE_BOOT_DEVICE (0x7B) including Intel VMD/RAID [cite: 9, 11]
- Missing Boot Manager / missing winload.efi [cite: 9]
- EFI / BCD corruption [cite: 9]
- Multi-boot or migration setups (choose C:, E:, etc.) [cite: 9]
- File system corruption (chkdsk repair available)
- System file corruption (SFC repair available)
- Pending Windows Update issues (DISM cleanup available)

It includes two payload tiers:

TIER 1 - FASTBOOT (Default):
- Restores only boot-critical Windows components (boot files, core storage drivers, and registry hives) [cite: 8]
- Does NOT wipe Users / Program Files / data [cite: 8]
- Designed for faster restore times than a full image [cite: 8]
- Size: ~1-2 GB

TIER 2 - WINCORE (Optional, Recommended):
- Backs up critical Windows system folders: System32, SysWOW64, Boot, Drivers, INF, servicing
- Focused on OS survivability, not user data
- Does NOT back up C:\Users or Program Files
- Does NOT include WinSxS, Logs, Temp, SoftwareDistribution, Panther
- Size: ~8-12 GB
- Can be enabled during backup (option 2: FASTBOOT + WINCORE)
- VSS Support: Automatically uses Volume Shadow Copy when available for cleaner backups

FOLDER STRUCTURE (per backup folder) [cite: 10]

<YYYY-MM-dd_HH-mm-ss>_FASTBOOT_<DriveLetter>\
  EFI\
    EFI\...                      (UEFI boot files from the EFI System Partition) [cite: 10]
  BCD_Backup                     (exported boot configuration) [cite: 10]
  Hives\                         (SYSTEM, SOFTWARE registry hives) [cite: 10]
  Drivers\                       (pnputil exported 3rd-party drivers from running OS) [cite: 11]
  Metadata\                      (Disk_ID.txt, Disk_Info.txt, Robocopy_EFI.log) [cite: 10]
  LOGS\                          (command logs including wincore_backup.log if WINCORE enabled) [cite: 10]
  
  WIN_CORE\                      (WINCORE payload - only if option 2 selected) [cite: 10]
    SYSTEM32\                    (Windows System32 folder, excludes LogFiles) [cite: 10]
    SYSWOW64\                    (Windows SysWOW64 folder) [cite: 10]
    BOOT\                        (Windows Boot folder) [cite: 10]
    DRIVERS\                     (Windows System32\drivers folder) [cite: 10]
    INF\                         (Windows INF folder) [cite: 10]
    SERVICING\                   (Windows servicing folder, excludes Logs/Temp) [cite: 10]

USAGE [cite: 13]

Backup (from Windows, Admin): [cite: 13]
- G:\MIRACLE_BOOT_FIXER\miracle_boot_backup_fast_v10.cmd [cite: 13]
- Select mode: [1] FASTBOOT only or [2] FASTBOOT + WINCORE (recommended)
- VSS snapshot automatically attempted for WINCORE backups

Restore (from WinRE / Windows USB command prompt): [cite: 13]
- G:\MIRACLE_BOOT_FIXER\miracle_boot_restore_fast_v10.cmd [cite: 13]
- Follow prompts to select backup folder and target drive
- WINCORE restore requires explicit confirmation (default: N)

Diagnostic & Repair (from Windows, Admin):
- G:\MIRACLE_BOOT_FIXER\QACursor.cmd [cite: 13]
- Option 1: Scan all backup folders
- Option 2: Validate specific backup folder
- Option 3: Live diagnostic (deep boot validation)
- Option 4: Surgical repair menu:
  - [1] EFI + BCD Reconstruction (bcdboot)
  - [2] File System Repair (chkdsk /f /r - schedules for next reboot)
  - [3] Offline System File Check (sfc /scannow)
  - [4] DISM Cleanup (Revert Pending Actions)
  - [5] Run All Repairs (sequential execution)
  - [6] Back to Main Menu

Notes:
- WinRE drive letters often differ; always pick the drive containing \Windows. [cite: 14]
- Registry hive restore is ONLY safe offline (WinRE); script will refuse to overwrite live hives. [cite: 14, 15]
- FASTBOOT is for speed, not for recovering from deep OS corruption; keep a full image backup. [cite: 16]
- WINCORE restore requires explicit confirmation (default: N) to prevent accidental overwrites. [cite: 16]
- WINCORE is optional but recommended for enhanced OS recovery capability. [cite: 16]
- VSS (Volume Shadow Copy) is automatically used when available for cleaner WINCORE backups.
- chkdsk repair schedules the check for next reboot; it does not run immediately.
- All scripts are WinPE-compatible and parser-safe (nuclear-hardened).

TECHNICAL DETAILS

Backup Script (v14.1):
- WinPE Detection: Automatic detection and fallback methods
- BitLocker Detection: Safe one-liner method, no parser errors
- Timestamp Generation: PowerShell-first with WMIC fallback
- Diskpart Operations: All scripts include 'exit', timeout protection
- VSS Integration: Automatic shadow copy creation for WINCORE backups
- Error Handling: Parser-safe batch scripting throughout

QA Script (v16.9):
- Unified Validation Engine: Consistent scoring across all modes
- Driver Sense Engine: Intel VMD, NVMe, SATA detection
- Surgical Repair Tools: Comprehensive repair options
- Error Handling: Robust error checking and user feedback

Restore Script:
- WINCORE Support: Optional restore with confirmation
- Driver Injection: Automatic DISM driver injection
- Safety Checks: Validates target drive before restore
- WinPE Compatible: Works in recovery environments
