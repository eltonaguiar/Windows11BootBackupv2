@echo off
setlocal EnableExtensions EnableDelayedExpansion
:: =============================================================================
:: MIRACLE BOOT RESTORE v21.6 - [NUCLEAR RESTORE RE-INTEGRATED]
:: =============================================================================
title Miracle Boot Restore v21.6 - Nuclear Zero-Dependency [STABLE]

echo ===========================================================================
echo    MIRACLE BOOT RESTORE v21.6 - FORENSIC NUCLEAR
echo ===========================================================================
echo [*] VERSION: 21.6

:: 1. AUTO-NETWORKING
echo [*] Initializing WinRE Network Stack...
wpeutil InitializeNetwork >nul 2>&1

:: 2. DYNAMIC PATH DISCOVERY
set "SYS=X:\Windows\System32"
if not exist X:\Windows\System32\diskpart.exe set "SYS=C:\Windows\System32"
if not exist !SYS!\diskpart.exe set "SYS=D:\Windows\System32"

set "DPART=!SYS!\diskpart.exe"
set "RBCP=!SYS!\robocopy.exe"
set "BCDB=!SYS!\bcdboot.exe"
set "BCDE=!SYS!\bcdedit.exe"
set "ATT=!SYS!\attrib.exe"
set "TAKE=!SYS!\takeown.exe"
set "ICACLS=!SYS!\icacls.exe"

:: =============================================================================
:: 3. TARGET & BACKUP DISCOVERY
:: =============================================================================
set "TARGET=C"
if not exist C:\Windows\System32\config\SYSTEM set "TARGET=D"
echo [OK] Detected Windows on Drive: !TARGET!:

set "BKP=C:\MIRACLE_BOOT_FIXER\2026-01-03_23-05_FASTBOOT_C"
if not exist "!BKP!" (
    for /f "delims=" %%F in ('dir /b /ad /s "!TARGET!:\*FASTBOOT*" 2^>nul') do set "BKP=%%F"
)
echo [OK] Using Backup: "!BKP!"

:: =============================================================================
:: 4. SERIAL MAPPING (INTERNAL MATCH - NO FINDSTR)
:: =============================================================================
for /f "tokens=5" %%S in ('vol !TARGET!: 2^>nul') do set "TSERIAL=%%S"
set "TDNUM="
for %%D in (0 1 2 3) do (
    echo select disk %%D > %temp%\dp.txt
    echo list volume >> %temp%\dp.txt
    !DPART! /s %temp%\dp.txt > %temp%\dp_out.txt
    for /f "usebackq delims=" %%L in ("%temp%\dp_out.txt") do (
        set "LINE=%%L"
        if not "!LINE:!TSERIAL!=!"=="!LINE!" set "TDNUM=%%D"
    )
)

if not defined TDNUM set "TDNUM=0"

:: =============================================================================
:: 5. NUCLEAR MENU (RE-INTEGRATED)
:: =============================================================================
echo.
echo [1] FASTBOOT RESTORE (EFI + BCD ONLY)
echo [2] NUCLEAR RESTORE (EFI + REG + WIN_CORE)
echo.
set /p "CHOICE=Select Restore Mode: "

:: ESP MOUNTING
set "TPNUM=1"
set "MNT=S"
mountvol !MNT!: /d >nul 2>&1
(echo select disk !TDNUM! & echo select partition !TPNUM! & echo assign letter=!MNT!) | !DPART! >nul 2>&1

if "%CHOICE%"=="1" goto :FASTBOOT

:: =============================================================================
:: 6. ADVANCED NUCLEAR LOGIC
:: =============================================================================
:NUCLEAR
echo [*] Neutralizing Target System Hive...
!ATT! -R -S -H "!TARGET!:\Windows\System32\config\SYSTEM" >nul 2>&1
!TAKE! /f "!TARGET!:\Windows\System32\config\SYSTEM" >nul 2>&1
!ICACLS! "!TARGET!:\Windows\System32\config\SYSTEM" /grant administrators:F >nul 2>&1
ren "!TARGET!:\Windows\System32\config\SYSTEM" "SYSTEM.old_%random%" >nul 2>&1
copy /y "!BKP!\Hives\SYSTEM" "!TARGET!:\Windows\System32\config\SYSTEM" >nul

if exist "!BKP!\WIN_CORE\SYSTEM32\ntoskrnl.exe" (
    echo [*] Injecting WIN_CORE System Files...
    !RBCP! "!BKP!\WIN_CORE\SYSTEM32" "!TARGET!:\Windows\System32" /E /B /R:1 /W:1 /COPY:DAT /NP /NFL /NDL >nul
)

:: =============================================================================
:: 7. EFI & BCD REBUILD
:: =============================================================================
:FASTBOOT
echo [*] Injecting EFI Boot Files...
!RBCP! "!BKP!\EFI" "!MNT!:\EFI" /E /R:1 /W:1 /NP /NFL /NDL >nul

echo [*] Rebuilding BCD Store...
!BCDB! !TARGET!:\Windows /s !MNT!: /f UEFI >nul

set "STORE=!MNT!:\EFI\Microsoft\Boot\BCD"
!BCDE! /store "!STORE!" /set {default} device partition=!TARGET!: >nul 2>&1
!BCDE! /store "!STORE!" /set {default} osdevice partition=!TARGET!: >nul 2>&1

:: CLEANUP
mountvol !MNT!: /d >nul 2>&1
echo ===========================================================================
echo [FINISHED] Restore cycle complete. Please Restart the VM.
echo ===========================================================================
pause