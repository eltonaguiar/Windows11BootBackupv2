@echo off
setlocal EnableExtensions EnableDelayedExpansion
:: HARDCODED VERSION HEADER
title Miracle Boot Restore v20.7 - Forensic Final [STABLE]

:: =============================================================================
:: 1. HARDCODED SYSTEM PATHS (WinRE Recovery)
:: =============================================================================
set "SYS=%SystemRoot%\System32"
set "FSTR=%SYS%\findstr.exe"
set "DPART=%SYS%\diskpart.exe"
set "RBCP=%SYS%\robocopy.exe"
set "REGT=%SYS%\reg.exe"
set "BCDB=%SYS%\bcdboot.exe"
set "BCDE=%SYS%\bcdedit.exe"
set "ICACLS=%SYS%\icacls.exe"
set "TAKE=%SYS%\takeown.exe"
set "ATT=%SYS%\attrib.exe"

set "MNT=S"
set "GUID_ESP={c12a7328-f81f-11d2-ba4b-00a0c93ec93b}"
set "V_BOOT=FAIL"
set "V_BCD=FAIL"

echo ===========================================================================
echo    MIRACLE BOOT RESTORE v20.7 - FORENSIC MAPPING ENGINE
echo ===========================================================================

:: =============================================================================
:: 2. FORENSIC DRIVE DISCOVERY (Windows & Backup)
:: =============================================================================
echo [*] VERSION: 20.7
echo [*] Searching for Windows Installation...
set "TARGET="
for %%D in (C D E F G H I J K L) do if exist "%%D:\Windows\System32\config\SYSTEM" if not defined TARGET set "TARGET=%%D"

if not defined TARGET echo [!] ERROR: Windows installation not found! & pause & exit /b 1
echo [OK] Detected Windows on Drive: !TARGET!:

echo [*] Initializing Deep Backup Search (Scanning C: through L:)...
set "BKP="
for %%D in (C D E F G H I J K L) do (
    if not defined BKP (
        echo [LOG] Checking drive %%D: for FASTBOOT/NUCLEAR folders...
        for /f "delims=" %%F in ('dir /b /ad /s "%%D:\*FASTBOOT*" "%%D:\*NUCLEAR*" 2^>nul') do (
            if not defined BKP (
                set "BKP=%%F"
                echo [OK] Found candidate: "%%F"
            )
        )
    )
)

if not defined BKP echo [!] ERROR: No backups found on any drive! & pause & exit /b 1
echo [OK] Final Backup Path: "!BKP!"

:: =============================================================================
:: 3. SERIAL-BASED DRIVE MAPPING (Fixes "Volume C not found")
:: =============================================================================
echo [*] Mapping !TARGET!: to physical hardware via Volume Serial...
set "TDNUM="

:: Get the Serial Number of the Target Drive
for /f "tokens=5" %%S in ('vol !TARGET!: 2^>nul') do set "TSERIAL=%%S"
if "!TSERIAL!"=="" echo [!] ERROR: Could not read serial for !TARGET!: & pause & exit /b 1

:: Probe DiskPart for the Disk Number matching that Serial
(echo list disk) > "%temp%\dp.txt"
for /f "tokens=2" %%D in ('!DPART! /s "%temp%\dp.txt" ^| !FSTR! /i "Disk "') do (
    if not defined TDNUM (
        (echo select disk %%D & echo list volume) > "%temp%\dp.txt"
        !DPART! /s "%temp%\dp.txt" | !FSTR! /i "!TSERIAL!" >nul
        if !errorlevel! equ 0 set "TDNUM=%%D"
    )
)

if not defined TDNUM echo [!] ERROR: Forensic Disk Map Failed. & pause & exit /b 1
echo [OK] Target Mapped to Disk !TDNUM!

:: =============================================================================
:: 4. FIND & MOUNT ESP (GPT TYPE PROBE)
:: =============================================================================
:FIND_ESP
set "TPNUM="
(echo select disk !TDNUM! & echo list partition) > "%temp%\dp.txt"
!DPART! /s "%temp%\dp.txt" > "%temp%\dp_out.txt"

:: Search for GPT System Type (Standard ESP)
for /f "tokens=2" %%P in ('type "%temp%\dp_out.txt" ^| !FSTR! /i "System"') do set "TPNUM=%%P"

if not defined TPNUM (
    echo [*] Unlabeled ESP detected. Probing partitions...
    for /f "tokens=2" %%P in ('type "%temp%\dp_out.txt" ^| !FSTR! /r /c:"^[ ]*Partition[ ]*[0-9]"') do (
        set "CAND=%%P"
        mountvol !MNT!: /d >nul 2>&1
        (echo select disk !TDNUM! ^& echo select partition !CAND! ^& echo assign letter=!MNT!) | !DPART! >nul 2>&1
        if exist "!MNT!:\EFI\Microsoft\Boot\bootmgfw.efi" set "TPNUM=!CAND!" & goto :MOUNT_ESP
    )
)

:MOUNT_ESP
if not defined TPNUM echo [!] ERROR: ESP Not Found. & pause & exit /b 1
mountvol !MNT!: /d >nul 2>&1
(echo select disk !TDNUM! ^& echo select partition !TPNUM! ^& echo assign letter=!MNT!) | !DPART! >nul 2>&1

cls
echo ===========================================================================
echo    MIRACLE BOOT RESTORE v20.7 - TARGET: !TARGET!: (Disk !TDNUM! Part !TPNUM!)
echo ===========================================================================
echo [1] FASTBOOT RESTORE (EFI + BCD - RECOMMENDED)
echo [2] ADVANCED RESTORE (EFI + REG + WINCORE - WinRE ONLY)
echo.
set /p "CHOICE=Choice: "

if "%CHOICE%"=="2" goto :ADVANCED
goto :FASTBOOT

:ADVANCED
echo [*] Neutralizing Target Hive...
!ATT! -R -S -H "!TARGET!:\Windows\System32\config\SYSTEM" >nul 2>&1
!TAKE! /f "!TARGET!:\Windows\System32\config\SYSTEM" >nul 2>&1
!ICACLS! "!TARGET!:\Windows\System32\config\SYSTEM" /grant administrators:F >nul 2>&1
ren "!TARGET!:\Windows\System32\config\SYSTEM" "SYSTEM.old_%random%" >nul 2>&1
copy /y "!BKP!\Hives\SYSTEM" "!TARGET!:\Windows\System32\config\SYSTEM" >nul

if exist "!BKP!\WIN_CORE\SYSTEM32\ntoskrnl.exe" (
    echo [*] Restoring WINCORE System Files...
    !RBCP! "!BKP!\WIN_CORE\SYSTEM32" "!TARGET!:\Windows\System32" /E /B /R:1 /W:1 /COPY:DAT /NP /NFL /NDL >nul
)

:FASTBOOT
echo [*] Restoring EFI Structure...
!RBCP! "!BKP!\EFI" "!MNT!:\EFI" /E /R:1 /W:1 /NP /NFL /NDL >nul

echo [*] Rebuilding BCD Store...
!BCDB! !TARGET!:\Windows /s !MNT!: /f UEFI >nul

set "STORE=!MNT!:\EFI\Microsoft\Boot\BCD"
set "CUR_GUID="
for /f "tokens=2" %%G in ('!BCDE! /store "!STORE!" /enum osloader ^| !FSTR! /i "identifier"') do if not defined CUR_GUID set "CUR_GUID=%%G"
if not defined CUR_GUID set "CUR_GUID={default}"

!BCDE! /store "!STORE!" /set !CUR_GUID! device partition=!TARGET!: >nul 2>&1
!BCDE! /store "!STORE!" /set !CUR_GUID! osdevice partition=!TARGET!: >nul 2>&1

:: Verification
if exist "!MNT!:\EFI\Microsoft\Boot\bootmgfw.efi" set "V_BOOT=OK"
!BCDE! /store "!STORE!" /enum !CUR_GUID! 2^>nul | !FSTR! /i "partition=!TARGET!:" >nul
if !errorlevel! equ 0 set "V_BCD=OK"

:CLEANUP
mountvol !MNT!: /d >nul 2>&1
(echo select disk !TDNUM! ^& echo select partition !TPNUM! ^& echo remove letter=!MNT!) | !DPART! >nul 2>&1

echo ===========================================================================
echo [FINISHED] Restore cycle complete.
echo VERIFICATION: BootMgr: !V_BOOT! ^| BCD Pointer: !V_BCD!
echo ===========================================================================
pause
exit /b 0
