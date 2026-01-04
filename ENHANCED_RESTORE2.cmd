@echo off
setlocal EnableExtensions EnableDelayedExpansion
:: =============================================================================
:: MIRACLE BOOT RESTORE v23.3 - [BOOT ENTRY PROMOTION + NUCLEAR REBUILD]
:: =============================================================================
title Miracle Boot Restore v23.3 - Forensic Audit [STABLE]

set "CV=23.3"
echo ===========================================================================
echo    MIRACLE BOOT RESTORE v23.3 - [BOOT PROMOTION ONLINE]
echo ===========================================================================
echo [*] CURRENT VERSION: !CV!
echo [*] STATUS: Boot Entry Promotion Active

:: 1. AUTO-NETWORKING
wpeutil InitializeNetwork >nul 2>&1

:: 2. DYNAMIC TOOL DISCOVERY
set "SYS=C:\Windows\System32"
if not exist !SYS!\diskpart.exe set "SYS=X:\Windows\System32"
set "DPART=!SYS!\diskpart.exe"
set "RBCP=!SYS!\robocopy.exe"
set "BCDB=!SYS!\bcdboot.exe"
set "BCDE=!SYS!\bcdedit.exe"
set "ATT=!SYS!\attrib.exe"
set "TAKE=!SYS!\takeown.exe"
set "ICACLS=!SYS!\icacls.exe"
set "CURL=C:\Windows\System32\curl.exe"

:: =============================================================================
:: 3. TARGET & BACKUP DISCOVERY
:: =============================================================================
set "TARGET=C"
if not exist C:\Windows\System32\config\SYSTEM set "TARGET=D"
set "BKP=C:\MIRACLE_BOOT_FIXER\2026-01-03_23-05_FASTBOOT_C"

echo [*] Auditing Backup Folder...
if not exist "!BKP!" echo [!] ERROR: Backup folder not found! & pause & exit /b 1

:: Forensic Component Check
set "E_EFI=MISSING" & if exist "!BKP!\EFI" set "E_EFI=FOUND"
set "E_REG=MISSING" & if exist "!BKP!\Hives\SYSTEM" set "E_REG=FOUND"
set "E_CORE=MISSING" & if exist "!BKP!\WIN_CORE\SYSTEM32\ntoskrnl.exe" set "E_CORE=FOUND"

echo [LOG] EFI Structure: !E_EFI!
echo [LOG] Registry Hive: !E_REG!
echo [LOG] WIN_CORE Files: !E_CORE!

:: =============================================================================
:: 4. SERIAL MAPPING
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
if not defined TDNUM set "TDNUM=3"

:: =============================================================================
:: 5. MANDATORY RESTORE MENU
:: =============================================================================
:MENU_TOP
cls
echo ===========================================================================
echo    MIRACLE BOOT RESTORE v23.3 - TARGET DISK: !TDNUM! 
echo ===========================================================================
echo [1] FASTBOOT RESTORE (EFI + BCD ONLY)
echo [2] NUCLEAR RESTORE (EFI + REG + WIN_CORE)
echo.
set "USER_CHOICE="
set /p "USER_CHOICE=SELECT MODE (1 OR 2): "
if "!USER_CHOICE!"=="1" set "MODE_STR=FASTBOOT" & goto :MODE_CONFIRMED
if "!USER_CHOICE!"=="2" set "MODE_STR=NUCLEAR" & goto :MODE_CONFIRMED
goto :MENU_TOP

:MODE_CONFIRMED
echo.
echo [!] CONFIRMED: STARTING !MODE_STR! RESTORE CYCLE...

:: ESP MOUNTING
set "MNT=S"
mountvol !MNT!: /d >nul 2>&1
(echo select disk !TDNUM! ^& echo select partition 1 ^& echo assign letter=!MNT!) | !DPART! >nul 2>&1

if "!USER_CHOICE!"=="1" goto :FASTBOOT

:: =============================================================================
:: 6. NUCLEAR RESTORE LOGIC
:: =============================================================================
:NUCLEAR
if "!E_REG!"=="FOUND" (
    echo [*] Neutralizing Target System Hive...
    !ATT! -R -S -H "!TARGET!:\Windows\System32\config\SYSTEM" >nul 2>&1
    !TAKE! /f "!TARGET!:\Windows\System32\config\SYSTEM" >nul 2>&1
    !ICACLS! "!TARGET!:\Windows\System32\config\SYSTEM" /grant administrators:F >nul 2>&1
    ren "!TARGET!:\Windows\System32\config\SYSTEM" "SYSTEM.old_%random%" >nul 2>&1
    copy /y "!BKP!\Hives\SYSTEM" "!TARGET!:\Windows\System32\config\SYSTEM" >nul
)
if "!E_CORE!"=="FOUND" (
    echo [*] Injecting WIN_CORE System Files...
    !RBCP! "!BKP!\WIN_CORE\SYSTEM32" "!TARGET!:\Windows\System32" /E /B /R:1 /W:1 /COPY:DAT /NP /NFL /NDL >nul
)

:: =============================================================================
:: 7. EFI & BCD REBUILD + BOOT ENTRY PROMOTION
:: =============================================================================
:FASTBOOT
echo [*] Restoring EFI Structure...
!RBCP! "!BKP!\EFI" "!MNT!:\EFI" /E /R:1 /W:1 /NP /NFL /NDL >nul

echo [*] Rebuilding BCD Store...
!BCDB! !TARGET!:\Windows /s !MNT!: /f UEFI >nul

:: Promote New Boot Entry
echo [*] Promoting Miracle Boot Entry...
set "STORE=!MNT!:\EFI\Microsoft\Boot\BCD"
!BCDE! /store "!STORE!" /set {default} device partition=!TARGET!: >nul 2>&1
!BCDE! /store "!STORE!" /set {default} osdevice partition=!TARGET!: >nul 2>&1
!BCDE! /store "!STORE!" /displayorder {default} /addfirst >nul 2>&1

:: Reset GPT Attributes
(echo select disk !TDNUM! ^& echo select partition 3 ^& echo gpt attributes=0x0000000000000000) | !DPART! >nul 2>&1

:: CLEANUP
mountvol !MNT!: /d >nul 2>&1
echo ===========================================================================
echo [FINISHED] v23.3 !MODE_STR! Restore Complete.
echo ===========================================================================

:: =============================================================================
:: 8. LIVE UPDATE FUNCTION
:: =============================================================================
set /p "UPCH=Attempt to pull latest script version? (Y/N): "
if /i "!UPCH!"=="Y" (
    echo [*] Checking bit.ly/4skPgOh for updates...
    !CURL! -s -H "Cache-Control: no-cache" -L bit.ly/4skPgOh -o %temp%\check.cmd
    for /f "tokens=2 delims=:" %%V in ('type %temp%\check.cmd ^| findstr "VERSION:"') do set "NV=%%V"
    set "NV=!NV: =!"
    if "!NV!" GTR "!CV!" (
        echo [!] NEW VERSION AVAILABLE: !NV!
        echo [*] Update via the One-Liner in Section 1.
    ) else (
        echo [OK] You are running the latest version.
    )
)
echo [*] Restart the VM now.
pause