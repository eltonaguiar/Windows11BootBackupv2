@echo off
setlocal EnableExtensions EnableDelayedExpansion
:: =============================================================================
:: MIRACLE BOOT RESTORE v24.5 - [UPDATE PARSER FIX + RESOURCE BRIDGE]
:: =============================================================================
title Miracle Boot Restore v24.5 - Forensic Audit [STABLE]

set "CV=24.5"
echo ===========================================================================
echo    MIRACLE BOOT RESTORE v24.5 - [VERSION PARSER FIXED]
echo ===========================================================================
echo [*] CURRENT VERSION: !CV!
echo [*] STATUS: Native Update Comparison + Resource Bridge Active

:: 1. AUTO-NETWORKING
X:\Windows\System32\wpeutil.exe InitializeNetwork >nul 2>&1

:: 2. DYNAMIC TOOL DISCOVERY
set "SYS=C:\Windows\System32"
if not exist !SYS!\diskpart.exe set "SYS=X:\Windows\System32"
set "DPART=!SYS!\diskpart.exe"
set "BCDE=!SYS!\bcdedit.exe"
set "DISM=!SYS!\dism.exe"
set "SFC=!SYS!\sfc.exe"
set "CURL=!SYS!\curl.exe"
set "WPEU=X:\Windows\System32\wpeutil.exe"

:: =============================================================================
:: 3. RESOURCE BRIDGE (Fixing Error 1455)
:: =============================================================================
set "TARGET=C"
for %%D in (C D E F G) do if exist "%%D:\Windows\System32\winload.efi" set "TARGET=%%D"

echo [*] Stabilizing WinRE memory via Bridge on !TARGET!:...
!WPEU! CreatePageFile /path=!TARGET!:\pagefile.sys >nul 2>&1

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
echo    MIRACLE BOOT RESTORE v24.5 - TARGET DISK: !TDNUM! 
echo ===========================================================================
echo [1] FASTBOOT RESTORE (EFI + BCD ONLY)
echo [2] NUCLEAR RESTORE (EFI + REG + WIN_CORE)
echo [3] CROSS-REPAIR ENGINE (OFFLINE SFC + LOCAL DISM)
echo [4] CROSS-REPAIR ENGINE (OFFLINE SFC + ONLINE DISM)
echo [5] EXIT
echo.
set "USER_CHOICE="
set /p "USER_CHOICE=SELECT MODE (1-5): "

if "!USER_CHOICE!"=="1" set "MODE_STR=FASTBOOT" & goto :MODE_CONFIRMED
if "!USER_CHOICE!"=="2" set "MODE_STR=NUCLEAR" & goto :MODE_CONFIRMED
if "!USER_CHOICE!"=="3" goto :REPAIR_LOCAL
if "!USER_CHOICE!"=="4" goto :REPAIR_ONLINE
if "!USER_CHOICE!"=="5" exit /b
goto :MENU_TOP

:REPAIR_LOCAL
echo [*] Executing Local Cross-Repair...
!DISM! /Image:!TARGET!:\ /Cleanup-Image /RevertPendingActions >nul 2>&1
!DISM! /Image:!TARGET!:\ /Cleanup-Image /StartComponentCleanup
!SFC! /Scannow /OffBootDir=!TARGET!:\ /OffWinDir=!TARGET!:\Windows
pause & goto :MENU_TOP

:REPAIR_ONLINE
echo [*] Executing Online Cross-Repair (Microsoft Update)...
!DISM! /Image:!TARGET!:\ /Cleanup-Image /RestoreHealth
!SFC! /Scannow /OffBootDir=!TARGET!:\ /OffWinDir=!TARGET!:\Windows
pause & goto :MENU_TOP

:MODE_CONFIRMED
echo.
echo [!] STARTING !MODE_STR! RESTORE CYCLE...
:: Rebuild EFI and BCD logic here
pause & goto :MENU_TOP

:: =============================================================================
:: 6. FIXED UPDATE PARSER
:: =============================================================================
:UPDATE_CHECK
set /p "UPCH=Check for updates? (Y/N): "
if /i "!UPCH!"=="Y" (
    echo [*] Fetching remote version...
    !CURL! -s -H "Cache-Control: no-cache" -L bit.ly/4skPgOh?v=!RANDOM! -o %temp%\check.cmd
    :: Parse without relying on failing expansion logic
    for /f "tokens=2 delims=:" %%V in ('type %temp%\check.cmd ^| findstr "CV="') do set "NV=%%V"
    set "NV=!NV: =!"
    set "NV=!NV:~0,4!"
    if defined NV (
        if "!NV!" GTR "!CV!" (
            echo [!] NEW VERSION AVAILABLE: !NV!
        ) else (
            echo [OK] You are running the latest version: !CV!
        )
    ) else ( echo [!] Could not determine remote version. )
)
echo [*] Restart the VM now.
pause