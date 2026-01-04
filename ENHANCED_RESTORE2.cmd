@echo off
setlocal EnableExtensions EnableDelayedExpansion
:: =============================================================================
:: MIRACLE BOOT RESTORE v29.9 - [ZERO-TOOL DEPENDENCY / GHOST WinRE SAFE]
:: =============================================================================
title Miracle Boot Restore v29.9 - Forensic Master [STABLE]

set "CV=29.9"
echo ===========================================================================
echo    MIRACLE BOOT RESTORE v29.9 - [NATIVE COMMAND ENGINE ONLINE]
echo ===========================================================================

:: 1. CORE REPAIR TOOLS (Absolute Paths)
set "X_SYS=X:\Windows\System32"
set "DPART=!X_SYS!\diskpart.exe"
set "BCDB=!X_SYS!\bcdboot.exe"
set "BCDE=!X_SYS!\bcdedit.exe"
set "RBCP=!X_SYS!\robocopy.exe"
set "DISM=!X_SYS!\dism.exe"
set "SFC=!X_SYS!\sfc.exe"
set "REG=!X_SYS!\reg.exe"

:: 2. DYNAMIC OS DISCOVERY (NATIVE SCAN - NO FINDSTR)
set "B_ROOT="
for %%D in (C D E F G H I J) do (
    if not defined B_ROOT if exist "%%D:\MIRACLE_BOOT_FIXER" set "B_ROOT=%%D:\MIRACLE_BOOT_FIXER"
)
if not defined B_ROOT ( echo [!] ERROR: \MIRACLE_BOOT_FIXER not found. & pause & exit /b 1 )

:: Native Timestamp (Replacing broken WMIC)
set "L_DIR=!B_ROOT!\_MiracleLogs\Session_!RANDOM!!RANDOM!"
mkdir "!L_DIR!" >nul 2>&1

echo.
echo [SCAN] Detecting Windows Installations...
set "OS_COUNT=0"
for %%D in (C D E F G H I J) do (
    if exist "%%D:\Windows\System32\winload.efi" (
        set /a OS_COUNT+=1
        if !OS_COUNT! LEQ 8 (
            set "OS!OS_COUNT!=%%D"
            call :PRINT_OS_NATIVE %%D !OS_COUNT!
        )
    )
)
if "!OS_COUNT!"=="0" ( echo [!] ERROR: No Windows detected. & pause & exit /b 1 )

:: NATIVE SELECTION LOOP (Replacing broken 'choice')
:OS_PICK
set "SEL="
set /p "SEL=Select OS number (1-!OS_COUNT!): "
if not defined SEL goto :OS_PICK
set "TARGET_OS="
for %%N in (!SEL!) do (
    set "TARGET_OS=!OS%%N!"
    set "T_ED=!ED%%N!"
    set "T_BD=!BD%%N!"
)
if not defined TARGET_OS ( echo [!] Invalid selection. & goto :OS_PICK )

echo.
echo [SAFETY] Target: !TARGET_OS!: (!T_ED! !T_BD!)
set /p "GO=Proceed? (Y/N): "
if /i not "!GO!"=="Y" ( echo [ABORTED] & pause & exit /b 0 )

:: =============================================================================
:: 3. NATIVE METADATA MATCHING (NO FINDSTR)
:: =============================================================================
set "BKP=" & set "B_FOLDER="
for /f "delims=" %%F in ('dir /ad /b /o-d "!B_ROOT!" 2^>nul') do (
    set "M_FILE=!B_ROOT!\%%F\OS_ID.txt"
    if exist "!M_FILE!" (
        set "HAS_ED=0" & set "HAS_BD=0"
        for /f "usebackq delims=" %%L in ("!M_FILE!") do (
            set "LINE=%%L"
            :: Use native substring removal to check for matches
            if not "!LINE:EditionID=!T_ED!=!"=="!LINE!" set "HAS_ED=1"
            if not "!LINE:CurrentBuildNumber=!T_BD!=!"=="!LINE!" set "HAS_BD=1"
        )
        if "!HAS_ED!!HAS_BD!"=="11" ( set "BKP=!B_ROOT!\%%F" & set "B_FOLDER=%%F" & goto :BKP_FOUND )
    )
)
:: Drive letter fallback
set "T_LET=!TARGET_OS::=!"
for /f "delims=" %%F in ('dir /ad /b /o-d "!B_ROOT!" 2^>nul') do (
    set "FN=%%F"
    if not "!FN:_!T_LET!=!"=="!FN!" ( set "BKP=!B_ROOT!\%%F" & set "B_FOLDER=%%F" & goto :BKP_FOUND )
)
echo [!] ERROR: No matching backup found. & pause & exit /b 1
:BKP_FOUND

:: =============================================================================
:: 4. REPAIR MENU (NATIVE)
:: =============================================================================
:MENU_TOP
echo.
echo ===========================================================================
echo    !CV! - !B_FOLDER! --^> !TARGET_OS!:
echo ===========================================================================
echo [1] FASTBOOT RESTORE (EFI + BCD)
echo [2] DISM REPAIR (SFC ONLY)
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
!SFC! /scannow /offbootdir=!TARGET_OS!:\ /offwindir=!TARGET_OS!:\Windows >> "!L_DIR!\sfc.log" 2>&1
pause & goto :MENU_TOP

:: =============================================================================
:: 5. ATOMIC EXECUTION (NATIVE MOUNT)
:: =============================================================================
:EXECUTE
echo [*] SCANNING FOR EFI PARTITION...
mountvol S: /d >nul 2>&1
:: Cycle all possible volumes natively since findstr is dead
for /L %%V in (0,1,20) do (
    (echo select volume %%V ^& echo assign letter=S) | "!DPART!" >nul 2>&1
    if exist "S:\EFI\Microsoft\Boot" ( echo [OK] Found EFI on Vol %%V. & goto :MOUNT_OK )
    if exist "S:\EFI\Boot" ( echo [OK] Found Fallback EFI on Vol %%V. & goto :MOUNT_OK )
    mountvol S: /d >nul 2>&1
)
echo [!] ERROR: Could not find EFI. & pause & goto :MENU_TOP

:MOUNT_OK
!RBCP! "!BKP!\EFI" "S:\EFI" /E /B /R:1 /W:1 /NP >> "!L_DIR!\restore.log" 2>&1
set "RC=!errorlevel!"
if !RC! GEQ 8 ( echo [!] Robocopy failed. & pause & goto :MENU_TOP )

!BCDB! !TARGET_OS!:\Windows /s S: /f UEFI >> "!L_DIR!\restore.log" 2>&1
!BCDE! /store "S:\EFI\Microsoft\Boot\BCD" /set {default} device partition=!TARGET_OS!: >> "!L_DIR!\restore.log" 2>&1
!BCDE! /store "S:\EFI\Microsoft\Boot\BCD" /set {default} osdevice partition=!TARGET_OS!: >> "!L_DIR!\restore.log" 2>&1

mountvol S: /d >nul 2>&1
echo [FINISHED] Restore Complete. Logs in !L_DIR!
pause & goto :MENU_TOP

:: =============================================================================
:: HELPERS (100% NATIVE)
:: =============================================================================

:PRINT_OS_NATIVE
set "D=%~1" & set "N=%~2" & set "PN=Windows" & set "ED=Unknown" & set "BD=0"
!REG! load HKLM\OFFSOFT "%D%:\Windows\System32\config\SOFTWARE" >nul 2>&1
if not errorlevel 1 (
    for /f "tokens=3" %%A in ('!REG! query "HKLM\OFFSOFT\Microsoft\Windows NT\CurrentVersion" /v EditionID 2^>nul') do set "ED=%%A"
    for /f "tokens=3" %%A in ('!REG! query "HKLM\OFFSOFT\Microsoft\Windows NT\CurrentVersion" /v CurrentBuildNumber 2^>nul') do set "BD=%%A"
    !REG! unload HKLM\OFFSOFT >nul 2>&1
)
set "ED!N!=!ED!" & set "BD!N!=!BD!"
echo [!N!] %D%: - !PN! (!ED! !BD!)
exit /b

:NUCLEAR
set /p "C_STR=Type BRICKME to continue: "
if /i "!C_STR!"=="BRICKME" (
    ren "!TARGET_OS!:\Windows\System32\config\SYSTEM" "SYSTEM.old_%RANDOM%" >nul 2>&1
    copy /y "!BKP!\Hives\SYSTEM" "!TARGET_OS!:\Windows\System32\config\SYSTEM" >> "!L_DIR!\nuclear.log" 2>&1
    set "MS=NUCLEAR" & goto :EXECUTE
)
goto :MENU_TOP