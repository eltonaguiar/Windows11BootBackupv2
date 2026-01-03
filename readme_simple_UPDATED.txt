README_SIMPLE (Updated)

FAST RECOVERY (Recommended)
1) Boot into Windows Recovery:
   - Windows USB -> Repair -> Troubleshoot -> Advanced -> Command Prompt

2) Run the restore script:
   - G:\MIRACLE_BOOT_FIXER\miracle_boot_restore_fast_v8.cmd

3) When prompted:
   - Enter the Windows drive letter to fix (WinRE letters can differ from normal Windows)
   - Use the latest backup (default) unless you know you need an older one
   - Optionally restore the FASTBOOT payload (core files/drivers/hives)

CRITICAL FOR NVMe / STORAGE MODE CHANGES
- If you moved from SATA -> NVMe, or changed BIOS storage mode (AHCI <-> RAID/VMD),
  you may hit INACCESSIBLE_BOOT_DEVICE.
- In that case you MUST inject storage drivers (offline) or restore a FASTBOOT payload.
  The restore script can:
    - copy storage DriverStore packages (best-effort)
    - inject exported drivers with DISM (you can also do it manually)

QUICK QA / DIAG
- Run QA.cmd to sanity check your newest backup + estimate if a target drive will boot.
