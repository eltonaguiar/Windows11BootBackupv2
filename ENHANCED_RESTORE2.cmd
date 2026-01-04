@echo off
setlocal EnableExtensions EnableDelayedExpansion
:: =============================================================================
:: MIRACLE BOOT RESTORE v24.1 - [ONLINE DISM REPAIR + LOG FORENSICS]
:: =============================================================================
title Miracle Boot Restore v24.1 - Forensic Audit [STABLE]

set "CV=24.1"
echo ===========================================================================
echo    MIRACLE BOOT RESTORE v24.1 - [ONLINE REPAIR ENGINE ONLINE]
echo ===========================================================================
echo [*] CURRENT VERSION: !CV!
echo [*] STATUS: Online DISM Source + SFC Repair Active

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
:: 3. PRE-BOOT FAILURE AUDIT (Log Scraper)
:: =============================================================================
set "TARGET=C"
echo.
echo [FORENSICS] SCRAPING PRIOR BOOT FAILURE LOGS...
echo ---------------------------------------------------------------------------
set "SRT_LOG=!TARGET!:\Windows\System32\LogFiles\Srt\SrtTrail.txt"
if exist "!SRT_LOG!" (
    echo [FOUND] SrtTrail.txt detected.
    for /f "usebackq delims=" %%A in ("!SRT_LOG!") do (
        set "LINE=%%A"
        if not "!LINE:Root cause found=!"=="!LINE!" echo    -^> !LINE!
        if not "!LINE:Repair action:=!"=="!LINE!" echo    -^> !LINE!
    )
)
if exist "!TARGET!:\Windows\Minidump\*.dmp" echo [WARN] Minidumps detected.
echo ---------------------------------------------------------------------------

:: =============================================================================
:: 4. AUDIT & TARGET LOCK
:: =============================================================================
set "BKP=C:\MIRACLE_BOOT_FIXER\2026-01-03_23-05_FASTBOOT_C"
echo [AUDIT] VERIFYING BACKUP INTEGRITY...
if exist "!BKP!" ( echo [FOUND] Target Path: !BKP! ) else ( echo [MISSING] !BKP! & pause & exit /b 1 )

set "E_EFI=[MISSING]" & if exist "!BKP!\EFI" set "E_EFI=[FOUND]  "
set "E_REG=[MISSING]" & if exist "!BKP!\Hives\SYSTEM" set "E_REG=[FOUND]  "
set "E_CORE=[MISSING]" & if exist "!BKP!\WIN_CORE\SYSTEM32\ntoskrnl.exe" set "E_CORE=[FOUND]  "

echo !E_EFI! EFI Boot Structure
echo !E_REG! Registry System Hive
echo !E_CORE! WIN_CORE Kernel Files
set "TDNUM=3"

:: =============================================================================
:: 5. RESTORE & REPAIR MENU
:: =============================================================================
:MENU_TOP
echo.
echo ===========================================================================
echo    MIRACLE BOOT RESTORE v24.1 - TARGET DISK: !TDNUM! 
echo ===========================================================================
echo [1] FASTBOOT RESTORE (EFI + BCD ONLY)
echo [2] NUCLEAR RESTORE (EFI + REG + WIN_CORE)
echo [3] FORENSIC REPAIR (OFFLINE SFC + LOCAL DISM)
echo [4] ONLINE REPAIR   (OFFLINE SFC + ONLINE DISM)
echo [5] EXIT
echo.
set "USER_CHOICE="
set /p "USER_CHOICE=SELECT MODE (1-4): "

if "!USER_CHOICE!"=="1" set "MODE_STR=FASTBOOT" & goto :MODE_CONFIRMED
if "!USER_CHOICE!"=="2" set "MODE_STR=NUCLEAR" & goto :MODE_CONFIRMED
if "!USER_CHOICE!"=="3" goto :REPAIR_LOCAL
if "!USER_CHOICE!"=="4" goto :REPAIR_ONLINE
if "!USER_CHOICE!"=="5" exit /b
goto :MENU_TOP

:: =============================================================================
:: 6. REPAIR CYCLES
:: =============================================================================
:REPAIR_LOCAL
echo [*] Running Local Forensic Repair...
!DISM! /Image:!TARGET!:\ /Cleanup-Image /RevertPendingActions >nul 2>&1
!SFC! /Scannow /OffBootDir=!TARGET!:\ /OffWinDir=!TARGET!:\Windows
pause & goto :MENU_TOP

:REPAIR_ONLINE
echo [*] Initializing Online Forensic Repair...
echo [*] Attempting to pull repair files from Microsoft Update...
!DISM! /Image:!TARGET!:\ /Cleanup-Image /RestoreHealth
!SFC! /Scannow /OffBootDir=!TARGET!:\ /OffWinDir=!TARGET!:\Windows
pause & goto :MENU_TOP

:MODE_CONFIRMED
echo.
echo [!] STARTING !MODE_STR! RESTORE CYCLE...
set "MNT=S"
mountvol !MNT!: /d >nul 2>&1
(echo select disk !TDNUM! ^& echo select partition 1 ^& echo assign letter=!MNT!) | !DPART! >nul 2>&1

if "!USER_CHOICE!"=="2" (
    echo [*] Injecting WIN_CORE Files...
    !RBCP! "!BKP!\WIN_CORE\SYSTEM32" "!TARGET!:\Windows\System32" /E /B /R:1 /W:1 /NP >nul
    echo [*] Swapping Registry Hive...
    ren "!TARGET!:\Windows\System32\config\SYSTEM" "SYSTEM.old_%random%" >nul 2>&1
    copy /y "!BKP!\Hives\SYSTEM" "!TARGET!:\Windows\System32\config\SYSTEM" >nul
)

:: =============================================================================
:: 7. EFI REBUILD + BOOT PROMOTION
:: =============================================================================
echo [*] Restoring EFI Structure...
!RBCP! "!BKP!\EFI" "!MNT!:\EFI" /E /R:1 /W:1 /NP >nul
!BCDB! !TARGET!:\Windows /s !MNT!: /f UEFI >nul

set "STORE=!MNT!:\EFI\Microsoft\Boot\BCD"
!BCDE! /store "!STORE!" /set {default} device partition=!TARGET!: >nul 2>&1
!BCDE! /store "!STORE!" /set {default} osdevice partition=!TARGET!: >nul 2>&1
!BCDE! /store "!STORE!" /displayorder {default} /addfirst >nul 2>&1

(echo select disk !TDNUM! ^& echo select partition 3 ^& echo gpt attributes=0x0000000000000000) | !DPART! >nul 2>&1
mountvol !MNT!: /d >nul 2>&1
echo ===========================================================================
echo [FINISHED] v24.1 !MODE_STR! Restore Complete.
echo ===========================================================================

:: =============================================================================
:: 8. UPDATE CHECK
:: =============================================================================
set /p "UPCH=Check for updates? (Y/N): "
if /i "!UPCH!"=="Y" (
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