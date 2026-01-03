# Miracle Boot Fixer

A comprehensive Windows boot repair toolkit for surgical repair of boot failures without full disk restore. Includes advanced diagnostic tools and fast recovery options.
This has yet to "save" someone from windows dying on them.. but lets see what happens .

## 🎯 Purpose

This kit targets common Windows boot failures:
- `INACCESSIBLE_BOOT_DEVICE` (0x7B)
- Missing Boot Manager / missing `winload.efi`
- EFI / BCD corruption
- Multi-boot or migration setups
- Storage driver issues (NVMe, SATA, RAID mode changes)

## ✨ Features

### 🔍 Advanced Boot Diagnostic (QACursor.cmd)
- **Live diagnostic analysis** of boot integrity
- **Boot probability scoring** (0-100%) with detailed evidence breakdown
- **Context-aware driver verification** (distinguishes FAIL, UNKNOWN, and OK states)
- **Root cause analysis** with fix commands
- **Multi-drive support** (single, multiple, or all drives A-Z)
- **Live OS detection** (uses live registry for currently running Windows)
- **Storage type detection** (NVMe, SATA, RAID) via BusType
- **Boot-proven logic** (if system is running, drivers verified as OK)

### 💾 Fast Recovery (FASTBOOT)
- Restores only boot-critical components (boot files, drivers, registry hives)
- **Does NOT wipe** Users / Program Files / data
- Faster restore times than full image restore
- Safe offline registry hive restore

## 📁 Folder Structure

```
MIRACLE_BOOT_FIXER/
├── QACursor.cmd                          # Advanced boot diagnostic tool
├── miracle_boot_backup_fast_v10.cmd      # FASTBOOT backup script
├── miracle_boot_restore_fast_v10.cmd     # FASTBOOT restore script
└── <backup_folder>/
    └── <YYYY-MM-dd_HH-mm-ss>_FASTBOOT_<DriveLetter>/
        ├── EFI/                          # UEFI boot files from ESP
        ├── BCD_EXPORT.bcd                # Exported boot configuration
        ├── BCD_ENUM.txt                  # bcdedit /enum all output
        ├── DISK_LAYOUT.txt               # diskpart output
        ├── LOGS/                         # Command logs
        ├── DRIVERS_EXPORT/               # Exported 3rd-party drivers
        └── WIN_BOOT/                     # FASTBOOT payload
            ├── HIVES/                    # Registry hives (SYSTEM, SOFTWARE, etc.)
            ├── CORE_FILES/               # Core boot files (winload.efi, ntoskrnl.exe)
            ├── CORE_DRIVERS/             # Boot-critical drivers
            └── DRIVERSTORE_STORAGE/      # Storage-related FileRepository packages
```

## 🚀 Quick Start

### Diagnostic (Recommended First Step)

```cmd
# Run from Windows (Admin) or WinRE command prompt
QACursor.cmd
```

1. Choose **Option 2: LIVE DIAGNOSTIC**
2. Enter drive letter(s):
   - Single drive: `C`
   - Multiple drives: `C D E`
   - All drives: Press Enter
3. Review results:
   - Boot Probability Score (0-100%)
   - Evidence breakdown
   - Root cause analysis with fix commands

### Backup (Before Problems Occur)

```cmd
# Run from Windows (Admin)
miracle_boot_backup_fast_v10.cmd
```

### Restore (From WinRE)

```cmd
# Boot into Windows Recovery:
# Windows USB -> Repair -> Troubleshoot -> Advanced -> Command Prompt

miracle_boot_restore_fast_v10.cmd
```

## 📊 QACursor.cmd - Boot Integrity Checks

The diagnostic tool evaluates 6 key components:

| Component | Weight | Description |
|-----------|--------|-------------|
| **Disk Mapping** | 25% | Verifies drive can be mapped to physical disk |
| **EFI System Partition** | 20% | Checks for ESP partition |
| **EFI Files** | 20% | Verifies `bootmgfw.efi` exists in ESP |
| **BCD Pointer** | 20% | Confirms BCD points to correct partition |
| **winload.efi** | 10% | Verifies Windows bootloader exists |
| **Storage Drivers** | 5% | Validates boot-critical storage drivers |

### Driver Verification Features

- **Live OS**: Uses live registry and verifies drivers are actually loaded/running
- **Offline Drives**: Checks registry configuration and driver file existence
- **Context-Aware**: Distinguishes between:
  - `FAIL` - Wrong configuration (missing file, wrong Start value)
  - `UNKNOWN` - Cannot verify (hive locked/inaccessible) - gets partial credit
  - `OK` - Verified correct - gets full credit
- **Storage-Aware**: Detects NVMe, SATA, or RAID and checks appropriate drivers
- **Boot-Proven**: If system is currently running from a drive, marks drivers as OK

### Example Output

```
===========================================================================
DRIVE  EFI-PATH   BCD-POINTER   WINLOAD  DRIVERS  STATUS (SCORE)
---------------------------------------------------------------------------
C:     OK        OK         OK      OK    GREEN (100%)
     [PERFECT] Full boot integrity confirmed.

E:     FAIL        FAIL         OK      OK    RED (40%)
     [Issues]:  [NO_ESP]
     
     Why not 100%? Missing 60% points:
       - ESP: Missing 20 points
         [ROOT CAUSE] No EFI System Partition found on disk.
         [FIX] Run: diskpart > list disk > select disk X > create partition efi size=100
       - EFI files: Missing 20 points
         [ROOT CAUSE] bootmgfw.efi missing from ESP\EFI\Microsoft\Boot\
         [FIX] Run: bcdboot E:\Windows /f UEFI
       - BCD pointer: Missing 20 points
         [ROOT CAUSE] BCD does not point to this drive partition.
         [FIX] Run: bcdboot E:\Windows /f UEFI
```

## 🔧 Technical Details

### Boot Integrity Scoring

The tool uses a weighted scoring system:
- **100%** = All checks passed - boot should succeed
- **90-99%** = Minor issues (typically driver warnings)
- **50-89%** = Moderate issues (missing components)
- **0-49%** = Critical issues (boot will likely fail)

### Verification Coverage

Separate from boot probability, the tool also reports **Verification Coverage**:
- Indicates how much of the system could be verified
- Decreases when checks can't be performed (e.g., locked hives)
- Helps distinguish between "everything is OK" vs "can't verify but looks OK"

### Storage Type Detection

Automatically detects storage controller type:
- **NVMe** (BusType 17): Checks `stornvme` driver
- **SATA/AHCI** (BusType 3): Checks `storahci` driver
- **RAID** (BusType 11): Checks `iaStorVD`, `iaStorAC`, `storahci`
- **Generic**: Falls back to `storahci`, `storport`

## ⚠️ Important Notes

1. **WinRE Drive Letters**: Drive letters in WinRE often differ from normal Windows. Always verify the drive contains `\Windows` before restoring.

2. **Registry Hive Restore**: Registry hive restore is **ONLY safe offline** (WinRE). The restore script will refuse to overwrite hives on the live OS.

3. **Full Backup**: Keep a **FULL image backup** too. FASTBOOT is for speed, not for recovering from deep OS corruption.

4. **Storage Mode Changes**: If you moved from SATA → NVMe or changed BIOS storage mode (AHCI ↔ RAID/VMD), you may hit `INACCESSIBLE_BOOT_DEVICE`. QACursor.cmd will detect this and verify appropriate drivers are present.

## 🛠️ Requirements

- **Windows 10/11** (UEFI boot)
- **Administrator privileges** (for backup and diagnostic)
- **WinRE or Windows USB** (for restore operations)
- **PowerShell** (for storage detection - included in Windows)

## 📝 Usage Examples

### Check Single Drive
```cmd
QACursor.cmd
# Option 2
# Enter: C
```

### Check Multiple Drives
```cmd
QACursor.cmd
# Option 2
# Enter: C D E
```

### Check All Drives
```cmd
QACursor.cmd
# Option 2
# Press Enter (no input)
```

### Backup Current System
```cmd
miracle_boot_backup_fast_v10.cmd
# Follow prompts to select drive and backup location
```

### Restore from WinRE
```cmd
# Boot from Windows USB
# Navigate to Troubleshoot > Advanced > Command Prompt
miracle_boot_restore_fast_v10.cmd
# Enter drive letter (may differ from normal Windows)
# Select backup to restore
```

## 🐛 Troubleshooting

### "The syntax of the command is incorrect"
- Ensure you're running from a proper command prompt (not PowerShell ISE)
- Check that drive letters are valid (A-Z)

### "Cannot load SYSTEM hive"
- For live OS: This is expected - tool uses live registry instead
- For offline drives: Hive may be locked by AV or other processes

### "No EFI System Partition found"
- Drive may be using legacy BIOS boot (not UEFI)
- ESP may be on a different disk
- Use `diskpart` to create ESP if missing

### Low Boot Probability Score
- Check the "Why not 100%?" section for specific issues
- Follow the provided fix commands
- Verify all components are present before attempting boot

## 📄 License

This toolkit is provided as-is for boot repair purposes. Use at your own risk.

## 🤝 Contributing

Improvements and bug fixes welcome! Please test thoroughly before submitting.

## ⚡ Quick Reference

| Task | Script | Run From |
|------|--------|----------|
| Diagnose boot issues | `QACursor.cmd` | Windows (Admin) or WinRE |
| Backup boot components | `miracle_boot_backup_fast_v10.cmd` | Windows (Admin) |
| Restore boot components | `miracle_boot_restore_fast_v10.cmd` | WinRE or Windows USB |

---

**Remember**: Always keep full system backups. This toolkit is for boot repair, not data recovery.


