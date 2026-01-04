@echo off
setlocal EnableExtensions EnableDelayedExpansion
:: =============================================================================
:: MIRACLE BOOT RESTORE v25.5 - [DEDICATED ONLINE DISM + BACKUP INJECTION]
:: =============================================================================
title Miracle Boot Restore v25.5 - Forensic Master [STABLE]

set "CV=25.5"
echo ===========================================================================
echo    MIRACLE BOOT RESTORE v25.5 - [RESTORATION ENGINE FINALIZED]
echo ===========================================================================
echo [*] CURRENT VERSION: !CV!
echo [*] STATUS: Absolute Backup Injection + Dedicated Online Repair Active

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
set "SFC=!SYS!\sfc.exe"
set "NTPD=!SYS!\notepad.exe"
set "BCDE=!SYS!\bcdedit.exe"
set "WPEU=X:\Windows\System32\wpeutil.exe"

:: =============================================================================
:: 3. RESOURCE BRIDGING (Fix for Error 1455 & Scratch Exhaustion)
:: =============================================================================
echo [*] Executing: !WPEU! CreatePageFile /path=!TARGET!:\pagefile.sys
!WPEU! CreatePageFile /path=!TARGET!:\pagefile.sys >nul 2>&1

set "SD=!TARGET!:\_SCRATCH"
if not exist "!SD!" (
    echo [*] Executing: mkdir "!SD!"
    mkdir "!SD!"
)

:: =============================================================================
:: 4. BACKUP AUDIT (Hard-Locked to 19-28 Timestamp)
:: =============================================================================
set "BKP=C:\MIRACLE_BOOT_FIXER\2026-01-03_19-28_FASTBOOT_C"
echo.
echo [AUDIT] VERIFYING TARGET BACKUP: !BKP!
if not exist "!BKP!" (
    echo [!] ERROR: Backup folder !BKP! not found. Check drive mapping!
    pause & exit /b 1
)

set "E_EFI=[MISSING]" & if exist "!BKP!\EFI" set "E_EFI=[FOUND]  "
set "E_REG=[MISSING]" & if exist "!BKP!\Hives\SYSTEM" set "E_REG=[FOUND]  "
set "E_CORE=[MISSING]" & if exist "!BKP!\WIN_CORE\SYSTEM32\ntoskrnl.exe" set "E_CORE=[FOUND]  "

echo !E_EFI! EFI Boot Structure
echo !E_REG! Registry System Hive (with Drivers)
echo !E_CORE! WIN_CORE Payload

:: =============================================================================
:: 5. RESTORE & REPAIR MENU
:: =============================================================================
:MENU_TOP
echo.
echo ===========================================================================
echo    MIRACLE BOOT RESTORE v25.5 - TARGET DISK: 3 
echo ===========================================================================
echo [1] FASTBOOT RESTORE (EFI + BCD ONLY)
echo [2] NUCLEAR RESTORE (EFI + REG + WIN_CORE INJECTION)
echo [3] LOCAL REPAIR    (SFC + DISM REVERT PENDING)
echo [4] ONLINE REPAIR   (DISM /RESTOREHEALTH FROM MS)
echo [5] OPEN FORENSIC LOGS (SrtTrail / DISM / SetupAPI)
echo [6] EXIT
echo.
set /p "USER_CHOICE=SELECT MODE (1-6): "

if "!USER_CHOICE!"=="1" set "MODE_STR=FASTBOOT" & goto :MODE_CONFIRMED
if "!USER_CHOICE!"=="2" set "MODE_STR=NUCLEAR" & goto :MODE_CONFIRMED
if "!USER_CHOICE!"=="3" goto :REPAIR_LOCAL
if "!USER_CHOICE!"=="4" goto :REPAIR_ONLINE
if "!USER_CHOICE!"=="5" goto :VIEW_LOGS
if "!USER_CHOICE!"=="6" exit /b
goto :MENU_TOP

:: =============================================================================
:: 6. REPAIR LOGIC (Transparent + Bridged)
:: =============================================================================
:REPAIR_LOCAL
echo [*] Executing: !DISM! /Image:!TARGET!:\ /ScratchDir:!SD! /Cleanup-Image /RevertPendingActions
!DISM! /Image:!TARGET!:\ /ScratchDir:!SD! /Cleanup-Image /RevertPendingActions
echo [*] Executing: !SFC! /Scannow /OffBootDir=!TARGET!:\ /OffWinDir=!TARGET!:\Windows
!SFC! /Scannow /OffBootDir=!TARGET!:\ /OffWinDir=!TARGET!:\Windows
pause & goto :MENU_TOP

:REPAIR_ONLINE
echo [*] Executing: !DISM! /Image:!TARGET!:\ /ScratchDir:!SD! /Cleanup-Image /RestoreHealth
!DISM! /Image:!TARGET!:\ /ScratchDir:!SD! /Cleanup-Image /RestoreHealth
echo [*] Executing: !SFC! /Scannow /OffBootDir=!TARGET!:\ /OffWinDir=!TARGET!:\Windows
!SFC! /Scannow /OffBootDir=!TARGET!:\ /OffWinDir=!TARGET!:\Windows
pause & goto :MENU_TOP

:: =============================================================================
:: 7. LOG VIEWER
:: =============================================================================
:VIEW_LOGS
echo.
set "S_LOG=!TARGET!:\Windows\System32\LogFiles\Srt\SrtTrail.txt"
set "D_LOG=X:\Windows\Logs\DISM\dism.log"
set "A_LOG=!TARGET!:\Windows\inf\setupapi.dev.log"

if exist "!S_LOG!" ( echo [*] Opening SrtTrail... & start !NTPD! "!S_LOG!" )
if exist "!D_LOG!" ( echo [*] Opening DISM Log... & start !NTPD! "!D_LOG!" )
if exist "!A_LOG!" ( echo [*] Opening SetupAPI Log... & start !NTPD! "!A_LOG!" )
pause & goto :MENU_TOP

:: =============================================================================
:: 8. RESTORE CYCLE (Component Injection Fixed)
:: =============================================================================
:MODE_CONFIRMED
echo.
echo [!] STARTING !MODE_STR! RESTORE CYCLE FROM !BKP!...
set "MNT=S"
mountvol !MNT!: /d >nul 2>&1
echo [*] Executing: (select disk 3 ^& select partition 1 ^& assign letter=!MNT!) | !DPART!
(echo select disk 3 ^& echo select partition 1 ^& echo assign letter=!MNT!) | !DPART! >nul 2>&1

if "!USER_CHOICE!"=="2" (
    echo [*] Injecting WIN_CORE Files (Drivers/System) via Robocopy...
    echo [*] Executing: !RBCP! "!BKP!\WIN_CORE\SYSTEM32" "!TARGET!:\Windows\System32" /E /B
    !RBCP! "!BKP!\WIN_CORE\SYSTEM32" "!TARGET!:\Windows\System32" /E /B /R:1 /W:1 /NP >nul
    
    echo [*] Injecting System Registry Hive...
    echo [*] Executing: ren "!TARGET!:\Windows\System32\config\SYSTEM" "SYSTEM.old_%random%"
    ren "!TARGET!:\Windows\System32\config\SYSTEM" "SYSTEM.old_%random%" >nul 2>&1
    echo [*] Executing: copy /y "!BKP!\Hives\SYSTEM" "!TARGET!:\Windows\System32\config\SYSTEM"
    copy /y "!BKP!\Hives\SYSTEM" "!TARGET!:\Windows\System32\config\SYSTEM" >nul
)

echo [*] Restoring EFI Structure...
!RBCP! "!BKP!\EFI" "!MNT!:\EFI" /E /R:1 /W:1 /NP >nul
echo [*] Executing: !BCDB! !TARGET!:\Windows /s !MNT!: /f UEFI
!BCDB! !TARGET!:\Windows /s !MNT!: /f UEFI >nul

:: Promote Boot Entry
set "STORE=!MNT!:\EFI\Microsoft\Boot\BCD"
!BCDE! /store "!STORE!" /set {default} device partition=!TARGET!: >nul 2>&1
!BCDE! /store "!STORE!" /set {default} osdevice partition=!TARGET!: >nul 2>&1
!BCDE! /store "!STORE!" /displayorder {default} /addfirst >nul 2>&1

mountvol !MNT!: /d >nul 2>&1
echo ===========================================================================
echo [FINISHED] v25.5 !MODE_STR! Restore Complete from !BKP!.
echo ===========================================================================

:: =============================================================================
:: 9. UPDATE CHECK & EXIT
:: =============================================================================
set /p "UPCH=Check for updates? (Y/N): "
if /i "!UPCH!"=="Y" (
    X:\Windows\System32\curl.exe -s -H "Cache-Control: no-cache" -L bit.ly/4skPgOh?v=!RANDOM! -o %temp%\check.cmd
    for /f "tokens=2 delims=:" %%V in ('type %temp%\check.cmd ^| findstr "CV="') do set "NV=%%V"
    set "NV=!NV: =!"
    if "!NV!" GTR "!CV!" (echo [!] NEW VERSION AVAILABLE: !NV!) else (echo [OK] Up to date.)
)
pause