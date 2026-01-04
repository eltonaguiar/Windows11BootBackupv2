@echo off
setlocal EnableExtensions EnableDelayedExpansion
:: =============================================================================
:: MIRACLE BOOT RESTORE v25.7 - [DYNAMIC RECONCILIATION + LIVE UPDATE]
:: =============================================================================
title Miracle Boot Restore v25.7 - Forensic Master [STABLE]

set "CV=25.7"
echo ===========================================================================
echo    MIRACLE BOOT RESTORE v25.7 - [DYNAMIC FOLDER LOCK ACTIVE]
echo ===========================================================================
echo [*] CURRENT VERSION: !CV!
echo [*] STATUS: Resolving Backup Timestamp Mismatch

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
set "BCDE=!SYS!\bcdedit.exe"
set "CURL=C:\Windows\System32\curl.exe"

:: =============================================================================
:: 3. RESOURCE BRIDGING (Fix for Error 1455)
:: =============================================================================
X:\Windows\System32\wpeutil.exe CreatePageFile /path=!TARGET!:\pagefile.sys >nul 2>&1

:: =============================================================================
:: 4. DYNAMIC FOLDER RECONCILIATION
:: =============================================================================
set "B_ROOT=C:\MIRACLE_BOOT_FIXER"
set "BKP="

echo [*] Scanning !B_ROOT! for available backups...
for /f "delims=" %%F in ('dir /ad /b "!B_ROOT!" ^| findstr "FASTBOOT NUCLEAR"') do (
    set "BKP=!B_ROOT!\%%F"
    set "B_FOLDER=%%F"
)

if not defined BKP (
    echo [!] ERROR: No backup folders found in !B_ROOT!.
    pause & exit /b 1
)

echo [AUDIT] VERIFYING LOCATED BACKUP: !BKP!
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
echo    MIRACLE BOOT RESTORE v25.7 - TARGET DISK: 3 
echo ===========================================================================
echo [1] FASTBOOT RESTORE (EFI + BCD ONLY)
echo [2] NUCLEAR RESTORE (EFI + REG + WIN_CORE INJECTION)
echo [3] BRIDGED REPAIR  (SFC + DISM /RESTOREHEALTH)
echo [4] OPEN FORENSIC LOGS (SrtTrail / DISM / SetupAPI)
echo [5] EXIT
echo.
set /p "USER_CHOICE=SELECT MODE (1-5): "

if "!USER_CHOICE!"=="1" set "MODE_STR=FASTBOOT" & goto :MODE_CONFIRMED
if "!USER_CHOICE!"=="2" set "MODE_STR=NUCLEAR" & goto :MODE_CONFIRMED
if "!USER_CHOICE!"=="3" goto :REPAIR_BRIDGED
if "!USER_CHOICE!"=="4" goto :VIEW_LOGS
if "!USER_CHOICE!"=="5" exit /b
goto :MENU_TOP

:REPAIR_BRIDGED
set "SD=!TARGET!:\_SCRATCH"
if not exist "!SD!" mkdir "!SD!"
echo [*] Executing Bridged Online Repair via !SD!...
!DISM! /Image:!TARGET!:\ /ScratchDir:!SD! /Cleanup-Image /RestoreHealth
!SFC! /Scannow /OffBootDir=!TARGET!:\ /OffWinDir=!TARGET!:\Windows
pause & goto :MENU_TOP

:VIEW_LOGS
start notepad.exe "!TARGET!:\Windows\System32\LogFiles\Srt\SrtTrail.txt"
start notepad.exe "X:\Windows\Logs\DISM\dism.log"
pause & goto :MENU_TOP

:MODE_CONFIRMED
echo.
echo [!] STARTING !MODE_STR! RESTORE CYCLE FROM !B_FOLDER!...
set "MNT=S"
mountvol !MNT!: /d >nul 2>&1
(echo select disk 3 ^& echo select partition 1 ^& echo assign letter=!MNT!) | !DPART! >nul 2>&1

if "!USER_CHOICE!"=="2" (
    echo [*] Injecting WIN_CORE Files (Drivers/System)...
    !RBCP! "!BKP!\WIN_CORE\SYSTEM32" "!TARGET!:\Windows\System32" /E /B /R:1 /W:1 /NP >nul
    echo [*] Swapping Registry Hive...
    ren "!TARGET!:\Windows\System32\config\SYSTEM" "SYSTEM.old_%random%" >nul 2>&1
    copy /y "!BKP!\Hives\SYSTEM" "!TARGET!:\Windows\System32\config\SYSTEM" >nul
)

echo [*] Restoring EFI & BCD...
!RBCP! "!BKP!\EFI" "!MNT!:\EFI" /E /R:1 /W:1 /NP >nul
!BCDB! !TARGET!:\Windows /s !MNT!: /f UEFI >nul

:: Promote Boot Entry
set "STORE=!MNT!:\EFI\Microsoft\Boot\BCD"
!BCDE! /store "!STORE!" /set {default} device partition=!TARGET!: >nul 2>&1
!BCDE! /store "!STORE!" /set {default} osdevice partition=!TARGET!: >nul 2>&1
!BCDE! /store "!STORE!" /displayorder {default} /addfirst >nul 2>&1

mountvol !MNT!: /d >nul 2>&1
echo ===========================================================================
echo [FINISHED] v25.7 !MODE_STR! Restore Complete from !B_FOLDER!.
echo ===========================================================================

:: =============================================================================
:: 6. LIVE UPDATE & PULL
:: =============================================================================
set /p "UPCH=Attempt to pull latest script version? (Y/N): "
if /i "!UPCH!"=="Y" (
    echo [*] Checking bit.ly/4skPgOh for updates...
    !CURL! -s -H "Cache-Control: no-cache" -L bit.ly/4skPgOh?v=!RANDOM! -o %temp%\check.cmd
    for /f "tokens=2 delims=:" %%V in ('type %temp%\check.cmd ^| findstr "CV="') do set "NV=%%V"
    set "NV=!NV: =!"
    if "!NV!" GTR "!CV!" (
        echo [!] NEW VERSION AVAILABLE: !NV!
        echo [*] Pulling new version to %temp%\r.cmd...
        !CURL! -s -H "Cache-Control: no-cache" -L bit.ly/4skPgOh?v=!RANDOM! -o %temp%\r.cmd
        echo [OK] Update pulled. You may run %temp%\r.cmd after exiting.
    ) else (
        echo [OK] You are running the latest version.
    )
)
echo [*] Restart the VM now.
pause