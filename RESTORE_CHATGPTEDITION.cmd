@echo off
setlocal EnableExtensions EnableDelayedExpansion
:: =============================================================================
:: MIRACLE BOOT RESTORE v30.2 - CHATGPT EDITION
:: [NO-FINDSTR WINPE COMPAT + NO-CHOICE FALLBACK + STABLE WMIC PARSE]
:: =============================================================================
title Miracle Boot Restore v30.2 - Forensic Master [STABLE] - CHATGPT EDITION

set "CV=30.2"
echo ===========================================================================
echo    MIRACLE BOOT RESTORE v30.2 - [TOOL FALLBACK ENGINE ONLINE] - CHATGPT EDITION
echo ===========================================================================

:: 0. WINPE DETECTION GUARD
reg query "HKLM\Software\Microsoft\Windows NT\CurrentVersion\WinPE" >nul 2>&1
if errorlevel 1 (
  echo [!] ERROR: Script restricted to WinPE/WinRE.
  pause
  exit /b 1
)

:: 1. TOOL DISCOVERY (WinPE varies)
set "X_SYS=X:\Windows\System32"
set "DPART=%X_SYS%\diskpart.exe"
set "BCDB=%X_SYS%\bcdboot.exe"
set "BCDE=%X_SYS%\bcdedit.exe"
set "RBCP=%X_SYS%\robocopy.exe"
set "DISM=%X_SYS%\dism.exe"
set "SFC=%X_SYS%\sfc.exe"
set "CURL=%X_SYS%\curl.exe"
set "WMIC=%X_SYS%\wbem\wmic.exe"

:: 1.1 GREP FALLBACK: findstr -> find
set "GREP="
if exist "%X_SYS%\findstr.exe" (
  set "GREP=%X_SYS%\findstr.exe"
  set "GREP_IS_FINDSTR=1"
) else if exist "%X_SYS%\find.exe" (
  set "GREP=%X_SYS%\find.exe"
  set "GREP_IS_FINDSTR=0"
) else (
  echo [FATAL] Missing both findstr.exe and find.exe in this WinPE.
  echo Use a fuller WinRE/WinPE media.
  pause
  exit /b 1
)

:: 1.2 choice.exe fallback
set "NO_CHOICE="
if not exist "%X_SYS%\choice.exe" (
  echo [WARN] choice.exe missing. Falling back to manual input.
  set "NO_CHOICE=1"
)

:: 2. AUTO-NETWORK INITIALIZATION (best effort)
%X_SYS%\wpeutil.exe InitializeNetwork >nul 2>&1

:: =============================================================================
:: 3. LOCATE BACKUP ROOT
:: =============================================================================
set "B_ROOT="
for %%D in (C D E F G H I J) do (
  if not defined B_ROOT if exist "%%D:\MIRACLE_BOOT_FIXER" set "B_ROOT=%%D:\MIRACLE_BOOT_FIXER"
)
if not defined B_ROOT (
  echo [!] ERROR: \MIRACLE_BOOT_FIXER not found.
  pause
  exit /b 1
)

:: =============================================================================
:: 3.1 FORENSIC LOG VAULT (WMIC without regex)
:: =============================================================================
set "TS="
if exist "%WMIC%" (
  for /f "skip=1 tokens=1" %%i in ('"%WMIC%" os get localdatetime 2^>nul') do (
    if not defined TS (
      set "line=%%i"
      if not "!line!"=="" set "TS=%%i"
    )
  )
)
if not defined TS set "TS=%RANDOM%%RANDOM%%RANDOM%"

set "L_DIR=%B_ROOT%\_MiracleLogs\%TS:~0,8%_%TS:~8,6%"
mkdir "%L_DIR%" >nul 2>&1

echo [LOG] %L_DIR%> "%L_DIR%\_session.txt"
echo [VER] v%CV% - CHATGPT EDITION>> "%L_DIR%\_session.txt"

:: =============================================================================
:: 4. OS DISCOVERY (C..J, clamp to 8)
:: =============================================================================
echo.
echo =======================================================================
echo [SCAN] Detected Windows Installations (C..J) - CHATGPT EDITION
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
if "%OS_COUNT%"=="0" (
  echo [!] ERROR: No Windows installs detected.
  pause
  exit /b 1
)

set "SHOW_COUNT=%OS_COUNT%"
if %SHOW_COUNT% GTR 8 set "SHOW_COUNT=8"

:: Select OS
set "SEL="
if defined NO_CHOICE (
  call :ASK_NUM SEL "Select target OS (1-%SHOW_COUNT%): " 1 %SHOW_COUNT% || (echo [!] Invalid selection.& pause & exit /b 1)
) else (
  set "OS_CH=12345678"
  set "OS_CH=!OS_CH:~0,%SHOW_COUNT%!"
  choice /c !OS_CH! /n /m "Select target OS (1-%SHOW_COUNT%): "
  set "SEL=%errorlevel%"
)

for %%N in (%SEL%) do (
  set "TARGET_OS=!OS%%N!!"
  set "T_ED=!ED%%N!"
  set "T_BD=!BD%%N!"
)

if not defined TARGET_OS (
  echo [!] ERROR: Invalid selection.
  pause
  exit /b 1
)

if not exist "!TARGET_OS!:\Windows\System32\winload.efi" (
  echo [!] ERROR: Target OS invalid (missing winload.efi).
  pause
  exit /b 1
)

echo.
echo [SAFETY] Selected Target: !TARGET_OS!: (!T_ED! !T_BD!) - CHATGPT EDITION
echo [TARGET] !TARGET_OS!:>> "%L_DIR%\_session.txt"
echo [ED] !T_ED!>> "%L_DIR%\_session.txt"
echo [BD] !T_BD!>> "%L_DIR%\_session.txt"

:: Confirm
if defined NO_CHOICE (
  call :ASK_YN GO "Proceed with recovery?" || (echo [!] Invalid input.& pause & exit /b 1)
  if /i "!GO!"=="N" (echo [ABORTED] & exit /b 0)
) else (
  choice /c YN /m "Proceed with recovery? "
  if errorlevel 2 ( echo [ABORTED] & exit /b 0 )
)

:: =============================================================================
:: 5. BACKUP MATCHING (metadata then letter fallback)
:: =============================================================================
set "BKP="
set "B_FOLDER="

for /f "delims=" %%F in ('dir /ad /b /o-d "%B_ROOT%" 2^>nul') do (
  set "M_FILE=%B_ROOT%\%%F\OS_ID.txt"
  if exist "!M_FILE!" (
    set "HAS_ED=0"
    set "HAS_BD=0"
    for /f "usebackq delims=" %%L in ("!M_FILE!") do (
      call :LINE_HAS "%%L" "EditionID" && call :LINE_HAS "%%L" "!T_ED!" && set "HAS_ED=1"
      call :LINE_HAS "%%L" "CurrentBuildNumber" && call :LINE_HAS "%%L" "!T_BD!" && set "HAS_BD=1"
    )
    if "!HAS_ED!!HAS_BD!"=="11" (
      set "BKP=%B_ROOT%\%%F"
      set "B_FOLDER=%%F"
      goto :BKP_FOUND
    )
  )
)

set "T_LET=!TARGET_OS!"
set "T_LET=!T_LET::=!"
for /f "delims=" %%F in ('dir /ad /b /o-d "%B_ROOT%" 2^>nul') do (
  call :LINE_HAS "%%F" "_!T_LET!" && (
    set "BKP=%B_ROOT%\%%F"
    set "B_FOLDER=%%F"
    goto :BKP_FOUND
  )
)

echo [!] ERROR: No matching backup found.
pause
exit /b 1

:BKP_FOUND
echo [BKP] %BKP%>> "%L_DIR%\_session.txt"

:: =============================================================================
:: 6. INSTALL MEDIA DETECTION + WIM INDEX MATCH
:: =============================================================================
set "W_SRC="
set "W_IDX=1"
for %%D in (C D E F G H I J K) do (
  if exist "%%D:\sources\install.wim" (set "W_SRC=%%D:\sources\install.wim" & goto :W_READY)
  if exist "%%D:\sources\install.esd" (set "W_SRC=%%D:\sources\install.esd" & goto :W_READY)
)
:W_READY
if defined W_SRC call :AUTO_WIM_INDEX

:: =============================================================================
:: 7. MENU
:: =============================================================================
:MENU_TOP
echo.
echo ===========================================================================
echo    v%CV% - %B_FOLDER% --^> !TARGET_OS!:  - CHATGPT EDITION
echo ===========================================================================
echo [1] FASTBOOT RESTORE (EFI + BCD REBUILD)
echo [2] DRIVER INJECTION (DISM ADD-DRIVER)
echo [3] REAL REPAIR MODE (DISM + SFC)
echo [4] LAST RESORT (NUCLEAR SWAP)
echo [5] EXIT
echo.
echo [LOG] %L_DIR%
set "MENU_CH="

if defined NO_CHOICE (
  call :ASK_NUM MENU_CH "Select (1-5): " 1 5 || goto :MENU_TOP
) else (
  choice /c 12345 /n /m "Select (1-5): "
  set "MENU_CH=%errorlevel%"
)

if "%MENU_CH%"=="1" set "MS=FASTBOOT" & goto :EXECUTE
if "%MENU_CH%"=="2" goto :DRIVER_RESTORE
if "%MENU_CH%"=="3" goto :REPAIR_REAL
if "%MENU_CH%"=="4" goto :NUCLEAR_LAST_RESORT
if "%MENU_CH%"=="5" exit /b
goto :MENU_TOP

:: =============================================================================
:: EXECUTE (FASTBOOT / NUCLEAR runs through here)
:: =============================================================================
:EXECUTE
echo.
echo [*] AUTO-MOUNTING EFI (TWO-PASS) - CHATGPT EDITION
call :AUTO_MOUNT_EFI
if errorlevel 1 (
  echo [!] ERROR: EFI not found.
  pause
  goto :MENU_TOP
)

echo [*] Restoring EFI files...
"%RBCP%" "%BKP%\EFI" "S:\EFI" /E /B /R:1 /W:1 /NP >> "%L_DIR%\robocopy_efi.log" 2>&1
set "RC=%errorlevel%"
if %RC% GEQ 8 (
  echo [!] Robocopy failed (%RC%). Check logs.
  pause
  goto :MENU_TOP
)

echo [*] Running BCDBOOT...
"%BCDB%" !TARGET_OS!:\Windows /s S: /f UEFI >> "%L_DIR%\bcdboot.log" 2>&1
if errorlevel 1 (
  echo [!] Bcdboot failed. Check logs.
  pause
  goto :MENU_TOP
)

echo [*] Optional BCDEDIT tweaks...
"%BCDE%" /store "S:\EFI\Microsoft\Boot\BCD" /set {default} device partition=!TARGET_OS!: >> "%L_DIR%\bcdedit.log" 2>&1
if errorlevel 1 echo [WARN] BCDEDIT set device failed.>>"%L_DIR%\bcdedit.log"
"%BCDE%" /store "S:\EFI\Microsoft\Boot\BCD" /set {default} osdevice partition=!TARGET_OS!: >> "%L_DIR%\bcdedit.log" 2>&1
if errorlevel 1 echo [WARN] BCDEDIT set osdevice failed.>>"%L_DIR%\bcdedit.log"
"%BCDE%" /store "S:\EFI\Microsoft\Boot\BCD" /displayorder {default} /addfirst >> "%L_DIR%\bcdedit.log" 2>&1
if errorlevel 1 echo [WARN] BCDEDIT displayorder failed.>>"%L_DIR%\bcdedit.log"

mountvol S: /d >nul 2>&1
echo [FINISHED] %MS% Restore Complete. Logs: %L_DIR% - CHATGPT EDITION
pause
goto :MENU_TOP

:: =============================================================================
:: REPAIR MODE
:: =============================================================================
:REPAIR_REAL
set "SD=!TARGET_OS!:\_SCRATCH"
if not exist "!SD!" mkdir "!SD!" >nul 2>&1

if defined W_SRC (
  set "STAG=WIM"
  echo !W_SRC! | "%GREP%" /I ".esd" >nul 2>&1 && set "STAG=ESD"
  echo [*] DISM RestoreHealth Source=!W_SRC! Index=!W_IDX! - CHATGPT EDITION
  "%DISM%" /Image:!TARGET_OS!:\ /ScratchDir:!SD! /Cleanup-Image /RestoreHealth /Source:!STAG!:!W_SRC!:!W_IDX! /LimitAccess >> "%L_DIR%\dism_repair.log" 2>&1
) else (
  echo [WARN] No source found. DISM skipped.>> "%L_DIR%\dism_repair.log"
)

"%SFC%" /scannow /offbootdir=!TARGET_OS!:\ /offwindir=!TARGET_OS!:\Windows >> "%L_DIR%\sfc_repair.log" 2>&1
pause
goto :MENU_TOP

:: =============================================================================
:: DRIVER INJECTION
:: =============================================================================
:DRIVER_RESTORE
if exist "%BKP%\Drivers" (
  "%DISM%" /Image:!TARGET_OS!:\ /Add-Driver /Driver:"%BKP%\Drivers" /Recurse >> "%L_DIR%\driver_injection.log" 2>&1
) else (
  echo [!] No Drivers folder in backup.>> "%L_DIR%\driver_injection.log"
)
pause
goto :MENU_TOP

:: =============================================================================
:: NUCLEAR
:: =============================================================================
:NUCLEAR_LAST_RESORT
set "C_STR="
set /p "C_STR=Type BRICKME to continue: "
if /i not "!C_STR!"=="BRICKME" goto :MENU_TOP

if not exist "%BKP%\Hives\SYSTEM" (
  echo [!] ERROR: SYSTEM hive backup missing.
  pause
  goto :MENU_TOP
)

set "OLD_HIVE=SYSTEM.old_%RANDOM%"
ren "!TARGET_OS!:\Windows\System32\config\SYSTEM" "!OLD_HIVE!" >nul 2>&1
copy /y "%BKP%\Hives\SYSTEM" "!TARGET_OS!:\Windows\System32\config\SYSTEM" >> "%L_DIR%\hive_injection.log" 2>&1
if errorlevel 1 (
  echo [!] Hive copy failed.
  pause
  goto :MENU_TOP
)

"%RBCP%" "%BKP%\WIN_CORE\SYSTEM32" "!TARGET_OS!:\Windows\System32" /E /B /R:1 /W:1 /NP >> "%L_DIR%\robocopy_wincore.log" 2>&1
set "RC=%errorlevel%"
if %RC% GEQ 8 (
  echo [!] Robocopy failed. Rolling back...
  del /f /q "!TARGET_OS!:\Windows\System32\config\SYSTEM" >nul 2>&1
  ren "!TARGET_OS!:\Windows\System32\config\!OLD_HIVE!" "SYSTEM" >nul 2>&1
  pause
  goto :MENU_TOP
)

set "MS=NUCLEAR"
goto :EXECUTE

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

:: contains check (case-insensitive) using findstr or find
:LINE_HAS
set "LH_LINE=%~1"
set "LH_NEED=%~2"
if defined GREP_IS_FINDSTR (
  echo %LH_LINE% | "%GREP%" /I "%LH_NEED%" >nul 2>&1 && exit /b 0
) else (
  echo %LH_LINE% | "%GREP%" /I "%LH_NEED%" >nul 2>&1 && exit /b 0
)
exit /b 1

:: TWO-PASS EFI MOUNT
:AUTO_MOUNT_EFI
mountvol S: /d >nul 2>&1

:: PASS 1: Microsoft ESP
for /f "tokens=2" %%V in ('echo list volume ^| "%DPART%" ^| "%GREP%" /I "Volume" ^| "%GREP%" /I "FAT32"') do (
  (echo select volume %%V ^& echo assign letter=S) | "%DPART%" >nul 2>&1
  if exist "S:\EFI\Microsoft\Boot" (
    echo [EFI] PASS1 Volume %%V mounted>> "%L_DIR%\efi_mount.log"
    exit /b 0
  )
  mountvol S: /d >nul 2>&1
)

:: PASS 2: Generic EFI\Boot
for /f "tokens=2" %%V in ('echo list volume ^| "%DPART%" ^| "%GREP%" /I "Volume" ^| "%GREP%" /I "FAT32"') do (
  (echo select volume %%V ^& echo assign letter=S) | "%DPART%" >nul 2>&1
  if exist "S:\EFI\Boot" (
    echo [EFI] PASS2 Volume %%V mounted>> "%L_DIR%\efi_mount.log"
    exit /b 0
  )
  mountvol S: /d >nul 2>&1
)

exit /b 1

:: Sequential WIM index matching (Index then Name)
:AUTO_WIM_INDEX
set "OFF_ED="
reg load HKLM\OFFSOFT "!TARGET_OS!:\Windows\System32\config\SOFTWARE" >nul 2>&1
for /f "tokens=2,*" %%A in ('reg query "HKLM\OFFSOFT\Microsoft\Windows NT\CurrentVersion" /v EditionID 2^>nul') do (
  if /i "%%A"=="REG_SZ" set "OFF_ED=%%B"
)
reg unload HKLM\OFFSOFT >nul 2>&1

set "OFF_ED=!OFF_ED: =!"
if not defined OFF_ED exit /b 0

set "CUR_IDX="
for /f "usebackq delims=" %%L in (`"%DISM% /English /Get-WimInfo /WimFile:"!W_SRC!" 2^>nul"`) do (
  echo %%L | "%GREP%" /I "Index :" >nul 2>&1 && (
    for /f "tokens=2 delims=:" %%X in ("%%L") do set "CUR_IDX=%%X"
    set "CUR_IDX=!CUR_IDX: =!"
  )
  echo %%L | "%GREP%" /I "Name :" >nul 2>&1 && (
    set "NM=%%L"
    echo !NM! | "%GREP%" /I "!OFF_ED!" >nul 2>&1 && (
      if defined CUR_IDX set "W_IDX=!CUR_IDX!"
    )
  )
)

echo [AUTO_WIM_INDEX] EditionID=!OFF_ED! MatchedIndex=!W_IDX!>> "%L_DIR%\dism_repair.log"
exit /b 0

:PRINT_OS
set "D=%~1"
set "N=%~2"
set "PN="
set "ED="
set "BD="

reg load HKLM\OFFSOFT "%D%:\Windows\System32\config\SOFTWARE" >nul 2>&1
if not errorlevel 1 (
  for /f "tokens=2,*" %%A in ('reg query "HKLM\OFFSOFT\Microsoft\Windows NT\CurrentVersion" /v ProductName 2^>nul') do (
    if /i "%%A"=="REG_SZ" set "PN=%%B"
  )
  for /f "tokens=2,*" %%A in ('reg query "HKLM\OFFSOFT\Microsoft\Windows NT\CurrentVersion" /v EditionID 2^>nul') do (
    if /i "%%A"=="REG_SZ" set "ED=%%B"
  )
  for /f "tokens=2,*" %%A in ('reg query "HKLM\OFFSOFT\Microsoft\Windows NT\CurrentVersion" /v CurrentBuildNumber 2^>nul') do (
    if /i "%%A"=="REG_SZ" set "BD=%%B"
  )
  reg unload HKLM\OFFSOFT >nul 2>&1
)

set "ED!N!=!ED!"
set "BD!N!=!BD!"
echo [!N!] %D%: - !PN! (!ED! !BD!)
exit /b
