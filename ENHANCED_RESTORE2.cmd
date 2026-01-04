@echo off
setlocal EnableExtensions EnableDelayedExpansion
:: =============================================================================
:: MIRACLE BOOT RESTORE v30.1 - GEMINI EDITION
:: [BRUTE-FORCE PATH DISCOVERY / GHOST WinRE SAFE]
:: =============================================================================
title Miracle Boot Restore v30.1 - GEMINI EDITION [STABLE]

set "CV=30.1 - GEMINI EDITION"
echo ===========================================================================
echo    MIRACLE BOOT RESTORE v30.1 - [DEEP PATH BRUTE-FORCE ACTIVE]
echo ===========================================================================

:: 1. CORE TOOLS (Absolute Paths)
set "X_SYS=X:\Windows\System32"
set "DPART=!X_SYS!\diskpart.exe"
set "BCDB=!X_SYS!\bcdboot.exe"
set "BCDE=!X_SYS!\bcdedit.exe"
set "RBCP=!X_SYS!\robocopy.exe"
set "REG=!X_SYS!\reg.exe"
set "SFC=!X_SYS!\sfc.exe"

:: 2. DYNAMIC OS DISCOVERY
set "B_ROOT="
for %%D in (C D E F G H I J) do (
    if not defined B_ROOT if exist "%%D:\MIRACLE_BOOT_FIXER" set "B_ROOT=%%D:\MIRACLE_BOOT_FIXER"
)
if not defined B_ROOT ( echo [!] ERROR: \MIRACLE_BOOT_FIXER not found. & pause & exit /b 1 )

echo.
echo [SCAN] Detecting Windows Installations...
set "OS_COUNT=0"
for %%D in (C D E F G H I J) do (
    if exist "%%D:\Windows\System32\winload.efi" (
        set /a OS_COUNT+=1
        set "OS!OS_COUNT!=%%D"
        call :PRINT_OS_NATIVE %%D !OS_COUNT!
    )
)
if "!OS_COUNT!"=="0" ( echo [!] ERROR: No Windows detected. & pause & exit /b 1 )

:OS_PICK
set "SEL="
set /p "SEL=Select OS number (1-!OS_COUNT!): "
if not defined SEL goto :OS_PICK
set "TARGET_OS="
for %%N in (!SEL!) do (
    set "TARGET_OS=!OS%%N!"
    set "T_ED=!ED%%N!"
)
if not defined TARGET_OS ( echo [!] Invalid selection. & goto :OS_PICK )

echo.
echo [SAFETY] Target: !TARGET_OS!:
set /p "GO=Proceed? (Y/N): "
if /i not "!GO!"=="Y" ( echo [ABORTED] & pause & exit /b 0 )

:: =============================================================================
:: 3. BRUTE-FORCE BACKUP DISCOVERY (No metadata reliance)
:: =============================================================================
set "BKP=" & set "B_FOLDER="
set "T_LET=!TARGET_OS::=!"

echo [*] Searching for FASTBOOT_!T_LET! folders...
for /f "delims=" %%F in ('dir /ad /b /o-d "!B_ROOT!" 2^>nul') do (
    set "FN=%%F"
    :: Direct match for your specific folder naming pattern
    if not "!FN:_FASTBOOT_!T_LET!=!"=="!FN!" (
        set "BKP=!B_ROOT!\%%F"
        set "B_FOLDER=%%F"
        goto :BKP_FOUND
    )
)

:: Emergency Fallback: If naming fails, take the absolute newest folder
echo [WARN] Direct match failed. Using newest backup folder.
for /f "delims=" %%F in ('dir /ad /b /o-d "!B_ROOT!" 2^>nul') do (
    if not "%%F"=="_MiracleLogs" (
        set "BKP=!B_ROOT!\%%F"
        set "B_FOLDER=%%F"
        goto :BKP_FOUND
    )
)

echo [!] ERROR: No usable backup folders found. & pause & exit /b 1
:BKP_FOUND
echo [OK] Using Backup: !B_FOLDER!

:: =============================================================================
:: 4. REPAIR MENU
:: =============================================================================
:MENU_TOP
echo.
echo ===========================================================================
echo    !CV! - !B_FOLDER! --^> !TARGET_OS!:
echo ===========================================================================
echo [1] FASTBOOT RESTORE (EFI + BCD)
echo [2] REPAIR (SFC ONLY)
echo [3] NUCLEAR SWAP (SYSTEM HIVE)
echo [4] EXIT
echo.
set "M_SEL="
set /p "M_SEL=Select (1-4): "
if "!M_SEL!"=="1" set "MS=FASTBOOT" & goto :EXECUTE
if "!M_SEL!"=="2" goto :REPAIR_SFC
if "!M_SEL!"=="3" goto :NUCLEAR
if "!M_SEL!"=="4" exit /b
goto :MENU_TOP

:REPAIR_SFC
!SFC! /scannow /offbootdir=!TARGET_OS!:\ /offwindir=!TARGET_OS!:\Windows
pause & goto :MENU_TOP

:: =============================================================================
:: 5. ATOMIC EXECUTION (ZERO-PARSING MOUNT)
:: =============================================================================
:EXECUTE
echo [*] SCANNING FOR EFI PARTITION...
mountvol S: /d >nul 2>&1
for /L %%V in (0,1,20) do (
    (echo select volume %%V ^& echo assign letter=S) | "!DPART!" >nul 2>&1
    if exist "S:\EFI\Microsoft\Boot" ( echo [OK] Found EFI on Vol %%V. & goto :MOUNT_OK )
    if exist "S:\EFI\Boot" ( echo [OK] Found EFI on Vol %%V. & goto :MOUNT_OK )
    mountvol S: /d >nul 2>&1
)
echo [!] ERROR: Could not find EFI. & pause & goto :MENU_TOP

:MOUNT_OK
:: Verify backup contents before copy
if not exist "!BKP!\EFI" ( echo [!] ERROR: Backup EFI folder missing. & pause & goto :MENU_TOP )

!RBCP! "!BKP!\EFI" "S:\EFI" /E /B /R:1 /W:1 /NP
!BCDB! !TARGET_OS!:\Windows /s S: /f UEFI
!BCDE! /store "S:\EFI\Microsoft\Boot\BCD" /set {default} device partition=!TARGET_OS!: >nul 2>&1
!BCDE! /store "S:\EFI\Microsoft\Boot\BCD" /set {default} osdevice partition=!TARGET_OS!: >nul 2>&1

mountvol S: /d >nul 2>&1
echo [FINISHED] Restore Complete.
pause & goto :MENU_TOP

:: =============================================================================
:: HELPERS
:: =============================================================================

:PRINT_OS_NATIVE
set "D=%~1" & set "N=%~2" & set "ED=Unknown"
!REG! load HKLM\OFFSOFT "%D%:\Windows\System32\config\SOFTWARE" >nul 2>&1
if not errorlevel 1 (
    :: Hardened token parsing to handle different REG outputs
    for /f "usebackq tokens=1,2,3*" %%A in (`!REG! query "HKLM\OFFSOFT\Microsoft\Windows NT\CurrentVersion" /v EditionID 2^>nul`) do (
        if "%%A"=="EditionID" set "ED=%%C"
    )
    !REG! unload HKLM\OFFSOFT >nul 2>&1
)
set "ED!N!=!ED!"
echo [!N!] %D%: - Windows (!ED!)
exit /b

:NUCLEAR
set /p "C_STR=Type BRICKME to continue: "
if /i "!C_STR!"=="BRICKME" (
    ren "!TARGET_OS!:\Windows\System32\config\SYSTEM" "SYSTEM.old_%RANDOM%" >nul 2>&1
    copy /y "!BKP!\Hives\SYSTEM" "!TARGET_OS!:\Windows\System32\config\SYSTEM" >nul
    set "MS=NUCLEAR" & goto :EXECUTE
)
goto :MENU_TOP