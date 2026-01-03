README_SIMPLE (v14.1 Backup / v16.9 QA Build)

BACKUP MODES:
[1] FASTBOOT only (~1-2 GB) - Boot-critical files only
[2] FASTBOOT + WINCORE (~8-12 GB) - Enhanced OS recovery (recommended)
    - Automatically uses VSS (Volume Shadow Copy) when available
    - Falls back to live filesystem if VSS unavailable

FAST RECOVERY (Recommended) [cite: 1, 10]
1) Boot into Windows Recovery (WinRE Command Prompt). [cite: 1, 10]
2) Run: G:\MIRACLE_BOOT_FIXER\miracle_boot_restore_fast_v10.cmd [cite: 2, 13]
3) Verify your Windows Drive letter (WinRE letters shift!). [cite: 2, 13]
4) If WINCORE payload detected, confirm restore (default: N). [cite: 2, 13]

MODERN HARDWARE (Intel VMD / NVMe) [cite: 3, 11]
- v16.9 detects Intel VMD (iaStorVD) and NVMe drivers specifically. [cite: 3, 11]
- If you switched BIOS storage modes (AHCI <-> RAID/VMD), the diagnostic will tell you if the drivers are missing (0x7B error). [cite: 4, 11]

UNIFIED SCORING [cite: 5]
- Option 1 (Scan All) and Option 2 (Specific Folder) now result in the EXACT same score for the same backup. [cite: 5, 10]
- Logic inconsistency has been fixed. [cite: 6, 10]
- WINCORE Payload: +10% OS Integrity Confidence boost if detected. [cite: 5, 10]

SURGICAL REPAIR TOOLS (QACursor.cmd Option 4)
- EFI + BCD Reconstruction: Rebuilds boot configuration (bcdboot)
- File System Repair: Schedules chkdsk /f /r for next reboot
- Offline System File Check: SFC /scannow on offline drives
- DISM Cleanup: Reverts pending Windows Update actions
- Run All Repairs: Executes all repairs sequentially

DIAG CODES:
- OK: Component verified. [cite: 6]
- WARN: Component exists but volume/config may be generic. [cite: 6]
- FAIL: Critical component missing (Boot likely to fail). [cite: 7]
- UNKNOWN: Registry locked; check if winload.efi exists for partial credit. [cite: 7]

CRITICAL: FIXING 0x7B (INACCESSIBLE_BOOT_DEVICE)
If the script finishes but Windows won't start, run this manual command:
> dism /Image:C:\ /Add-Driver /Driver:"BACKUP_PATH\Drivers" /Recurse 

Or use QACursor.cmd Option 4 (Surgical Repair) for automated fixes.

VSS (VOLUME SHADOW COPY) SUPPORT
- Automatically attempted for WINCORE backups
- Creates snapshot for cleaner backup of in-use files
- Falls back to live filesystem if VSS unavailable
- Automatic cleanup after backup completes

WINPE COMPATIBILITY
- All scripts tested and hardened for WinPE/WinRE
- Robust fallbacks for unavailable tools
- Parser-safe batch scripting throughout
- No hanging operations (all diskpart scripts include exit)
