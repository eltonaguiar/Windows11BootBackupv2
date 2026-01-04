@echo off
setlocal EnableExtensions EnableDelayedExpansion
:: =============================================================================
:: MIRACLE BOOT RESTORE v28.1 - [STABLE MOUNT + DISM DRIVERS + ERROR GUARDS]
:: =============================================================================
title Miracle Boot Restore v28.1 - Forensic Master [STABLE]

set "CV=28.1"
echo ===========================================================================
echo    MIRACLE BOOT RESTORE v28.1 - [STRICT INTEGRITY ENGINE ONLINE]
echo ===========================================================================

:: WINPE DETECTION GUARD
reg query "HKLM\Software\Microsoft\Windows NT\CurrentVersion\WinPE" >nul 2>&1
if errorlevel 1 ( echo [!] ERROR: Script restricted to WinPE/WinRE. & pause & exit /b 1 )

:: 1. WINRE CORE TOOLS
set "X_SYS=X:\Windows\System32"
set "DPART=!X_SYS!\diskpart.exe"
set "BCDB=!X_SYS!\bcdboot.exe"
set "BCDE=!X_SYS!\bcdedit.exe"
set "RBCP=!X_SYS!\robocopy.exe"
set "DISM=!X_SYS!\dism.exe"
set "SFC=!X_SYS!\sfc.exe"
set "FSTR=!X_SYS!\findstr.exe"

:: 2. AUTO-NETWORK INITIALIZATION
!X_SYS!\wpeutil.exe InitializeNetwork >nul 2>&1

:: =============================================================================
:: 3. DYNAMIC OS DISCOVERY
:: =============================================================================
set "BKP_ROOT="
for %%D in (C D E F G H I J) do (
    if not defined BKP_ROOT if exist "%%D:\MIRACLE_BOOT_FIXER" set "BKP_ROOT=%%D:\MIRACLE_BOOT_FIXER"
)
if not defined BKP_ROOT ( echo [!] ERROR: \MIRACLE_BOOT_FIXER not found. & pause & exit /b 1 )

echo.
echo =======================================================================
echo [SCAN] Detected Windows Installations (C..J)
echo =======================================================================
set "OS_COUNT=0"
for %%D in (C D E F G H I J) do (
    if exist "%%D:\Windows\System32\winload.efi" (
        set /a OS_COUNT+=1
        if !OS_COUNT! LEQ 8 (
            set "OS!OS_COUNT!=%%D"
            call :PRINT_OS %%D !OS_COUNT!
        )
    )
)
if "!OS_COUNT!"=="0" ( echo [!] ERROR: No Windows installs detected. & pause & exit /b 1 )
echo.
choice /c 12345678 /n /m "Select target OS (1-!OS_COUNT!): "
set "SEL=%errorlevel%"
for %%N in (!SEL!) do (
    set "TARGET_OS=!OS%%N!!"
    set "T_ED=!ED%%N!"
    set "T_BD=!BD%%N!"
)

echo.
echo [SAFETY] Selected Target: !TARGET_OS!: (!T_ED! !T_BD!)
choice /c YN /m "Proceed with recovery? "
if errorlevel 2 ( echo [ABORTED] & pause & exit /b 0 )

:: =============================================================================
:: 4. STABLE METADATA MATCHING (FIXED CROSS-LINE)
:: =============================================================================
set "BKP=" & set "B_FOLDER="
echo [*] Matching backup by Edition/Build metadata...
for /f "delims=" %%F in ('dir /ad /b /o-d "!BKP_ROOT!" 2^>nul') do (
    set "M_FILE=!BKP_ROOT!\%%F\OS_ID.txt"
    if exist "!M_FILE!" (
        set "HAS_ED=0" & set "HAS_BD=0"
        for /f "usebackq delims=" %%L in ("!M_FILE!") do (
            echo %%L | !FSTR! /i "EditionID" >nul && echo %%L | !FSTR! /i "!T_ED!" >nul && set "HAS_ED=1"
            echo %%L | !FSTR! /i "CurrentBuildNumber" >nul && echo %%L | !FSTR! /i "!T_BD!" >nul && set "HAS_BD=1"
        )
        if "!HAS_ED!!HAS_BD!"=="11" ( set "BKP=!BKP_ROOT!\%%F" & set "B_FOLDER=%%F" & goto :BKP_FOUND )
    )
)
:: Letter fallback
set "T_LET=!TARGET_OS!" & set "T_LET=!T_LET::=!"
for /f "delims=" %%F in ('dir /ad /b /o-d "!BKP_ROOT!" 2^>nul') do (
    echo %%F | !FSTR! /i "_!T_LET!" >nul && ( set "BKP=!BKP_ROOT!\%%F" & set "B_FOLDER=%%F" & goto :BKP_FOUND )
)
echo [!] ERROR: No matching backup found. & pause & exit /b 1
:BKP_FOUND

:: =============================================================================
:: 5. FORENSIC RESTORE MENU
:: =============================================================================
:MENU_TOP
echo.
echo ===========================================================================
echo    !CV! - !B_FOLDER! --^> !TARGET_OS!:
echo ===========================================================================
echo [1] FASTBOOT RESTORE (EFI + BCD REBUILD)
echo [2] DRIVER INJECTION (DISM ADD-DRIVER)
echo [3] REAL REPAIR MODE (DISM + SFC)
echo [4] LAST RESORT (NUCLEAR SWAP)
echo [5] EXIT
echo.
choice /c 12345 /n /m "Select (1-5): "
set "MENU_CHOICE=%errorlevel%"

if "!MENU_CHOICE!"=="1" set "MS=FASTBOOT" & goto :EXECUTE
if "!MENU_CHOICE!"=="2" goto :DRIVER_RESTORE
if "!MENU_CHOICE!"=="3" goto :REPAIR_REAL
if "!MENU_CHOICE!"=="4" goto :NUCLEAR_LAST_RESORT
if "!MENU_CHOICE!"=="5" exit /b
goto :MENU_TOP

:: =============================================================================
:: 6. DRIVER RESTORE (DISM-NATIVE)
:: =============================================================================
:DRIVER_RESTORE
if exist "!BKP!\Drivers" (
    echo [*] Injecting drivers via DISM Add-Driver...
    !DISM! /Image:!TARGET_OS!:\ /Add-Driver /Driver:"!BKP!\Drivers" /Recurse
) else ( echo [!] No Drivers folder found in backup. )
pause & goto :MENU_TOP

:REPAIR_REAL
set "SD=!TARGET_OS!:\_SCRATCH" & if not exist "!SD!" mkdir "!SD!"
!DISM! /Image:!TARGET_OS!:\ /ScratchDir:!SD! /Cleanup-Image /RestoreHealth
!SFC! /scannow /offbootdir=!TARGET_OS!:\ /offwindir=!TARGET_OS!:\Windows
pause & goto :MENU_TOP

:: =============================================================================
:: 7. EXECUTION ENGINE (VERIFIED SUCCESS)
:: =============================================================================
:EXECUTE
echo.
echo [*] AUTO-DETECTING EFI SYSTEM PARTITION...
call :AUTO_MOUNT_EFI
if errorlevel 1 ( echo [!] ERROR: EFI not found. & pause & goto :MENU_TOP )

:: Backup Integrity Audit
if not exist "!BKP!\EFI\Microsoft" ( echo [!] ERROR: EFI backup missing. & pause & goto :MENU_TOP )

!RBCP! "!BKP!\EFI" "S:\EFI" /E /B /R:1 /W:1 /NP >nul
if %errorlevel% GEQ 8 ( echo [!] ERROR: EFI Robocopy failed. & pause & goto :MENU_TOP )

!BCDB! !TARGET_OS!:\Windows /s S: /f UEFI >nul
if errorlevel 1 ( echo [!] ERROR: Bcdboot failed. & pause & goto :MENU_TOP )

!BCDE! /store "S:\EFI\Microsoft\Boot\BCD" /set {default} device partition=!TARGET_OS!: >nul 2>&1
!BCDE! /store "S:\EFI\Microsoft\Boot\BCD" /set {default} osdevice partition=!TARGET_OS!: >nul 2>&1
!BCDE! /store "S:\EFI\Microsoft\Boot\BCD" /displayorder {default} /addfirst >nul 2>&1
mountvol S: /d >nul 2>&1
echo [FINISHED] Restore Complete.
pause & goto :MENU_TOP

:NUCLEAR_LAST_RESORT
set /p "CONFIRM=Type BRICKME to continue: "
if /i "!CONFIRM!"=="BRICKME" (
    set "OLD_HIVE=SYSTEM.old_!random!"
    ren "!TARGET_OS!:\Windows\System32\config\SYSTEM" "!OLD_HIVE!" >nul 2>&1
    copy /y "!BKP!\Hives\SYSTEM" "!TARGET_OS!:\Windows\System32\config\SYSTEM" >nul
    !RBCP! "!BKP!\WIN_CORE\SYSTEM32" "!TARGET_OS!:\Windows\System32" /E /B /R:1 /W:1 /NP >nul
    if %errorlevel% GEQ 8 (
        echo [!] robocopy failed. Rolling back SYSTEM hive...
        ren "!TARGET_OS!:\Windows\System32\config\!OLD_HIVE!" "SYSTEM" >nul 2>&1
    )
    set "MS=NUCLEAR" & goto :EXECUTE
)
goto :MENU_TOP

:: =============================================================================
:: HELPER: STABLE AUTO-MOUNT EFI
:: =============================================================================
:AUTO_MOUNT_EFI
mountvol S: /d >nul 2>&1
for /f "tokens=2 delims= " %%V in ('echo list volume ^| "!DPART!" ^| "!FSTR!" /i "Volume" ^| "!FSTR!" /i "FAT32"') do (
    (echo select volume %%V ^& echo assign letter=S) | "!DPART!" >nul 2>&1
    if exist "S:\EFI\Microsoft" ( exit /b 0 )
    mountvol S: /d >nul 2>&1
)
exit /b 1

:PRINT_OS
set "D=%~1" & set "N=%~2" & set "PN=" & set "ED=" & set "BD="
reg load HKLM\OFFSOFT "%D%:\Windows\System32\config\SOFTWARE" >nul 2>&1
if not errorlevel 1 (
    for /f "tokens=2,*" %%A in ('reg query "HKLM\OFFSOFT\Microsoft\Windows NT\CurrentVersion" /v ProductName 2^>nul ^| !FSTR! /i "ProductName"') do set "PN=%%B"
    for /f "tokens=2,*" %%A in ('reg query "HKLM\OFFSOFT\Microsoft\Windows NT\CurrentVersion" /v EditionID 2^>nul ^| !FSTR! /i "EditionID"') do set "ED=%%B"
    for /f "tokens=2,*" %%A in ('reg query "HKLM\OFFSOFT\Microsoft\Windows NT\CurrentVersion" /v CurrentBuildNumber 2^>nul ^| !FSTR! /i "CurrentBuildNumber"') do set "BD=%%B"
    reg unload HKLM\OFFSOFT >nul 2>&1
)
set "ED!N!=!ED!" & set "BD!N!=!BD!"
echo [!N!] %D%: - !PN! (!ED! !BD!)
exit /b