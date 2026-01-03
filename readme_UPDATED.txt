PURPOSE (Updated v16.9) [cite: 8]

This kit is for surgical repair of Windows boot failures WITHOUT doing a full disk restore. [cite: 8]
Targets problems like:
- INACCESSIBLE_BOOT_DEVICE (0x7B) including Intel VMD/RAID [cite: 9, 11]
- Missing Boot Manager / missing winload.efi [cite: 9]
- EFI / BCD corruption [cite: 9]
- Multi-boot or migration setups (choose C:, E:, etc.) [cite: 9]

It includes a "FASTBOOT" payload option:
- Restores only boot-critical Windows components (boot files, core storage drivers, and registry hives) [cite: 8]
- Does NOT wipe Users / Program Files / data [cite: 8]
- Designed for faster restore times than a full image [cite: 8]

FOLDER STRUCTURE (per backup folder) [cite: 10]

<YYYY-MM-dd_HH-mm-ss>_FASTBOOT_<DriveLetter>\
  EFI\
    EFI\...                      (UEFI boot files from the EFI System Partition) [cite: 10]
  BCD_EXPORT.bcd                 (exported boot configuration) [cite: 10]
  BCD_ENUM.txt                   (bcdedit /enum all output) [cite: 10]
  DISK_LAYOUT.txt                (diskpart output) [cite: 10]
  LOGS\                          (command logs) [cite: 10]
  DRIVERS_EXPORT\                (pnputil exported 3rd-party drivers from running OS) [cite: 11]

  WIN_BOOT\                      (FASTBOOT payload) [cite: 10]
    HIVES\                       (SYSTEM, SOFTWARE, SAM, SECURITY, DEFAULT) [cite: 10]
    CORE_FILES\                  (core boot files such as winload.efi, ntoskrnl.exe) [cite: 12]
    CORE_DRIVERS\                (core storage + boot-critical drivers) [cite: 10]
    DRIVERSTORE_STORAGE\         (storage-related FileRepository packages; best-effort) [cite: 13]

USAGE [cite: 13]

Backup (from Windows, Admin): [cite: 13]
- G:\MIRACLE_BOOT_FIXER\miracle_boot_backup_fast_v10.cmd [cite: 13]

Restore (from WinRE / Windows USB command prompt): [cite: 13]
- G:\MIRACLE_BOOT_FIXER\miracle_boot_restore_fast_v10.cmd [cite: 13]

Notes:
- WinRE drive letters often differ; always pick the drive containing \Windows. [cite: 14]
- Registry hive restore is ONLY safe offline (WinRE); script will refuse to overwrite live hives. [cite: 14, 15]
- FASTBOOT is for speed, not for recovering from deep OS corruption; keep a full image backup. [cite: 16]