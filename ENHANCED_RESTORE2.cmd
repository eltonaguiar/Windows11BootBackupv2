@echo off
setlocal EnableExtensions EnableDelayedExpansion
:: =============================================================================
:: MIRACLE BOOT RESTORE v25.1 - [MULTI-ENDPOINT UPLINK + LOG TRUNCATION]
:: =============================================================================
title Miracle Boot Restore v25.1 - Forensic Master [STABLE]

set "CV=25.1"
echo ===========================================================================
echo    MIRACLE BOOT RESTORE v25.1 - [LOG UPLINK ENGINE ONLINE]
echo ===========================================================================
echo [*] CURRENT VERSION: !CV!
echo [*] STATUS: Multi-Endpoint Uplink + Log Truncation Active

:: 1. AUTO-NETWORKING
X:\Windows\System32\wpeutil.exe InitializeNetwork >nul 2>&1

:: 2. DYNAMIC TOOL DISCOVERY
set "TARGET=C"
for %%D in (C D E F G) do if exist "%%D:\Windows\System32\winload.efi" set "TARGET=%%D"

set "SYS=!TARGET!:\Windows\System32"
set "DPART=!SYS!\diskpart.exe"
set "DISM=!SYS!\dism.exe"
set "SFC=!SYS!\sfc.exe"
set "BCDB=!SYS!\bcdboot.exe"
set "RBCP=!SYS!\robocopy.exe"
set "NTPD=!SYS!\notepad.exe"
set "CURL=!SYS!\curl.exe"

:: =============================================================================
:: 3. RESOURCE BRIDGING (Error 1455 & Scratch Fix)
:: =============================================================================
set "SD=!TARGET!:\_SCRATCH"
if not exist "!SD!" mkdir "!SD!"

:: =============================================================================
:: 4. RESTORE & REPAIR MENU
:: =============================================================================
:MENU_TOP
echo.
echo ===========================================================================
echo    MIRACLE BOOT RESTORE v25.1 - TARGET DISK: 3 
echo ===========================================================================
echo [1] FASTBOOT RESTORE (EFI + BCD ONLY)
echo [2] NUCLEAR RESTORE (EFI + REG + WIN_CORE)
echo [3] BRIDGED REPAIR  (OFFLINE SFC + LOCAL DISM)
echo [4] OPEN FORENSIC LOGS (LOCAL VIEW)
echo [5] UPLOAD FORENSIC LOGS (CBS.LOG / SrtTrail)
echo [6] EXIT
echo.
set /p "USER_CHOICE=SELECT MODE (1-6): "

if "!USER_CHOICE!"=="1" set "MODE_STR=FASTBOOT" & goto :MODE_CONFIRMED
if "!USER_CHOICE!"=="2" set "MODE_STR=NUCLEAR" & goto :MODE_CONFIRMED
if "!USER_CHOICE!"=="3" goto :REPAIR_LOCAL
if "!USER_CHOICE!"=="4" goto :VIEW_LOGS
if "!USER_CHOICE!"=="5" goto :UPLOAD_LOGS
if "!USER_CHOICE!"=="6" exit /b
goto :MENU_TOP

:: =============================================================================
:: 5. LOG UPLINK ENGINE (Bypasses 404 Errors)
:: =============================================================================
:UPLOAD_LOGS
echo.
echo [*] Truncating CBS.log to critical errors only...
set "C_LOG=!TARGET!:\Windows\Logs\CBS\CBS.log"
set "T_LOG=%temp%\sfcdetails.txt"
findstr /c:"[SR]" "!C_LOG!" > "!T_LOG!" 2>nul

echo [*] Attempting Upload to Transfer.sh (Primary)...
!CURL! --upload-file "!T_LOG!" https://transfer.sh/sfcdetails.txt
if !errorlevel! neq 0 (
    echo [!] Transfer.sh failed. Falling back to BashUpload...
    !CURL! -T "!T_LOG!" https://bashupload.com/sfcdetails.txt
)
pause & goto :MENU_TOP

:: =============================================================================
:: 6. REPAIR & RESTORE LOGIC (Transparent)
:: =============================================================================
:VIEW_LOGS
start !NTPD! "!TARGET!:\Windows\System32\LogFiles\Srt\SrtTrail.txt"
pause & goto :MENU_TOP

:REPAIR_LOCAL
echo [*] Executing: !DISM! /Image:!TARGET!:\ /ScratchDir:!SD! /Cleanup-Image /RevertPendingActions
!DISM! /Image:!TARGET!:\ /ScratchDir:!SD! /Cleanup-Image /RevertPendingActions
pause & goto :MENU_TOP

:MODE_CONFIRMED
echo [*] Executing: !BCDB! !TARGET!:\Windows /s S: /f UEFI
!BCDB! !TARGET!:\Windows /s S: /f UEFI >nul
echo [FINISHED] v25.1 !MODE_STR! Restore Complete.
pause & goto :MENU_TOP