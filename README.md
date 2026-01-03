# Miracle Boot Fixer v14.1 / QA v16.9

A surgical Windows boot repair toolkit with enhanced recovery capabilities. This build features **Nuclear-Hardened** backup scripts and a **Forensic Master** QA system with comprehensive repair tools.

## ✨ Features

### 💾 Backup System (miracle_boot_backup_fast_v10.cmd v14.1)
- **WinPE Compatible**: Works in both full Windows and WinPE/WinRE environments
- **Two Backup Tiers**:
  - **FASTBOOT** (Default, ~1-2 GB): Boot-critical components only
  - **FASTBOOT + WINCORE** (Recommended, ~8-12 GB): Enhanced OS recovery capability
- **VSS Support**: Automatic Volume Shadow Copy for cleaner live backups (WINCORE mode)
- **BitLocker Detection**: Automatic detection and warnings
- **Robust Error Handling**: Parser-safe batch scripting, no hanging diskpart operations
- **Timestamp Generation**: PowerShell-first with WMIC fallback

### 🔍 Unified Boot Diagnostic (QACursor.cmd v16.9)
- **Unified Logic**: Option 1 (Scan All) and Option 2 (Single Folder) share the same validation engine
- **Driver Sense Engine**: Automatic detection for **Intel VMD**, **NVMe**, and **SATA**
- **Context-Aware Verification**: Distinguishes between configuration errors and locked system files
- **Boot-Proven Logic**: Active OS drives receive automatic driver validation

### 🛠️ Surgical Repair Tools (QACursor.cmd)
- **EFI + BCD Reconstruction**: Rebuilds boot configuration
- **File System Repair**: Schedules chkdsk /f /r for next reboot
- **Offline System File Check**: SFC /scannow on offline drives
- **DISM Cleanup**: Reverts pending Windows Update actions
- **Run All Repairs**: Sequential execution of all repair operations

### 🛡️ WINCORE Payload (Tier 2 - Optional)
- **Enhanced OS Recovery**: Backs up critical Windows system folders (System32, SysWOW64, Boot, Drivers, INF, servicing)
- **Size**: ~8-12 GB (compared to FASTBOOT ~1-2 GB)
- **Purpose**: OS survivability without full Windows backup. Focuses on system files, not user data
- **VSS Integration**: Uses Volume Shadow Copy when available for cleaner backups of in-use files
- **Optional**: Default is FASTBOOT only. WINCORE can be enabled during backup for enhanced recovery capability

## 📊 Diagnostic Scoring (100% Base + 10% WINCORE Bonus)
| Component | Weight | Check Method |
|-----------|--------|--------------|
| **Disk Map** | 20% | Verified via DiskPart_Direct |
| **ESP Detection**| 20% | "System" Partition Type check |
| **EFI Files** | 20% | `bootmgfw.efi` presence |
| **BCD Pointer** | 20% | osdevice partition matching |
| **winload.efi** | 10% | Presence in System32 |
| **Storage Drivers**| 10% | Intel VMD/NVMe Sense |
| **WINCORE Payload**| +10% | `WIN_CORE\SYSTEM32\ntoskrnl.exe` presence (bonus) |

## 🚀 Quick Start

### Backup (from Windows, Admin)
1. Run `miracle_boot_backup_fast_v10.cmd` as Administrator
2. Select backup mode:
   - `[1]` FASTBOOT only (faster, ~1-2 GB)
   - `[2]` FASTBOOT + WINCORE (recommended, ~8-12 GB)
3. Backup completes with timestamped folder

### Restore (from WinRE / Windows USB command prompt)
1. Run `miracle_boot_restore_fast_v10.cmd`
2. Verify your Windows Drive letter (WinRE letters shift!)
3. If WINCORE payload detected, confirm restore (default: N)
4. Restore completes surgically without wiping data

### Diagnostic & Repair (from Windows, Admin)
1. Run `QACursor.cmd` as Administrator
2. Select option:
   - `[1]` Scan all backup folders
   - `[2]` Validate specific backup folder
   - `[3]` Live diagnostic (deep boot validation)
   - `[4]` Surgical repair (EFI + BCD + chkdsk + SFC + DISM)
3. Review results and apply repairs as needed

## 📁 Folder Structure

```
<YYYY-MM-dd_HH-mm-ss>_FASTBOOT_<DriveLetter>\
  EFI\                          (UEFI boot files from ESP)
  BCD_Backup                     (exported boot configuration)
  Hives\                         (SYSTEM, SOFTWARE registry hives)
  Drivers\                       (pnputil exported 3rd-party drivers)
  Metadata\                      (Disk_ID.txt, Disk_Info.txt, Robocopy_EFI.log)
  LOGS\                          (command logs including wincore_backup.log if WINCORE enabled)
  
  WIN_CORE\                      (WINCORE payload - only if option 2 selected)
    SYSTEM32\                     (Windows System32, excludes LogFiles)
    SYSWOW64\                     (Windows SysWOW64)
    BOOT\                         (Windows Boot folder)
    DRIVERS\                      (Windows System32\drivers)
    INF\                          (Windows INF folder)
    SERVICING\                    (Windows servicing, excludes Logs/Temp)
```

## 🔧 Advanced Features

### VSS (Volume Shadow Copy Service)
- Automatically attempts to create shadow copy for WINCORE backups
- Falls back to live filesystem if VSS unavailable
- Ensures cleaner backups of in-use files
- Automatic cleanup after backup completes

### WinPE Compatibility
- All scripts tested and hardened for WinPE/WinRE environments
- Robust fallbacks for tools unavailable in WinPE
- Safe error handling for all operations

### Parser-Safe Batch Scripting
- All `( ... )` blocks replaced with safe echo patterns
- No hanging diskpart operations (all scripts include `exit`)
- Timeout protection on all diskpart calls
- File existence checks before all for /f loops

## ⚠️ Important Notes

- **WinRE Drive Letters**: Drive letters often differ in WinRE; always pick the drive containing `\Windows`
- **Registry Hive Restore**: ONLY safe offline (WinRE); script will refuse to overwrite live hives
- **FASTBOOT Purpose**: For speed, not for recovering from deep OS corruption; keep a full image backup
- **WINCORE Restore**: Requires explicit confirmation (default: N) to prevent accidental overwrites
- **WINCORE Recommendation**: Optional but recommended for enhanced OS recovery capability
- **chkdsk Scheduling**: File system repair schedules chkdsk for next reboot (does not run immediately)

## 🐛 Troubleshooting

### INACCESSIBLE_BOOT_DEVICE (0x7B)
If the automated restore completes but you still face an `INACCESSIBLE_BOOT_DEVICE` loop, manually inject storage drivers:

```batch
dism /Image:C:\ /Add-Driver /Driver:"G:\MIRACLE_BOOT_FIXER\<Backup_Folder>\Drivers" /Recurse
```

Replace `C:\` with your actual Windows drive letter and `G:\` with your backup drive letter.

### Using Surgical Repair Tools
For persistent boot issues, use QACursor.cmd Option 4 (Surgical Repair):
1. **EFI + BCD Reconstruction**: Rebuilds boot configuration
2. **chkdsk /f /r**: Schedules file system repair for next reboot
3. **Offline SFC**: Scans and repairs system files on offline drive
4. **DISM Cleanup**: Reverts pending Windows Update actions that may cause boot issues

## 📝 Version History

- **v14.1** (Backup): Nuclear-Hardened build with VSS support, WinPE compatibility, parser-safe scripting
- **v16.9** (QA): Forensic Master with unified validation engine and comprehensive repair tools
