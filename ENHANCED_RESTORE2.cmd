@echo off
setlocal EnableExtensions EnableDelayedExpansion
:: =============================================================================
:: MIRACLE BOOT RESTORE v23.7 - [SFC/DISM REPAIR + BOOT PROMOTION]
:: =============================================================================
title Miracle Boot Restore v23.7 - Forensic Audit [STABLE]

set "CV=23.7"
echo ===========================================================================
echo    MIRACLE BOOT RESTORE v23.7 - [SYSTEM REPAIR ONLINE]
echo ===========================================================================
echo [*] CURRENT VERSION: !CV!
echo [*] STATUS: Offline DISM/SFC Repair Mode Active

:: 1. AUTO-NETWORKING
X:\Windows\System32\wpeutil.exe InitializeNetwork >nul 2>&1

:: 2. DYNAMIC TOOL DISCOVERY
set "SYS=C:\Windows\System32"
if not exist !SYS!\diskpart.exe set "SYS=X:\Windows\System32"
set "DPART=!SYS!\diskpart.exe"
set "RBCP=!SYS!\robocopy.exe"
set "BCDB=!SYS!\bcdboot.exe"
set "BCDE=!SYS!\bcdedit.exe"
set "DISM=!SYS!\dism.exe"
set "SFC=!SYS!\sfc.exe"
set "CURL=!SYS!\curl.exe"

:: =============================================================================
:: 3. AUDIT & TARGET LOCK
:: =============================================================================
set "TARGET=C"
set "BKP=C:\MIRACLE_BOOT_FIXER\2026-01-03_23-05_FASTBOOT_C"

if not exist "!BKP!" echo [!] ERROR: Backup folder not found! & pause & exit /b 1

set "E_EFI=MISSING" & if exist "!BKP!\EFI" set "E_EFI=FOUND"
set "E_REG=MISSING" & if exist "!BKP!\Hives\SYSTEM" set "E_REG=FOUND"
set "E_CORE=MISSING" & if exist "!BKP!\WIN_CORE\SYSTEM32\ntoskrnl.exe" set "E_CORE=FOUND"

:: Map Disk via Serial Match (8E6B-97D5)
set "TDNUM=3"

:: =============================================================================
:: 4. MANDATORY RESTORE MENU
:: =============================================================================
:MENU_TOP
cls
echo ===========================================================================
echo    MIRACLE BOOT RESTORE v23.7 - TARGET DISK: !TDNUM! 
echo ===========================================================================
echo [1] FASTBOOT RESTORE (EFI + BCD ONLY)
echo [2] NUCLEAR RESTORE (EFI + REG + WIN_CORE)
echo [3] FORENSIC REPAIR (OFFLINE SFC + DISM)
echo.
set "USER_CHOICE="
set /p "USER_CHOICE=SELECT MODE (1, 2, OR 3): "

if "!USER_CHOICE!"=="1" set "MODE_STR=FASTBOOT" & goto :MODE_CONFIRMED
if "!USER_CHOICE!"=="2" set "MODE_STR=NUCLEAR" & goto :MODE_CONFIRMED
if "!USER_CHOICE!"=="3" set "MODE_STR=REPAIR" & goto :REPAIR_CYCLE
goto :MENU_TOP

:: =============================================================================
:: 5. FORENSIC REPAIR CYCLE (SFC / DISM)
:: =============================================================================
:REPAIR_CYCLE
echo.
echo [*] STARTING OFFLINE SYSTEM REPAIR...
echo [*] Running DISM Revert Pending Actions...
!DISM! /Image:!TARGET!:\ /Cleanup-Image /RevertPendingActions >nul 2>&1
echo [*] Running SFC Scannow (Offline Mode)...
!SFC! /Scannow /OffBootDir=!TARGET!:\ /OffWinDir=!TARGET!:\Windows
echo [*] Running DISM Component Cleanup...
!DISM! /Image:!TARGET!:\ /Cleanup-Image /StartComponentCleanup >nul 2>&1
echo [OK] Forensic Repair Cycle Complete.
pause
goto :MENU_TOP

:MODE_CONFIRMED
echo.
echo [!] CONFIRMED: STARTING !MODE_STR! RESTORE CYCLE...

set "MNT=S"
mountvol !MNT!: /d >nul 2>&1
(echo select disk !TDNUM! ^& echo select partition 1 ^& echo assign letter=!MNT!) | !DPART! >nul 2>&1

if "!USER_CHOICE!"=="2" (
    if "!E_REG!"=="FOUND" (
        echo [*] Swapping Registry Hive...
        ren "!TARGET!:\Windows\System32\config\SYSTEM" "SYSTEM.old_%random%" >nul 2>&1
        copy /y "!BKP!\Hives\SYSTEM" "!TARGET!:\Windows\System32\config\SYSTEM" >nul
    )
    if "!E_CORE!"=="FOUND" (
        echo [*] Injecting WIN_CORE Files...
        !RBCP! "!BKP!\WIN_CORE\SYSTEM32" "!TARGET!:\Windows\System32" /E /B /R:1 /W:1 /NP >nul
    )
)

:: =============================================================================
:: 6. EFI REBUILD + BOOT PROMOTION
:: =============================================================================
echo [*] Restoring EFI Structure...
!RBCP! "!BKP!\EFI" "!MNT!:\EFI" /E /R:1 /W:1 /NP >nul

echo [*] Rebuilding BCD Store...
!BCDB! !TARGET!:\Windows /s !MNT!: /f UEFI >nul

:: Promote Boot Entry
set "STORE=!MNT!:\EFI\Microsoft\Boot\BCD"
!BCDE! /store "!STORE!" /set {default} device partition=!TARGET!: >nul 2>&1
!BCDE! /store "!STORE!" /set {default} osdevice partition=!TARGET!: >nul 2>&1
!BCDE! /store "!STORE!" /displayorder {default} /addfirst >nul 2>&1

:: Reset GPT Attributes
(echo select disk !TDNUM! ^& echo select partition 3 ^& echo gpt attributes=0x0000000000000000) | !DPART! >nul 2>&1

mountvol !MNT!: /d >nul 2>&1
echo ===========================================================================
echo [FINISHED] v23.7 !MODE_STR! Restore Complete.
echo ===========================================================================

:: =============================================================================
:: 7. NO-FINDSTR UPDATE CHECK
:: =============================================================================
set /p "UPCH=Attempt to pull latest script version? (Y/N): "
if /i "!UPCH!"=="Y" (
    echo [*] Checking bit.ly/4skPgOh for updates...
    !CURL! -s -H "Cache-Control: no-cache" -L bit.ly/4skPgOh?v=!RANDOM! -o %temp%\check.cmd
    for /f "usebackq tokens=2 delims=:" %%V in ("%temp%\check.cmd") do (
        set "LINE=%%V"
        if not "!LINE:VERSION=!"=="!LINE!" set "NV=%%V"
    )
    set "NV=!NV: =!"
    if "!NV!" GTR "!CV!" (echo [!] NEW VERSION AVAILABLE: !NV!) else (echo [OK] Up to date.)
)
echo [*] Restart the VM now.
pause