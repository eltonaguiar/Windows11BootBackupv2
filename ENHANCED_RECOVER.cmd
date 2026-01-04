@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Miracle Boot Restore v20.3 - Deep Discovery [STABLE]

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

:: =============================================================================
:: 2. FORENSIC DRIVE DISCOVERY (Windows & Backup)
:: =============================================================================
echo [*] Searching for Windows Installation...
set "TARGET="
for %%D in (C D E F G H I J K L) do if exist "%%D:\Windows\System32\config\SYSTEM" if not defined TARGET set "TARGET=%%D"

if not defined TARGET echo [!] ERROR: Windows installation not found! & pause & exit /b 1
echo [OK] Detected Windows on Drive: !TARGET!:

echo [*] Searching for Backup Folder on all drives...
set "BKP="
:: Scans every drive for any folder containing FASTBOOT or NUCLEAR
for %%D in (C D E F G H I J K L) do (
    if not defined BKP (
        for /f "delims=" %%F in ('dir /b /ad /s "%%D:\*FASTBOOT*" "%%D:\*NUCLEAR*" 2^>nul') do (
            if not defined BKP set "BKP=%%F"
        )
    )
)

if not defined BKP echo [!] ERROR: No backups found on any drive! & pause & exit /b 1
echo [OK] Using Backup: "!BKP!"

:: =============================================================================
:: 3. MAP TARGET DRIVE -> DISK NUMBER
:: =============================================================================
echo [*] Mapping !TARGET!: to physical hardware...
set "TDNUM="
:: Method A: PowerShell (If available)
for /f %%A in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "try{(Get-Partition -DriveLetter ''%TARGET%'').DiskNumber}catch{''}" 2^>nul') do set "TDNUM=%%A"

if defined TDNUM goto :FIND_ESP

:: Method B: Hardened DiskPart Fallback
echo [*] PowerShell failed. Probing DiskPart volume table...
(echo list volume) > "%temp%\dp.txt"
!DPART! /s "%temp%\dp.txt" > "%temp%\dp_out.txt"
set "TVOL="
for /f "tokens=2,3,4" %%A in ('type "%temp%\dp_out.txt"') do if /i "%%C"=="!TARGET!" set "TVOL=%%B"

if not defined TVOL echo [!] ERROR: Target Volume !TARGET! not found in DiskPart. & pause & exit /b 1

(echo select volume !TVOL! ^& echo detail volume) | !DPART! > "%temp%\dp_out.txt"
for /f "tokens=4" %%D in ('type "%temp%\dp_out.txt" ^| !FSTR! /i "Disk ###"') do set "TDNUM=%%D"

if not defined TDNUM echo [!] ERROR: Disk Map Failed. & pause & exit /b 1

:: =============================================================================
:: 4. FIND & MOUNT ESP (PROBE MODE)
:: =============================================================================
:FIND_ESP
echo [OK] Target Disk: !TDNUM!
set "TPNUM="

:: GPT Type-ID Scan
for /f %%B in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "$p=Get-Partition -DiskNumber %TDNUM% ^| ? {$_.GptType -eq ''%GUID_ESP%''} ^| select -First 1; if($p){$p.PartitionNumber}" 2^>nul') do set "TPNUM=%%B"

if defined TPNUM goto :MOUNT_ESP

:: Forensic Probe
echo [*] ESP search failed. Probing partitions via mount...
(echo select disk !TDNUM! ^& echo list partition) | !DPART! > "%temp%\dp_out.txt"

for /f "tokens=2" %%P in ('type "%temp%\dp_out.txt" ^| !FSTR! /r /c:"^[ ]*Partition[ ]*[0-9]"') do (
    set "CAND=%%P"
    mountvol !MNT!: /d >nul 2>&1
    (echo select disk !TDNUM! ^& echo select partition !CAND! ^& echo assign letter=!MNT!) | !DPART! >nul 2>&1
    if exist "!MNT!:\EFI\Microsoft\Boot\bootmgfw.efi" (
        set "TPNUM=!CAND!"
        goto :MOUNT_ESP
    )
    mountvol !MNT!: /d >nul 2>&1
)

if not defined TPNUM echo [!] ERROR: ESP Not Found. & pause & exit /b 1

:: =============================================================================
:: 5. EXECUTION MENU
:: =============================================================================
:MOUNT_ESP
echo [OK] ESP Found: Partition !TPNUM!
mountvol !MNT!: /d >nul 2>&1
(echo select disk !TDNUM! ^& echo select partition !TPNUM! ^& echo assign letter=!MNT!) | !DPART! >nul 2>&1

cls
echo ===========================================================================
echo    MIRACLE BOOT RESTORE v20.3 - TARGET: !TARGET!: (Disk !TDNUM! Part !TPNUM!)
echo ===========================================================================
echo [1] FASTBOOT RESTORE (EFI + BCD - WinRE RECOMMENDED)
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
    echo [*] Restoring WINCORE...
    !RBCP! "!BKP!\WIN_CORE\SYSTEM32" "!TARGET!:\Windows\System32" /E /B /R:1 /W:1 /COPY:DAT /NP /NFL /NDL >nul
)

:FASTBOOT
echo [*] Restoring EFI Structure...
!RBCP! "!BKP!\EFI" "!MNT!:\EFI" /E /R:1 /W:1 /NP /NFL /NDL >nul

echo [*] Rebuilding BCD Pointers...
!BCDB! !TARGET!:\Windows /s !MNT!: /f UEFI >nul

:: GUID Selection
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
echo [FINISHED] Restore Attempted.
echo VERIFICATION: BootMgr: !V_BOOT! ^| BCD Pointer: !V_BCD!
echo ===========================================================================
pause
exit /b 0
