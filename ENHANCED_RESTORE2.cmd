@echo off
setlocal EnableExtensions EnableDelayedExpansion
:: =============================================================================
:: MIRACLE BOOT RESTORE v30.9 - GEMINI EDITION
:: [ZERO-EXTERNAL-TOOL DEPENDENCY / PURE NATIVE BATCH]
:: =============================================================================
title Miracle Boot Restore v30.9 - GEMINI EDITION [STABLE]

set "CV=30.9 - GEMINI EDITION"
echo ===========================================================================
echo    MIRACLE BOOT RESTORE v30.9 - [TOTAL NATIVE ENGINE ONLINE]
echo ===========================================================================

:: 1. CORE TOOLS (Absolute Paths Only)
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

:: 3. BACKUP & NATIVE MEDIA SWEEP (NO FINDSTR)
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

echo [*] Scanning drives for Windows 11 ISO (Native Sweep)...
set "W_SRC=" & set "W_IDX=1"
for %%D in (C D E F G H I J K) do (
    if not defined W_SRC if exist "%%D:\sources\install.wim" set "W_SRC=%%D:\sources\install.wim"
    if not defined W_SRC if exist "%%D:\sources\install.esd" set "W_SRC=%%D:\sources\install.esd"
    if not defined W_SRC if exist "%%D:\install.wim" set "W_SRC=%%D:\install.wim"
    if not defined W_SRC if exist "%%D:\install.esd" set "W_SRC=%%D:\install.esd"
)
if defined W_SRC (
    echo [OK] Found Media: !W_SRC!
    call :AUTO_WIM_INDEX_NATIVE
) else (
    echo [WARN] No ISO detected. DISM will run in limited mode.
)

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
:: 5. NATIVE DISM REPAIR (NO EXTERNAL TOOLS)
:: =============================================================================
:REPAIR_REAL
set "SD=!TARGET_OS!:\_DISM_SCRATCH"
if exist "!SD!" rd /s /q "!SD!"
mkdir "!SD!"

if not defined W_SRC goto :DISM_NO_SOURCE

:: Native extension check
set "STAG=WIM"
set "EXT_CHK=!W_SRC:.esd=!"
if not "!EXT_CHK!"=="!W_SRC!" set "STAG=ESD"

echo [*] DISM: /RestoreHealth (Source: !W_SRC! Index: !W_IDX!)...
!DISM! /Image:!TARGET_OS!:\ /ScratchDir:!SD! /Cleanup-Image /RestoreHealth /Source:!STAG!:!W_SRC!:!W_IDX! /LimitAccess
goto :SFC_STEP

:DISM_NO_SOURCE
echo [WARN] No source. Running standard DISM...
!DISM! /Image:!TARGET_OS!:\ /ScratchDir:!SD! /Cleanup-Image /RestoreHealth

:SFC_STEP
echo [*] SFC Check...
!SFC! /scannow /offbootdir=!TARGET_OS!:\ /offwindir=!TARGET_OS!:\Windows
pause & goto :MENU_TOP

:DRIVER_RESTORE
set "SD=!TARGET_OS!:\_DISM_DRIVERS"
if exist "!SD!" rd /s /q "!SD!"
mkdir "!SD!"
if not exist "!BKP!\Drivers" ( echo [!] Drivers folder missing. & pause & goto :MENU_TOP )
!DISM! /Image:!TARGET_OS!:\ /ScratchDir:!SD! /Add-Driver /Driver:"!BKP!\Drivers" /Recurse
pause & goto :MENU_TOP

:: =============================================================================
:: 6. ATOMIC EXECUTION (EFI UNLOCK)
:: =============================================================================
:EXECUTE
echo [*] UNLOCKING EFI...
mountvol S: /d >nul 2>&1
for /L %%V in (0,1,20) do (
    (echo select volume %%V ^& echo assign letter=S) | "!DPART!" >nul 2>&1
    if exist "S:\EFI\Microsoft\Boot" (
        set "E_VOL=%%V"
        (echo select volume !E_VOL! ^& echo attributes volume clear readonly ^& echo attributes partition clear readonly) | "!DPART!" >nul 2>&1
        goto :MOUNT_OK
    )
    mountvol S: /d >nul 2>&1
)
echo [!] ERROR: No EFI found. & pause & goto :MENU_TOP

:MOUNT_OK
!RBCP! "!BKP!\EFI" "S:\EFI" /S /E /B /NP /R:1 /W:1 /COPY:DAT
if errorlevel 8 (
    echo [!] Lock detected. Retrying forced deletion...
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
:: HELPERS (100% NATIVE)
:: =============================================================================

:AUTO_WIM_INDEX_NATIVE
set "MATCH_ED=!T_ED!"
if /i "!MATCH_ED!"=="Professional" set "MATCH_ED=Pro"
if /i "!MATCH_ED!"=="Core" set "MATCH_ED=Home"
set "CUR_IDX="
:: Use native delimiter parsing for DISM output (No findstr)
for /f "usebackq delims=" %%L in (`"!DISM! /English /Get-WimInfo /WimFile:"!W_SRC!" 2^>nul"`) do (
    set "LINE=%%L"
    if not "!LINE:Index :=!"=="!LINE!" (
        for /f "tokens=2 delims=:" %%X in ("!LINE!") do set "CUR_IDX=%%X"
        set "CUR_IDX=!CUR_IDX: =!"
    )
    if not "!LINE:Name :=!"=="!LINE!" (
        if not "!LINE:!MATCH_ED!=!"=="!LINE!" (
            if defined CUR_IDX set "W_IDX=!CUR_IDX!"
        )
    )
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

:NUCLEAR
set /p "C_STR=Type BRICKME to continue: "
if /i "!C_STR!"=="BRICKME" (
    ren "!TARGET_OS!:\Windows\System32\config\SYSTEM" "SYSTEM.old_%RANDOM%" >nul 2>&1
    copy /y "!BKP!\Hives\SYSTEM" "!TARGET_OS!:\Windows\System32\config\SYSTEM" >nul
    set "MS=NUCLEAR" & goto :EXECUTE
)
goto :MENU_TOP