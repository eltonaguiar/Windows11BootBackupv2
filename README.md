# Miracle Boot Fixer v16.9

A surgical Windows boot repair toolkit. This build features the **Unified Validation Engine** to ensure scoring consistency across all diagnostic modes.
Windows 11 "Startup repair" failed me during a BOOT_DEVICE_INACCESSIBLE.
I didn't want to re-install windows and lose all my app shortcuts, and/or have to reinstall & configure everything again.
An "image" is ideal, but in cases of a minor crash of the "boot stuff" I figured there should be a way to do a "fast boot stuff restore" ..

I havent tried this out, in terms of the restore, but the other components have been tested and seems to work.

## ✨ Features

### 🔍 Unified Boot Diagnostic (QACursor.cmd)
- [cite_start]**Unified Logic**: Option 1 (Scan) and Option 2 (Single Folder) now share the same validation engine[cite: 10].
- [cite_start]**Driver Sense Engine**: Automatic detection for **Intel VMD**, **NVMe**, and **SATA**[cite: 11].
- **Context-Aware Verification**: Distinguishes between configuration errors and locked system files.
- [cite_start]**Boot-Proven Logic**: Active OS drives receive automatic driver validation[cite: 8].

### 💾 Fast Recovery (FASTBOOT)
- [cite_start]Restores boot-critical components (files, drivers, registry hives) without wiping user data[cite: 1, 5].
- [cite_start]**Driver Injection**: DISM integration for injecting storage drivers into offline OS[cite: 12].

## 📊 Diagnostic Scoring (100% Total)
| Component | Weight | Check Method |
|-----------|--------|--------------|
| **Disk Map** | 20% | Verified via DiskPart_Direct |
| **ESP Detection**| 20% | "System" Partition Type check |
| **EFI Files** | 20% | `bootmgfw.efi` presence |
| **BCD Pointer** | 20% | osdevice partition matching |
| **winload.efi** | 10% | Presence in System32 |
| **Storage Drivers**| 10% | Intel VMD/NVMe Sense |

## 🚀 Quick Start
1. Run `QACursor.cmd` as Admin.
2. Select **Option 3** for Live Diagnostic.
3. Review results: **RED / YELLOW / GREEN**.
--------

If the automated restore completes but you still face an `INACCESSIBLE_BOOT_DEVICE` loop, you must manually force the storage drivers into the Windows image using DISM from your WinPE/Recovery command prompt:

```batch
dism /Image:C:\ /Add-Driver /Driver:"G:\MIRACLE_BOOT_FIXER\<Backup_Folder>\Drivers" /Recurse

Note: Replace C:\ with your actual Windows drive letter and G:\ with your backup drive letter.




sample outputs
QA FILE:

option 1
===========================================================================
        BACKUP FORENSICS - COMPREHENSIVE VALIDATION (Unified)
===========================================================================

[BACKUP #1]: 2026-01-03_16-00_NUCLEAR_C
---------------------------------------------------------------------------
   [OK] bootmgfw.efi [+20]
   [OK] bootmgr.efi [+5]
   [OK] bootx64.efi [+5]
   [OK] EFI BCD [+10]
   [OK] BCD_Backup Valid [+20]
   [OK] SYSTEM Hive [+10]
   [OK] SOFTWARE Hive [+10]
---------------------------------------------------------------------------
FINAL SCORE: 88 / 100
[STATUS]: RESTORE-READY

Press any key to continue . . .



QA File
option 2,1 (1st backup)

Validating: 2026-01-03_16-00_NUCLEAR_C
---------------------------------------------------------------------------
   [OK] bootmgfw.efi [+20]
   [OK] bootmgr.efi [+5]
   [OK] bootx64.efi [+5]
   [OK] EFI BCD [+10]
   [OK] BCD_Backup Valid [+20]
   [OK] SYSTEM Hive [+10]
   [OK] SOFTWARE Hive [+10]
---------------------------------------------------------------------------
FINAL SCORE: 88 / 100
[STATUS]: RESTORE-READY
Press any key to continue . . .




Qa file option 3,ENTER(all Drives),it tries to get a boot probability.. something seems off with the probabilities as windows literally booted into C drive..
DRIVE  EFI-PATH   BCD-POINTER   WINLOAD  DRIVERS  STATUS (SCORE)
---------------------------------------------------------------------------
C:      FAIL", "BC=FAIL", "WL=--", "DS=UNKNOWN", "D_TYPE=NONE                   OK       OK    YELLOW (60%)
E:      FAIL", "BC=FAIL", "WL=--", "DS=UNKNOWN", "D_TYPE=NONE                   OK       OK    RED (40%)
---------------------------------------------------------------------------
Quick Table:
C: --> for "C:" is "Eltons_NVME_MAIN" --> 60% [IntelVMD]
D: --> [No OS] --> 0% [No Windows Folder]
E: --> for "E:" is "EltonsMainC_OLD" --> 40% [IntelVMD]
F: --> [No OS] --> 0% [No Windows Folder]
G: --> [No OS] --> 0% [No Windows Folder]
Press any key to continue . . .

QA file option 4 actually messes with the EFI/BCD , so not recommended to run that for testing purposes.






