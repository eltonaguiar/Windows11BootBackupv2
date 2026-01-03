PURPOSE (Updated)

This kit is for surgical repair of Windows boot failures WITHOUT doing a full disk restore.

Targets problems like:
- INACCESSIBLE_BOOT_DEVICE (0x7B)
- Missing Boot Manager / missing winload.efi
- EFI / BCD corruption
- Multi-boot or migration setups (choose C:, E:, etc.)

It includes a "FASTBOOT" payload option:
- Restores only boot-critical Windows components (boot files, core storage drivers, and registry hives)
- Does NOT wipe Users / Program Files / data
- Designed for faster restore times than a full image

FOLDER STRUCTURE (per backup folder)

<YYYY-MM-dd_HH-mm-ss>_FASTBOOT_<DriveLetter>\
  EFI\
    EFI\...                      (UEFI boot files from the EFI System Partition)
  BCD_EXPORT.bcd                  (exported boot configuration)
  BCD_ENUM.txt                    (bcdedit /enum all output)
  DISK_LAYOUT.txt                 (diskpart output)
  LOGS\                          (command logs)
  DRIVERS_EXPORT\                (pnputil exported 3rd-party drivers from running OS)

  WIN_BOOT\                      (FASTBOOT payload)
    HIVES\
      SYSTEM
      SOFTWARE
      SAM (optional)
      SECURITY (optional)
      DEFAULT (optional)
    CORE_FILES\                  (core boot files such as winload.efi, ntoskrnl.exe)
    CORE_DRIVERS\                (core storage + boot-critical drivers)
    DRIVERSTORE_STORAGE\         (storage-related FileRepository packages; best-effort)

USAGE

Backup (from Windows, Admin):
- G:\MIRACLE_BOOT_FIXER\miracle_boot_backup_fast_v8.cmd

Restore (from WinRE / Windows USB command prompt):
- G:\MIRACLE_BOOT_FIXER\miracle_boot_restore_fast_v8.cmd

Notes:
- WinRE drive letters often differ. Always pick the drive that actually contains \Windows.
- Registry hive restore is ONLY safe offline (WinRE). The restore script will refuse to overwrite hives on the live OS.
- Keep a FULL image backup too. FASTBOOT is for speed, not for recovering from deep OS corruption.
