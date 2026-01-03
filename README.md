# Miracle Boot Fixer v16.9

A surgical Windows boot repair toolkit. This build features the **Unified Validation Engine** to ensure scoring consistency across all diagnostic modes.

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