@echo off
setlocal EnableExtensions EnableDelayedExpansion
:: =============================================================================
:: MIRACLE BOOT RESTORE v21.2 - [NO-FINDSTR / NO-TIMEOUT EDITION]
:: =============================================================================
title Miracle Boot Restore v21.2 - Zero-Dependency [STABLE]

echo ===========================================================================
echo    MIRACLE BOOT RESTORE v21.2 - FORENSIC HARDENED
echo ===========================================================================
echo [*] VERSION: 21.2

:: 1. AUTO-NETWORKING (REMOVED TIMEOUT)
echo [*] Initializing WinRE Network Stack...
wpeutil InitializeNetwork >nul 2>&1

:: 2. DYNAMIC PATH DISCOVERY (Search X: then C: then D:)
set "SYS=X:\Windows\System32"
if not exist X:\Windows\System32\diskpart.exe set "SYS=C:\Windows\System32"
if not exist !SYS!\diskpart.exe set "SYS=D:\Windows\System32"

set "DPART=!SYS!\diskpart.exe"
set "RBCP=!SYS!\robocopy.exe"
set "BCDB=!SYS!\bcdboot.exe"
set "BCDE=!SYS!\bcdedit.exe"

:: =============================================================================
:: 3. TARGET & BACKUP DISCOVERY
:: =============================================================================
echo [DEBUG] Using System Path: !SYS!
set "TARGET=C"
if not exist C:\Windows\System32\config\SYSTEM set "TARGET=D"
echo [OK] Detected Windows on: !TARGET!:

set "BKP=C:\MIRACLE_BOOT_FIXER\2026-01-03_23-05_FASTBOOT_C"
if not exist "!BKP!" (
    echo [!] Hardcoded path failed. Scanning drive...
    for /f "delims=" %%F in ('dir /b /ad /s "!TARGET!:\*FASTBOOT*" 2^>nul') do set "BKP=%%F"
)
if not defined BKP echo [!] ERROR: No backups found! & pause & exit /b 1
echo [OK] Final Backup Path: "!BKP!"

:: =============================================================================
:: 4. SERIAL MAPPING (FINDSTR-FREE METHOD)
:: =============================================================================
echo [*] Mapping !TARGET!: via Serial Match...
for /f "tokens=5" %%S in ('vol !TARGET!: 2^>nul') do set "TSERIAL=%%S"
echo [DEBUG] Target Serial: !TSERIAL!

set "TDNUM="
:: Manually probe disks 0-3 without using findstr
for %%D in (0 1 2 3) do (
    echo select disk %%D > %temp%\dp.txt
    echo list volume >> %temp%\dp.txt
    !DPART! /s %temp%\dp.txt > %temp%\dp_out.txt
    
    :: Search for serial in output using internal loop instead of findstr
    for /f "delims=" %%L in (%temp%\dp_out.txt) do (
        set "LINE=%%L"
        if not "!LINE:!TSERIAL!=!"=="!LINE!" set "TDNUM=%%D"
    )
)

if not defined TDNUM set "TDNUM=0"
echo [OK] Mapped to Disk !TDNUM!

:: =============================================================================
:: 5. ESP MOUNTING (HARD-CODED PARTITION 1)
:: =============================================================================
set "TPNUM=1"
set "MNT=S"
mountvol !MNT!: /d >nul 2>&1
(echo select disk !TDNUM! & echo select partition !TPNUM! & echo assign letter=!MNT!) | !DPART! >nul 2>&1
if not exist !MNT!:\EFI (
    echo [!] Partition 1 failed. Trying Probe...
    (echo select disk !TDNUM! & echo select partition 2 & echo assign letter=!MNT!) | !DPART! >nul 2>&1
)

:: =============================================================================
:: 6. RESTORATION
:: =============================================================================
echo [*] Injecting EFI Files...
!RBCP! "!BKP!\EFI" "!MNT!:\EFI" /E /R:1 /W:1 /NP /NFL /NDL >nul

echo [*] Rebuilding BCD...
!BCDB! !TARGET!:\Windows /s !MNT!: /f UEFI >nul

:: Final GUID Set (No Findstr)
set "STORE=!MNT!:\EFI\Microsoft\Boot\BCD"
!BCDE! /store "!STORE!" /set {default} device partition=!TARGET!: >nul 2>&1
!BCDE! /store "!STORE!" /set {default} osdevice partition=!TARGET!: >nul 2>&1

:: CLEANUP
mountvol !MNT!: /d >nul 2>&1
echo ===========================================================================
echo [FINISHED] Restore Complete. Please Restart.
echo ===========================================================================
pause
