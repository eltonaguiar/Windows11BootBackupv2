@echo off
setlocal EnableExtensions EnableDelayedExpansion
:: =============================================================================
:: MIRACLE BOOT RESTORE v30.2 - [MINIMAL WINPE COMPAT ENGINE] - CHATGPT EDITION
:: =============================================================================
title Miracle Boot Restore v30.2 - Forensic Master [STABLE] - CHATGPT EDITION

set "CV=30.2"
echo ===========================================================================
echo    MIRACLE BOOT RESTORE v30.2 - [TOOL FALLBACK ENGINE ONLINE] - CHATGPT EDITION
echo ===========================================================================

:: 0) WINPE DETECTION GUARD
reg query "HKLM\Software\Microsoft\Windows NT\CurrentVersion\WinPE" >nul 2>&1
if errorlevel 1 ( echo [!] ERROR: Script restricted to WinPE/WinRE. & pause & exit /b 1 )

:: 1) PATHS (DON'T ASSUME SYSTEM32 TOOLS EXIST)
set "X_SYS=X:\Windows\System32"
set "DPART=%X_SYS%\diskpart.exe"
set "BCDB=%X_SYS%\bcdboot.exe"
set "BCDE=%X_SYS%\bcdedit.exe"
set "RBCP=%X_SYS%\robocopy.exe"
set "DISM=%X_SYS%\dism.exe"
set "SFC=%X_SYS%\sfc.exe"
set "WMIC=%X_SYS%\wbem\wmic.exe"
set "FIND=%X_SYS%\find.exe"
set "FSTR=%X_SYS%\findstr.exe"
set "CHOICE=%X_SYS%\choice.exe"

:: 1.1) BASIC TOOL SANITY
if not exist "%DPART%" ( echo [FATAL] Missing diskpart.exe & pause & exit /b 1 )
if not exist "%BCDB%"  ( echo [FATAL] Missing bcdboot.exe  & pause & exit /b 1 )
if not exist "%BCDE%"  ( echo [FATAL] Missing bcdedit.exe  & pause & exit /b 1 )
if not exist "%RBCP%"  ( echo [FATAL] Missing robocopy.exe & pause & exit /b 1 )
if not exist "%DISM%"  ( echo [WARN] dism.exe missing. Repair mode will be limited. )
if not exist "%SFC%"   ( echo [WARN] sfc.exe missing. Repair mode will be limited. )
if not exist "%FIND%"  ( echo [FATAL] find.exe missing. This WinPE is broken. & pause & exit /b 1 )

set "HAS_FINDSTR=0"
if exist "%FSTR%" set "HAS_FINDSTR=1"

set "HAS_CHOICE=0"
if exist "%CHOICE%" set "HAS_CHOICE=1"

:: 2) NETWORK INIT (SAFE)
%X_SYS%\wpeutil.exe InitializeNetwork >nul 2>&1

:: =============================================================================
:: 3) LOCATE BACKUP ROOT
:: =============================================================================
set "B_ROOT="
for %%D in (C D E F G H I J K L M N O P Q R S T U V W Y Z) do (
    if not defined B_ROOT if exist "%%D:\MIRACLE_BOOT_FIXER" set "B_ROOT=%%D:\MIRACLE_BOOT_FIXER"
)
if not defined B_ROOT ( echo [!] ERROR: \MIRACLE_BOOT_FIXER not found on any drive. & pause & exit /b 1 )

:: 3.1) LOG VAULT TIMESTAMP (WMIC IF AVAILABLE, ELSE RANDOM)
set "TS="
if exist "%WMIC%" (
  for /f "skip=1 tokens=1" %%i in ('"%WMIC%" os get localdatetime 2^>nul') do (
    if not defined TS set "TS=%%i"
  )
)
if not defined TS set "TS=%RANDOM%%RANDOM%%RANDOM%"
set "L_DIR=%B_ROOT%\_MiracleLogs\%TS:~0,8%_%TS:~8,6%"
if "%L_DIR%"=="%B_ROOT%\_MiracleLogs\_" set "L_DIR=%B_ROOT%\_MiracleLogs\%RANDOM%%RANDOM%"
mkdir "%L_DIR%" >nul 2>&1

echo.
echo [LOG] Vault: "%L_DIR%"

:: =============================================================================
:: 4) OS DISCOVERY (C..Z)
:: =============================================================================
echo.
echo =======================================================================
echo [SCAN] Detected Windows Installations
echo =======================================================================
set "OS_COUNT=0"

for %%D in (C D E F G H I J K L M N O P Q R S T U V W Y Z) do (
    if exist "%%D:\Windows\System32\winload.efi" (
        set /a OS_COUNT+=1
        if !OS_COUNT! LEQ 8 (
            set "OS!OS_COUNT!=%%D"
            call :PRINT_OS %%D !OS_COUNT!
        )
    )
)

if "%OS_COUNT%"=="0" ( echo [!] ERROR: No Windows installs detected. & pause & exit /b 1 )

set "SHOW_COUNT=%OS_COUNT%"
if %SHOW_COUNT% GTR 8 set "SHOW_COUNT=8"

echo.
call :ASK_NUM SEL "Select target OS (1-%SHOW_COUNT%): " 1 %SHOW_COUNT% || (echo [!] Invalid selection.& pause & exit /b 1)

for %%N in (%SEL%) do (
    set "TARGET_OS=!OS%%N!!"
    set "T_ED=!ED%%N!"
    set "T_BD=!BD%%N!"
)

if not exist "!TARGET_OS!:\Windows\System32\winload.efi" (
  echo [!] ERROR: Target OS invalid (missing winload.efi).
  pause & exit /b 1
)

echo.
echo [SAFETY] Selected Target: !TARGET_OS!: (!T_ED! !T_BD!)
call :ASK_YN GO "Proceed with recovery?" || (echo [!] Invalid input.& pause & exit /b 1)
if /i "!GO!"=="N" (echo [ABORTED] & pause & exit /b 0)

:: =============================================================================
:: 5) BACKUP MATCHING
:: =============================================================================
set "BKP=" & set "B_FOLDER="
for /f "delims=" %%F in ('dir /ad /b /o-d "%B_ROOT%" 2^>nul') do (
    set "M_FILE=%B_ROOT%\%%F\OS_ID.txt"
    if exist "!M_FILE!" (
        set "HAS_ED=0" & set "HAS_BD=0"
        for /f "usebackq delims=" %%L in ("!M_FILE!") do (
            echo %%L | "%FIND%" /i "EditionID" >nul && echo %%L | "%FIND%" /i "!T_ED!" >nul && set "HAS_ED=1"
            echo %%L | "%FIND%" /i "CurrentBuildNumber" >nul && echo %%L | "%FIND%" /i "!T_BD!" >nul && set "HAS_BD=1"
        )
        if "!HAS_ED!!HAS_BD!"=="11" ( set "BKP=%B_ROOT%\%%F" & set "B_FOLDER=%%F" & goto :BKP_FOUND )
    )
)

set "T_LET=!TARGET_OS!" & set "T_LET=!T_LET::=!"
for /f "delims=" %%F in ('dir /ad /b /o-d "%B_ROOT%" 2^>nul') do (
    echo %%F | "%FIND%" /i "_!T_LET!" >nul && ( set "BKP=%B_ROOT%\%%F" & set "B_FOLDER=%%F" & goto :BKP_FOUND )
)

echo [!] ERROR: No matching backup found.
pause & exit /b 1

:BKP_FOUND
echo.
echo [OK] Backup matched: "%BKP%"

:: =============================================================================
:: 6) MENU
:: =============================================================================
:MENU_TOP
echo.
echo ===========================================================================
echo    %CV% - %B_FOLDER% --^> !TARGET_OS!:
echo ===========================================================================
echo [1] FASTBOOT RESTORE (EFI + BCD REBUILD)
echo [2] DRIVER INJECTION (DISM ADD-DRIVER)
echo [3] REAL REPAIR MODE (DISM + SFC)
echo [4] LAST RESORT (NUCLEAR SWAP)
echo [5] EXIT
echo.
call :ASK_NUM MENU_CH "Select (1-5): " 1 5 || goto :MENU_TOP

if "%MENU_CH%"=="1" set "MS=FASTBOOT" & goto :EXECUTE
if "%MENU_CH%"=="2" goto :DRIVER_RESTORE
if "%MENU_CH%"=="3" goto :REPAIR_REAL
if "%MENU_CH%"=="4" goto :NUCLEAR_LAST_RESORT
if "%MENU_CH%"=="5" exit /b
goto :MENU_TOP

:: =============================================================================
:: 7) EXECUTE (EFI + BCD)
:: =============================================================================
:EXECUTE
echo.
echo [*] AUTO-MOUNTING EFI (TWO-PASS)...
call :AUTO_MOUNT_EFI
if errorlevel 1 ( echo [!] ERROR: EFI not found. & pause & goto :MENU_TOP )

echo [*] Restoring EFI folder...
"%RBCP%" "%BKP%\EFI" "S:\EFI" /E /B /R:1 /W:1 /NP >> "%L_DIR%\robocopy_efi.log" 2>&1
set "RC=%errorlevel%"
if %RC% GEQ 8 ( echo [!] Robocopy failed (%RC%). Check logs. & pause & goto :MENU_TOP )

echo [*] Running BCDBOOT...
"%BCDB%" !TARGET_OS!:\Windows /s S: /f UEFI >> "%L_DIR%\bcdboot.log" 2>&1
if errorlevel 1 ( echo [!] Bcdboot failed. Check logs. & pause & goto :MENU_TOP )

echo [*] BCDEDIT adjustments (non-fatal)...
"%BCDE%" /store "S:\EFI\Microsoft\Boot\BCD" /set {default} device partition=!TARGET_OS!: >> "%L_DIR%\bcdedit.log" 2>&1
if errorlevel 1 echo [WARN] BCDEDIT set device failed.>>"%L_DIR%\bcdedit.log"

"%BCDE%" /store "S:\EFI\Microsoft\Boot\BCD" /set {default} osdevice partition=!TARGET_OS!: >> "%L_DIR%\bcdedit.log" 2>&1
if errorlevel 1 echo [WARN] BCDEDIT set osdevice failed.>>"%L_DIR%\bcdedit.log"

"%BCDE%" /store "S:\EFI\Microsoft\Boot\BCD" /displayorder {default} /addfirst >> "%L_DIR%\bcdedit.log" 2>&1
if errorlevel 1 echo [WARN] BCDEDIT displayorder failed.>>"%L_DIR%\bcdedit.log"

mountvol S: /d >nul 2>&1
echo [FINISHED] %MS% Restore Complete. Logs: "%L_DIR%"
pause
goto :MENU_TOP

:: =============================================================================
:: HELPERS
:: =============================================================================

:ASK_NUM
set "%~1="
set /p "%~1=%~2"
for /f "delims=0123456789" %%Z in ("!%~1!") do set "%~1="
if not defined %~1 exit /b 1
if !%~1! LSS %3 exit /b 1
if !%~1! GTR %4 exit /b 1
exit /b 0

:ASK_YN
set "%~1="
set /p "%~1=%~2 (Y/N): "
set "%~1=!%~1:~0,1!"
if /i "!%~1!"=="Y" exit /b 0
if /i "!%~1!"=="N" exit /b 0
exit /b 1

:PRINT_OS
set "D=%~1"
set "N=%~2"
set "PN="
set "ED="
set "BD="

reg load HKLM\OFFSOFT "%D%:\Windows\System32\config\SOFTWARE" >nul 2>&1
if not errorlevel 1 (
    for /f "tokens=2,*" %%A in ('reg query "HKLM\OFFSOFT\Microsoft\Windows NT\CurrentVersion" /v ProductName 2^>nul') do set "PN=%%B"
    for /f "tokens=2,*" %%A in ('reg query "HKLM\OFFSOFT\Microsoft\Windows NT\CurrentVersion" /v EditionID 2^>nul') do set "ED=%%B"
    for /f "tokens=2,*" %%A in ('reg query "HKLM\OFFSOFT\Microsoft\Windows NT\CurrentVersion" /v CurrentBuildNumber 2^>nul') do set "BD=%%B"
    reg unload HKLM\OFFSOFT >nul 2>&1
)

set "ED%N%=%ED%"
set "BD%N%=%BD%"
echo [%N%] %D%: - !PN! (!ED! !BD!)
exit /b

:AUTO_MOUNT_EFI
mountvol S: /d >nul 2>&1

:: PASS 1: Prefer Microsoft ESP
for /f "tokens=1-6" %%a in ('echo list volume ^| "%DPART%" 2^>nul') do (
    if /i "%%a"=="Volume" if /i "%%e"=="FAT32" (
        (echo select volume %%b ^& echo assign letter=S) | "%DPART%" >nul 2>&1
        if exist "S:\EFI\Microsoft\Boot" ( echo [EFI] Mounted Volume %%b (Microsoft) >> "%L_DIR%\efi_mount.log" & exit /b 0 )
        mountvol S: /d >nul 2>&1
    )
)

:: PASS 2: Fallback EFI\Boot
for /f "tokens=1-6" %%a in ('echo list volume ^| "%DPART%" 2^>nul') do (
    if /i "%%a"=="Volume" if /i "%%e"=="FAT32" (
        (echo select volume %%b ^& echo assign letter=S) | "%DPART%" >nul 2>&1
        if exist "S:\EFI\Boot" ( echo [EFI] Mounted Volume %%b (Fallback) >> "%L_DIR%\efi_mount.log" & exit /b 0 )
        mountvol S: /d >nul 2>&1
    )
)

exit /b 1

:DRIVER_RESTORE
if not exist "%DISM%" ( echo [!] DISM missing. Can't inject drivers. & pause & goto :MENU_TOP )
if exist "%BKP%\Drivers" (
    "%DISM%" /Image:!TARGET_OS!:\ /Add-Driver /Driver:"%BKP%\Drivers" /Recurse >> "%L_DIR%\driver_injection.log" 2>&1
    echo [OK] Driver injection attempted. Check log.
) else (
    echo [!] No Drivers folder in backup.
)
pause
goto :MENU_TOP

:REPAIR_REAL
if not exist "%DISM%" echo [WARN] DISM missing. Skipping DISM.
if not exist "%SFC%"  echo [WARN] SFC missing. Skipping SFC.

set "SD=!TARGET_OS!:\_SCRATCH"
if not exist "!SD!" mkdir "!SD!" >nul 2>&1

if exist "%DISM%" (
    echo [*] DISM /RestoreHealth (no install.wim auto-source in minimal mode)...
    "%DISM%" /Image:!TARGET_OS!:\ /ScratchDir:!SD! /Cleanup-Image /RestoreHealth >> "%L_DIR%\dism_repair.log" 2>&1
)

if exist "%SFC%" (
    echo [*] SFC offline scan...
    "%SFC%" /scannow /offbootdir=!TARGET_OS!:\ /offwindir=!TARGET_OS!:\Windows >> "%L_DIR%\sfc_repair.log" 2>&1
)

pause
goto :MENU_TOP

:NUCLEAR_LAST_RESORT
set "C_STR="
set /p "C_STR=Type BRICKME to continue: "
if /i not "!C_STR!"=="BRICKME" goto :MENU_TOP

if not exist "%BKP%\Hives\SYSTEM" ( echo [!] ERROR: Hive backup missing. & pause & goto :MENU_TOP )

set "OLD_HIVE=SYSTEM.old_%RANDOM%"
ren "!TARGET_OS!:\Windows\System32\config\SYSTEM" "!OLD_HIVE!" >nul 2>&1
copy /y "%BKP%\Hives\SYSTEM" "!TARGET_OS!:\Windows\System32\config\SYSTEM" >> "%L_DIR%\hive_injection.log" 2>&1

"%RBCP%" "%BKP%\WIN_CORE\SYSTEM32" "!TARGET_OS!:\Windows\System32" /E /B /R:1 /W:1 /NP >> "%L_DIR%\robocopy_wincore.log" 2>&1
set "RC=%errorlevel%"
if %RC% GEQ 8 (
    echo [!] Robocopy failed. Rolling back SYSTEM hive...
    del /f /q "!TARGET_OS!:\Windows\System32\config\SYSTEM" >nul 2>&1
    ren "!TARGET_OS!:\Windows\System32\config\!OLD_HIVE!" "SYSTEM" >nul 2>&1
    pause & goto :MENU_TOP
)

set "MS=NUCLEAR"
goto :EXECUTE
