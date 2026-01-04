@echo off
setlocal EnableExtensions EnableDelayedExpansion
:: =============================================================================
:: MIRACLE BOOT RESTORE v25.3 - [ABSOLUTE COMPONENT INJECTION + DISM FORCE]
:: =============================================================================
title Miracle Boot Restore v25.3 - Forensic Master [STABLE]

set "CV=25.3"
echo ===========================================================================
echo    MIRACLE BOOT RESTORE v25.3 - [INJECTION ENGINE ONLINE]
echo ===========================================================================
echo [*] CURRENT VERSION: !CV!
echo [*] STATUS: Absolute Path Injection Active (Fixing Generic BCD Boot Bug)

:: 1. AUTO-NETWORKING
X:\Windows\System32\wpeutil.exe InitializeNetwork >nul 2>&1

:: 2. DYNAMIC TOOL DISCOVERY
set "TARGET=C"
for %%D in (C D E F G) do if exist "%%D:\Windows\System32\winload.efi" set "TARGET=%%D"
set "SYS=!TARGET!:\Windows\System32"
set "DPART=!SYS!\diskpart.exe"
set "BCDB=!SYS!\bcdboot.exe"
set "RBCP=!SYS!\robocopy.exe"
set "DISM=!SYS!\dism.exe"

:: =============================================================================
:: 3. BACKUP IDENTIFICATION (Locked to your timestamp)
:: =============================================================================
set "BKP=C:\MIRACLE_BOOT_FIXER\2026-01-03_19-28_FASTBOOT_C"

echo [AUDIT] VERIFYING SPECIFIC BACKUP: !BKP!
if not exist "!BKP!" (
    echo [!] ERROR: Backup folder !BKP! not found. Check drive mapping.
    pause & exit /b 1
)

:: Forensic Verification
set "E_EFI=[MISSING]" & if exist "!BKP!\EFI" set "E_EFI=[FOUND]  "
set "E_REG=[MISSING]" & if exist "!BKP!\Hives\SYSTEM" set "E_REG=[FOUND]  "
set "E_CORE=[MISSING]" & if exist "!BKP!\WIN_CORE\SYSTEM32\ntoskrnl.exe" set "E_CORE=[FOUND]  "

echo !E_EFI! EFI Boot Structure
echo !E_REG! Registry System Hive (with Drivers)
echo !E_CORE! WIN_CORE Payload

:: =============================================================================
:: 4. RESTORE & REPAIR MENU
:: =============================================================================
:MENU_TOP
echo.
echo ===========================================================================
echo    MIRACLE BOOT RESTORE v25.3 - TARGET DISK: 3 
echo ===========================================================================
echo [1] FASTBOOT RESTORE (EFI + BCD ONLY)
echo [2] NUCLEAR RESTORE (EFI + REG + WIN_CORE INJECTION)
echo [3] BRIDGED REPAIR  (FORCE REVERT PENDING ACTIONS)
echo [4] EXIT
echo.
set /p "USER_CHOICE=SELECT MODE (1-4): "

if "!USER_CHOICE!"=="1" set "MODE_STR=FASTBOOT" & goto :MODE_CONFIRMED
if "!USER_CHOICE!"=="2" set "MODE_STR=NUCLEAR" & goto :MODE_CONFIRMED
if "!USER_CHOICE!"=="3" goto :REPAIR_FORCE
if "!USER_CHOICE!"=="4" exit /b
goto :MENU_TOP

:: =============================================================================
:: 5. FORCE REPAIR LOGIC (Fixing Error 0xd000012d)
:: =============================================================================
:REPAIR_FORCE
echo.
set "SD=!TARGET!:\_SCRATCH"
if not exist "!SD!" mkdir "!SD!"
echo [*] Executing Forced Revert via !SD!...
!DISM! /Image:!TARGET!:\ /ScratchDir:!SD! /Cleanup-Image /RevertPendingActions
pause & goto :MENU_TOP

:: =============================================================================
:: 6. RESTORE LOGIC (Absolute Path Corrected)
:: =============================================================================
:MODE_CONFIRMED
echo.
echo [!] STARTING !MODE_STR! RESTORE CYCLE FROM !BKP!...
set "MNT=S"
mountvol !MNT!: /d >nul 2>&1
(echo select disk 3 ^& echo select partition 1 ^& echo assign letter=!MNT!) | !DPART! >nul 2>&1

if "!USER_CHOICE!"=="2" (
    echo [*] Injecting WIN_CORE Files (Drivers/System)...
    !RBCP! "!BKP!\WIN_CORE\SYSTEM32" "!TARGET!:\Windows\System32" /E /B /R:1 /W:1 /NP >nul
    echo [*] Swapping System Registry Hive...
    ren "!TARGET!:\Windows\System32\config\SYSTEM" "SYSTEM.old_%random%" >nul 2>&1
    copy /y "!BKP!\Hives\SYSTEM" "!TARGET!:\Windows\System32\config\SYSTEM" >nul
)

:: EFI Reconstruction
echo [*] Restoring EFI Structure...
!RBCP! "!BKP!\EFI" "!MNT!:\EFI" /E /R:1 /W:1 /NP >nul
echo [*] Rebuilding BCD Store (Targeting !TARGET!:\Windows)...
!BCDB! !TARGET!:\Windows /s !MNT!: /f UEFI >nul

mountvol !MNT!: /d >nul 2>&1
echo ===========================================================================
echo [FINISHED] v25.3 !MODE_STR! Restore Complete.
echo ===========================================================================
pause & goto :MENU_TOP