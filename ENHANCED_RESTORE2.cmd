@echo off
setlocal EnableExtensions EnableDelayedExpansion
:: =============================================================================
:: MIRACLE BOOT RESTORE v30.4 - GEMINI EDITION
:: [LINEAR LOGIC FIX / DISM REPAIR / EFI OVERRIDE]
:: =============================================================================
title Miracle Boot Restore v30.4 - GEMINI EDITION [STABLE]

set "CV=30.4 - GEMINI EDITION"
echo ===========================================================================
echo    MIRACLE BOOT RESTORE v30.4 - [LINEAR EXECUTION ENGINE ACTIVE]
echo ===========================================================================

:: 1. CORE TOOLS (Absolute Paths)
set "X_SYS=X:\Windows\System32"
set "DPART=!X_SYS!\diskpart.exe"
set "BCDB=!X_SYS!\bcdboot.exe"
set "BCDE=!X_SYS!\bcdedit.exe"
set "RBCP=!X_SYS!\robocopy.exe"
set "REG=!X_SYS!\reg.exe"
set "SFC=!X_SYS!\sfc.exe"
set "DISM=!X_SYS!\dism.exe"

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

:: =============================================================================
:: 3. BRUTE-FORCE BACKUP & MEDIA DISCOVERY
:: =============================================================================
set "BKP=" & set "B_FOLDER="
set "T_LET=!TARGET_OS::=!"
for /f "delims=" %%F in ('dir /ad /b /o-d "!B_ROOT!" 2^>nul') do (
    set "FN=%%F"
    if not "!FN:_FASTBOOT_!T_LET!=!"=="!FN!" (
        set "BKP=!B_ROOT!\%%F" & set "B_FOLDER=%%F" & goto :BKP_FOUND
    )
)
for /f "delims=" %%F in ('dir /ad /b /o-d "!B_ROOT!" 2^>nul') do (
    if not "%%F"=="_MiracleLogs" (
        set "BKP=!B_ROOT!\%%F" & set "B_FOLDER=%%F" & goto :BKP_FOUND
    )
)
echo [!] ERROR: No backup found. & pause & exit /b 1
:BKP_FOUND

:: INSTALL MEDIA DETECTION FOR DISM REPAIR
set "W_SRC=" & set "W_IDX=1"
for %%D in (C D E F G H I J K) do (
    if exist "%%D:\sources\install.wim" set "W_SRC=%%D:\sources\install.wim" & goto :W_READY
    if exist "%%D:\sources\install.esd" set "W_SRC=%%D:\sources\install.esd" & goto :W_READY
)
:W_READY
if defined W_SRC call :AUTO_WIM_INDEX

:: =============================================================================
:: 4. REPAIR MENU
:: =============================================================================
:MENU_TOP
echo.
echo ===========================================================================
echo    !CV! - !B_FOLDER! --^> !TARGET_OS!:
echo ===========================================================================
echo [1] FASTBOOT RESTORE (EFI + BCD + ATTR OVERRIDE)
echo [2] REAL DISM REPAIR (CLEANUP-IMAGE + SFC)
echo [3] DRIVER INJECTION (DISM ADD-DRIVER)
echo [4] NUCLEAR SWAP (SYSTEM HIVE)
echo [5] EXIT
echo.
set "M_SEL="
set /p "M_SEL=Select (1-5): "
if "!M_SEL!"=="1" set "MS=FASTBOOT" & goto :EXECUTE
if "!M_SEL!"=="2" goto :REPAIR_REAL
if "!M_SEL!"=="3" goto :DRIVER_RESTORE
if "!M_SEL!"=="4" goto :NUCLEAR
if "!M_SEL!"=="5" exit /b
goto :MENU_TOP

:: =============================================================================
:: 5. DISM REPAIR (LINEAR LOGIC FIX)
:: =============================================================================
:REPAIR_REAL
set "SD=!TARGET_OS!:\_SCRATCH" & if not exist "!SD!" mkdir "!SD!"
if not defined W_SRC goto :DISM_NO_SOURCE

:: Use WIM or ESD staging
set "STAG=WIM"
echo !W_SRC! | findstr /i "\.esd" >nul && set "STAG=ESD"

echo [*] Running DISM /RestoreHealth with source...
!DISM! /Image:!TARGET_OS!:\ /ScratchDir:!SD! /Cleanup-Image /RestoreHealth /Source:!STAG!:!W_SRC!:!W_IDX! /LimitAccess
goto :SFC_ONLY

:DISM_NO_SOURCE
echo [WARN] No media detected. Running DISM without source...
!DISM! /Image:!TARGET_OS!:\ /ScratchDir:!SD! /Cleanup-Image /RestoreHealth

:SFC_ONLY
echo [*] Running SFC Integrity Check...
!SFC! /scannow /offbootdir=!TARGET_OS!:\ /offwindir=!TARGET_OS!:\Windows
pause & goto :MENU_TOP

:: =============================================================================
:: 6. ATOMIC EXECUTION (EFI ATTRIBUTE OVERRIDE)
:: =============================================================================
:EXECUTE
echo [*] SCANNING AND UNLOCKING EFI...
mountvol S: /d >nul 2>&1
for /L %%V in (0,1,20) do (
    (echo select volume %%V ^& echo assign letter=S) | "!DPART!" >nul 2>&1
    if exist "S:\EFI\Microsoft\Boot" (
        set "E_VOL=%%V"
        (echo select volume !E_VOL! ^& echo attributes volume clear readonly ^& echo attributes partition clear readonly) | "!DPART!" >nul 2>&1
        echo [OK] Unlocked EFI on Volume !E_VOL!.
        goto :MOUNT_OK
    )
    mountvol S: /d >nul 2>&1
)
echo [!] ERROR: Could not find EFI. & pause & goto :MENU_TOP

:MOUNT_OK
:: Robust Transfer
!RBCP! "!BKP!\EFI" "S:\EFI" /S /E /B /NP /R:1 /W:1 /COPY:DAT
if errorlevel 8 (
    echo [!] ACCESS DENIED. Attempting physical file deletion...
    del /s /f /q S:\EFI\*.* >nul 2>&1
    !RBCP! "!BKP!\EFI" "S:\EFI" /S /E /B /NP /R:1 /W:1 /COPY:DAT
)

!BCDB! !TARGET_OS!:\Windows /s S: /f UEFI
!BCDE! /store "S:\EFI\Microsoft\Boot\BCD" /set {default} device partition=!TARGET_OS!: >nul 2>&1
!BCDE! /store "S:\EFI\Microsoft\Boot\BCD" /set {default} osdevice partition=!TARGET_OS!: >nul 2>&1

mountvol S: /d >nul 2>&1
echo [FINISHED] Restore Complete.
pause & goto :MENU_TOP

:: =============================================================================
:: HELPERS
:: =============================================================================

:AUTO_WIM_INDEX
set "MATCH_ED=!T_ED!"
if /i "!MATCH_ED!"=="Professional" set "MATCH_ED=Pro"
if /i "!MATCH_ED!"=="Core" set "MATCH_ED=Home"
set "CUR_IDX="
for /f "usebackq delims=" %%L in (`"!DISM! /English /Get-WimInfo /WimFile:"!W_SRC!" 2^>nul"`) do (
    echo %%L | findstr /i "Index :" >nul && (for /f "tokens=2 delims=:" %%X in ("%%L") do set "CUR_IDX=%%X" & set "CUR_IDX=!CUR_IDX: =!")
    echo %%L | findstr /i "Name :" >nul && (set "NM=%%L" & echo !NM! | findstr /i "!MATCH_ED!" >nul && (if defined CUR_IDX set "W_IDX=!CUR_IDX!"))
)
exit /b 0

:PRINT_OS_NATIVE
set "D=%~1" & set "N=%~2" & set "ED=Unknown"
!REG! load HKLM\OFFSOFT "%D%:\Windows\System32\config\SOFTWARE" >nul 2>&1
if not errorlevel 1 (
    for /f "usebackq tokens=1,2,3*" %%A in (`!REG! query "HKLM\OFFSOFT\Microsoft\Windows NT\CurrentVersion" /v EditionID 2^>nul`) do (
        if "%%A"=="EditionID" set "ED=%%C"
    )
    !REG! unload HKLM\OFFSOFT >nul 2>&1
)
set "ED!N!=!ED!"
echo [!N!] %D%: - Windows (!ED!)
exit /b

:DRIVER_RESTORE
if exist "!BKP!\Drivers" ( !DISM! /Image:!TARGET_OS!:\ /Add-Driver /Driver:"!BKP!\Drivers" /Recurse )
pause & goto :MENU_TOP

:NUCLEAR
set /p "C_STR=Type BRICKME to continue: "
if /i "!C_STR!"=="BRICKME" (
    ren "!TARGET_OS!:\Windows\System32\config\SYSTEM" "SYSTEM.old_%RANDOM%" >nul 2>&1
    copy /y "!BKP!\Hives\SYSTEM" "!TARGET_OS!:\Windows\System32\config\SYSTEM" >nul
    set "MS=NUCLEAR" & goto :EXECUTE
)
goto :MENU_TOP