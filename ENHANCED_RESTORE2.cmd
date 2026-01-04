@echo off
setlocal EnableExtensions EnableDelayedExpansion
:: =============================================================================
:: MIRACLE BOOT RESTORE v29.7 - [TOOL RESOLUTION + WIM NORMALIZATION]
:: =============================================================================
title Miracle Boot Restore v29.7 - Forensic Master [STABLE]

set "CV=29.7"
echo ===========================================================================
echo    MIRACLE BOOT RESTORE v29.7 - [FINAL RECOVERY SUITE]
echo ===========================================================================

:: 0. WINPE DETECTION GUARD
reg query "HKLM\Software\Microsoft\Windows NT\CurrentVersion\WinPE" >nul 2>&1
if errorlevel 1 ( echo [!] ERROR: Script restricted to WinPE/WinRE. & pause & exit /b 1 )

:: 1. TOOL RESOLUTION ENGINE (HARDENED)
set "X_SYS=X:\Windows\System32"
set "DPART=!X_SYS!\diskpart.exe"
set "BCDB=!X_SYS!\bcdboot.exe"
set "BCDE=!X_SYS!\bcdedit.exe"
set "RBCP=!X_SYS!\robocopy.exe"
set "DISM=!X_SYS!\dism.exe"
set "SFC=!X_SYS!\sfc.exe"
set "FSTR=!X_SYS!\findstr.exe"
set "WMIC=!X_SYS!\wbem\wmic.exe"

:: 1.1 TRY HARD TO RESOLVE FINDSTR
if not exist "!FSTR!" ( if exist "X:\Windows\System32\findstr.exe" set "FSTR=X:\Windows\System32\findstr.exe" )
if not exist "!FSTR!" ( where findstr >nul 2>&1 && set "FSTR=findstr" )
if not exist "!FSTR!" ( echo [FATAL] findstr missing. This WinRE is too minimal. & pause & exit /b 1 )

set "NO_CHOICE=" & if not exist "!X_SYS!\choice.exe" ( echo [WARN] choice.exe missing. Native fallback active. & set "NO_CHOICE=1" )
set "NO_WMIC=" & if not exist "!WMIC!" ( echo [WARN] wmic.exe missing. Randomizing TS. & set "NO_WMIC=1" )

:: 2. AUTO-NETWORK INITIALIZATION
!X_SYS!\wpeutil.exe InitializeNetwork >nul 2>&1

:: =============================================================================
:: 3. ENVIRONMENT SETUP (FORENSIC LOGS)
:: =============================================================================
set "B_ROOT="
for %%D in (C D E F G H I J) do ( if not defined B_ROOT if exist "%%D:\MIRACLE_BOOT_FIXER" set "B_ROOT=%%D:\MIRACLE_BOOT_FIXER" )
if not defined B_ROOT ( echo [!] ERROR: \MIRACLE_BOOT_FIXER not found. & pause & exit /b 1 )

:: 3.1 PADDED TIMESTAMP LOG VAULT
set "TS="
if not defined NO_WMIC ( for /f "tokens=*" %%i in ('"!WMIC!" os get localdatetime 2^>nul ^| "!FSTR!" /r "[0-9]"') do set "TS=%%i" )
if not defined TS ( set "TS=00000000!RANDOM!!RANDOM!!RANDOM!" & set "TS=!TS:~-14!" )
set "L_DIR=!B_ROOT!\_MiracleLogs\!TS:~0,8!_!TS:~8,6!"
mkdir "!L_DIR!" >nul 2>&1

echo.
echo =======================================================================
echo [SCAN] Detected Windows Installations (C..J)
echo =======================================================================
set "OS_COUNT=0"
for %%D in (C D E F G H I J) do (
    if exist "%%D:\Windows\System32\winload.efi" (
        set /a OS_COUNT+=1
        if !OS_COUNT! LEQ 8 ( set "OS!OS_COUNT!=%%D" & call :PRINT_OS %%D !OS_COUNT! )
    )
)
if "!OS_COUNT!"=="0" ( echo [!] ERROR: No Windows installs detected. & pause & exit /b 1 )

set "SHOW_COUNT=!OS_COUNT!"
if !SHOW_COUNT! GTR 8 set "SHOW_COUNT=8"
set "OS_CH=12345678"
set "OS_CH=!OS_CH:~0,!SHOW_COUNT!!"

echo.
if defined NO_CHOICE (
  call :ASK_NUM SEL "Select OS (1-!SHOW_COUNT!): " 1 !SHOW_COUNT! || (echo [!] Invalid selection.& pause & exit /b 1)
) else (
  choice /c !OS_CH! /n /m "Select OS (1-!SHOW_COUNT!): "
  set "SEL=%errorlevel%"
)

for %%N in (!SEL!) do ( set "TARGET_OS=!OS%%N!!" & set "T_ED=!ED%%N!" & set "T_BD=!BD%%N!" )
if not exist "!TARGET_OS!:\Windows\System32\winload.efi" ( echo [!] ERROR: Invalid selection. & pause & exit /b 1 )

echo.
echo [SAFETY] Target: !TARGET_OS!: (!T_ED! !T_BD!)
if defined NO_CHOICE (
  call :ASK_YN GO "Proceed with recovery?"
  if errorlevel 2 ( echo [ABORTED] & pause & exit /b 0 )
) else (
  choice /c YN /m "Proceed with recovery? "
  if errorlevel 2 ( echo [ABORTED] & pause & exit /b 0 )
)

:: =============================================================================
:: 4. STABLE METADATA BACKUP MATCHING
:: =============================================================================
set "BKP=" & set "B_FOLDER="
for /f "delims=" %%F in ('dir /ad /b /o-d "!B_ROOT!" 2^>nul') do (
    set "M_FILE=!B_ROOT!\%%F\OS_ID.txt"
    if exist "!M_FILE!" (
        set "HAS_ED=0" & set "HAS_BD=0"
        for /f "usebackq delims=" %%L in ("!M_FILE!") do (
            echo %%L | "!FSTR!" /i "EditionID" >nul && echo %%L | "!FSTR!" /i "!T_ED!" >nul && set "HAS_ED=1"
            echo %%L | "!FSTR!" /i "CurrentBuildNumber" >nul && echo %%L | "!FSTR!" /i "!T_BD!" >nul && set "HAS_BD=1"
        )
        if "!HAS_ED!!HAS_BD!"=="11" ( set "BKP=!B_ROOT!\%%F" & set "B_FOLDER=%%F" & goto :BKP_FOUND )
    )
)
set "T_LET=!TARGET_OS!" & set "T_LET=!T_LET::=!"
for /f "delims=" %%F in ('dir /ad /b /o-d "!B_ROOT!" 2^>nul') do (
    echo %%F | "!FSTR!" /i "_!T_LET!" >nul && ( set "BKP=!B_ROOT!\%%F" & set "B_FOLDER=%%F" & goto :BKP_FOUND )
)
echo [!] ERROR: No matching backup found. & pause & exit /b 1
:BKP_FOUND

:: INSTALL MEDIA DETECTION
set "W_SRC=" & set "W_IDX=1"
for %%D in (C D E F G H I J K) do (
    if exist "%%D:\sources\install.wim" set "W_SRC=%%D:\sources\install.wim" & goto :W_READY
    if exist "%%D:\sources\install.esd" set "W_SRC=%%D:\sources\install.esd" & goto :W_READY
)
:W_READY
if defined W_SRC call :AUTO_WIM_INDEX

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
echo [5] SYNC FROM GITHUB
echo [6] EXIT
echo.
if defined NO_CHOICE ( call :ASK_NUM MENU_CH "Select (1-6): " 1 6 || goto :MENU_TOP ) else (
  choice /c 123456 /n /m "Select (1-6): "
  set "MENU_CH=%errorlevel%"
)

if "!MENU_CH!"=="1" set "MS=FASTBOOT" & goto :EXECUTE
if "!MENU_CH!"=="2" goto :DRIVER_RESTORE
if "!MENU_CH!"=="3" goto :REPAIR_REAL
if "!MENU_CH!"=="4" goto :NUCLEAR_LAST_RESORT
if "!MENU_CH!"=="5" goto :SYNC_GITHUB
if "!MENU_CH!"=="6" exit /b
goto :MENU_TOP

:: =============================================================================
:: 6. REPAIR & EXECUTION (ATOMIC)
:: =============================================================================
:EXECUTE
echo.
call :AUTO_MOUNT_EFI
if errorlevel 1 ( echo [!] ERROR: EFI not found. & pause & goto :MENU_TOP )

!RBCP! "!BKP!\EFI" "S:\EFI" /E /B /R:1 /W:1 /NP >> "!L_DIR!\robocopy_efi.log" 2>&1
set "RC=!errorlevel!"
if !RC! GEQ 8 ( echo [!] Robocopy failed (!RC!). & pause & goto :MENU_TOP )

!BCDB! !TARGET_OS!:\Windows /s S: /f UEFI >> "!L_DIR!\bcdboot.log" 2>&1
if errorlevel 1 ( echo [!] Bcdboot failed. & pause & goto :MENU_TOP )

!BCDE! /store "S:\EFI\Microsoft\Boot\BCD" /set {default} device partition=!TARGET_OS!: >> "!L_DIR!\bcdedit.log" 2>&1
!BCDE! /store "S:\EFI\Microsoft\Boot\BCD" /set {default} osdevice partition=!TARGET_OS!: >> "!L_DIR!\bcdedit.log" 2>&1
!BCDE! /store "S:\EFI\Microsoft\Boot\BCD" /displayorder {default} /addfirst >> "!L_DIR!\bcdedit.log" 2>&1

mountvol S: /d >nul 2>&1
echo [FINISHED] !MS! Restore Complete. Logs: !L_DIR!
pause & goto :MENU_TOP

:: =============================================================================
:: HELPERS (WinPE AGNOSTIC)
:: =============================================================================

:ASK_NUM
set "%~1=" & set /p "%~1=%~2"
for /f "delims=0123456789" %%Z in ("!%~1!") do set "%~1="
if not defined %~1 exit /b 1
if !%~1! LSS %3 exit /b 1
if !%~1! GTR %4 exit /b 1
exit /b 0

:ASK_YN
set "%~1=" & set /p "%~1=%~2 (Y/N): "
set "%~1=!%~1:~0,1!"
if /i "!%~1!"=="Y" exit /b 0
if /i "!%~1!"=="N" exit /b 2
exit /b 1

:AUTO_MOUNT_EFI
mountvol S: /d >nul 2>&1
for /f "tokens=2 delims=	 " %%V in ('echo list volume ^| "!DPART!" ^| "!FSTR!" /i "Volume" ^| "!FSTR!" /i "FAT32"') do (
    (echo select volume %%V ^& echo assign letter=S) | "!DPART!" >nul 2>&1
    if exist "S:\EFI\Microsoft\Boot" ( echo [EFI] Volume %%V mounted. >> "!L_DIR!\efi.log" & exit /b 0 )
    mountvol S: /d >nul 2>&1
)
for /f "tokens=2 delims=	 " %%V in ('echo list volume ^| "!DPART!" ^| "!FSTR!" /i "Volume" ^| "!FSTR!" /i "FAT32"') do (
    (echo select volume %%V ^& echo assign letter=S) | "!DPART!" >nul 2>&1
    if exist "S:\EFI\Boot" ( echo [EFI] Fallback Volume %%V mounted. >> "!L_DIR!\efi.log" & exit /b 0 )
    mountvol S: /d >nul 2>&1
)
exit /b 1

:AUTO_WIM_INDEX
set "OFF_ED="
reg load HKLM\OFFSOFT "!TARGET_OS!:\Windows\System32\config\SOFTWARE" >nul 2>&1
for /f "tokens=2,*" %%A in ('reg query "HKLM\OFFSOFT\Microsoft\Windows NT\CurrentVersion" /v EditionID 2^>nul ^| "!FSTR!" /i "EditionID"') do set "OFF_ED=%%B"
reg unload HKLM\OFFSOFT >nul 2>&1
set "OFF_ED=!OFF_ED: =!"
if not defined OFF_ED exit /b 0
:: NORMALIZATION
set "MATCH_ED=!OFF_ED!"
if /i "!MATCH_ED!"=="Professional" set "MATCH_ED=Pro"
if /i "!MATCH_ED!"=="Core" set "MATCH_ED=Home"
set "CUR_IDX="
for /f "usebackq delims=" %%L in (`"!DISM! /English /Get-WimInfo /WimFile:"!W_SRC!" 2^>nul"`) do (
    echo %%L | "!FSTR!" /i "Index :" >nul && (for /f "tokens=2 delims=:" %%X in ("%%L") do set "CUR_IDX=%%X" & set "CUR_IDX=!CUR_IDX: =!")
    echo %%L | "!FSTR!" /i "Name :" >nul && (set "NM=%%L" & echo !NM! | "!FSTR!" /i "!MATCH_ED!" >nul && (if defined CUR_IDX set "W_IDX=!CUR_IDX!"))
)
echo [AUTO_WIM_INDEX] Edition=!OFF_ED! MatchToken=!MATCH_ED! Index=!W_IDX! >> "!L_DIR!\repair.log"
exit /b 0

:PRINT_OS
set "D=%~1" & set "N=%~2" & set "PN=" & set "ED=" & set "BD="
reg load HKLM\OFFSOFT "%D%:\Windows\System32\config\SOFTWARE" >nul 2>&1
if not errorlevel 1 (
    for /f "tokens=2,*" %%A in ('reg query "HKLM\OFFSOFT\Microsoft\Windows NT\CurrentVersion" /v ProductName 2^>nul ^| "!FSTR!" /i "ProductName"') do set "PN=%%B"
    for /f "tokens=2,*" %%A in ('reg query "HKLM\OFFSOFT\Microsoft\Windows NT\CurrentVersion" /v EditionID 2^>nul ^| "!FSTR!" /i "EditionID"') do set "ED=%%B"
    for /f "tokens=2,*" %%A in ('reg query "HKLM\OFFSOFT\Microsoft\Windows NT\CurrentVersion" /v CurrentBuildNumber 2^>nul ^| "!FSTR!" /i "CurrentBuildNumber"') do set "BD=%%B"
    reg unload HKLM\OFFSOFT >nul 2>&1
)
set "ED!N!=!ED!" & set "BD!N!=!BD!"
echo [!N!] %D%: - !PN! (!ED! !BD!)
exit /b

:DRIVER_RESTORE
if exist "!BKP!\Drivers" ( !DISM! /Image:!TARGET_OS!:\ /Add-Driver /Driver:"!BKP!\Drivers" /Recurse >> "!L_DIR!\drivers.log" 2>&1 )
pause & goto :MENU_TOP

:REPAIR_REAL
set "SD=!TARGET_OS!:\_SCRATCH" & if not exist "!SD!" mkdir "!SD!"
if defined W_SRC (
    set "STAG=WIM" & echo !W_SRC! | "!FSTR!" /i "\.esd" >nul && set "STAG=ESD"
    !DISM! /Image:!TARGET_OS!:\ /ScratchDir:!SD! /Cleanup-Image /RestoreHealth /Source:!STAG!:!W_SRC!:!W_IDX! /LimitAccess >> "!L_DIR!\repair.log" 2>&1
)
!SFC! /scannow /offbootdir=!TARGET_OS!:\ /offwindir=!TARGET_OS!:\Windows >> "!L_DIR!\repair.log" 2>&1
pause & goto :MENU_TOP

:NUCLEAR_LAST_RESORT
set /p "C_STR=Type BRICKME to continue: "
if /i "!C_STR!"=="BRICKME" (
    if not exist "!BKP!\Hives\SYSTEM" ( echo [!] ERROR: Hive backup missing. & pause & goto :MENU_TOP )
    set "OLD_HIVE=SYSTEM.old_!random!"
    ren "!TARGET_OS!:\Windows\System32\config\SYSTEM" "!OLD_HIVE!" >nul 2>&1
    copy /y "!BKP!\Hives\SYSTEM" "!TARGET_OS!:\Windows\System32\config\SYSTEM" >> "!L_DIR!\nuclear.log" 2>&1
    !RBCP! "!BKP!\WIN_CORE\SYSTEM32" "!TARGET_OS!:\Windows\System32" /E /B /R:1 /W:1 /NP >> "!L_DIR!\nuclear.log" 2>&1
    set "RC=!errorlevel!"
    if !RC! GEQ 8 (
        echo [!] Robocopy failed. Rolling back hive...
        del /f /q "!TARGET_OS!:\Windows\System32\config\SYSTEM" >nul 2>&1
        ren "!TARGET_OS!:\Windows\System32\config\!OLD_HIVE!" "SYSTEM" >nul 2>&1
        pause & goto :MENU_TOP
    )
    set "MS=NUCLEAR" & goto :EXECUTE
)
goto :MENU_TOP

:SYNC_GITHUB
C:\Windows\System32\curl.exe -s -H "Cache-Control: no-cache" -L "https://raw.githubusercontent.com/eltonaguiar/Windows11BootBackupv2/main/ENHANCED_RESTORE2.cmd?v=!RANDOM!" -o %temp%\r.cmd
echo [OK] Pulled. Restart script.
pause & goto :MENU_TOP