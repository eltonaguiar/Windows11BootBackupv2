README_SIMPLE (v16.9 Build)

[cite_start]FAST RECOVERY (Recommended) [cite: 1, 10]
[cite_start]1) Boot into Windows Recovery (WinRE Command Prompt). [cite: 1, 10]
[cite_start]2) Run: G:\MIRACLE_BOOT_FIXER\miracle_boot_restore_fast_v10.cmd [cite: 2, 13]
[cite_start]3) Verify your Windows Drive letter (WinRE letters shift!). [cite: 2, 13]

[cite_start]MODERN HARDWARE (Intel VMD / NVMe) [cite: 3, 11]
- [cite_start]v16.9 detects Intel VMD (iaStorVD) and NVMe drivers specifically. [cite: 3, 11]
- [cite_start]If you switched BIOS storage modes (AHCI <-> RAID/VMD), the diagnostic will tell you if the drivers are missing (0x7B error). [cite: 4, 11]

[cite_start]UNIFIED SCORING [cite: 5]
- [cite_start]Option 1 (Scan All) and Option 2 (Specific Folder) now result in the EXACT same score for the same backup. [cite: 5, 10]
- [cite_start]Logic inconsistency has been fixed. [cite: 6, 10]

DIAG CODES:
- [cite_start]OK: Component verified. [cite: 6]
- [cite_start]WARN: Component exists but volume/config may be generic. [cite: 6]
- [cite_start]FAIL: Critical component missing (Boot likely to fail). [cite: 7]
- [cite_start]UNKNOWN: Registry locked; check if winload.efi exists for partial credit. [cite: 7]