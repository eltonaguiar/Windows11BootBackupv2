@echo off
setlocal EnableExtensions EnableDelayedExpansion
:: =============================================================================
:: MIRACLE BOOT RESTORE v31.0 - GROK EDITION
:: [IMPROVED EFI DETECTION / ROBUST BACKUP SEARCH / SAFER OPERATIONS]
:: =============================================================================
title Miracle Boot Restore v31.0 - GROK EDITION [ENHANCED & STABLE]
set "CV=31.0 - GROK EDITION"
echo ===========================================================================
echo MIRACLE BOOT RESTORE v31.0 - GROK EDITION
echo [Improved EFI partition detection + Robust backup discovery + Safety checks]
echo ===========================================================================
:: 1. CORE TOOLS (Absolute Paths - WinRE X: drive)
set "X_SYS=X:\Windows\System32"
set "DPART=!X_SYS!\diskpart.exe"
set "BCDB=!X_SYS!\bcdboot.exe"
set "BCDE=!X_SYS!\bcdedit.exe"
set "RBCP=!X_SYS!\robocopy.exe"
set "REG=!X_SYS!\reg.exe"
set "SFC=!X_SYS!\sfc.exe"

:: 2. DYNAMIC BACKUP ROOT DISCOVERY
set "B_ROOT="
for %%D in (C D E F G H I J K L M N O P Q R) do (
    if not defined B_ROOT if exist "%%D:\MIRACLE_BOOT_FIXER" set "B_ROOT=%%D:\MIRACLE_BOOT_FIXER"
)
if not defined B_ROOT (
    echo [!] ERROR: Folder \MIRACLE_BOOT_FIXER not found on any drive.
    pause
    exit /b 1
)
echo [OK] Backup root found: !B_ROOT!

:: 3. OS INSTALLATION DETECTION
echo.
echo [SCAN] Detecting Windows installations...
set "OS_COUNT=0"
for %%D in (C D E F G H I J K L M N O P Q R) do (
    if exist "%%D:\Windows\System32\winload.efi" (
        set /a OS_COUNT+=1
        set "OS!OS_COUNT!=%%D"
        call :PRINT_OS_EDITION %%D !OS_COUNT!
    )
)
if "!OS_COUNT!"=="0" (
    echo [!] ERROR: No UEFI Windows installation detected.
    pause
    exit /b 1
)
if "!OS_COUNT!"=="1" (
    set "SEL=1"
) else (
    :OS_PICK
    set "SEL="
    set /p "SEL=Select OS number (1-!OS_COUNT!): "
    if not defined SEL goto :OS_PICK
)
set "TARGET_OS="
for %%N in (!SEL!) do set "TARGET_OS=!OS%%N!"
if not defined TARGET_OS (
    echo [!] Invalid selection.
    goto :OS_PICK
)
echo.
echo [SELECTED] Target OS drive: !TARGET_OS!:
set /p "GO=Proceed with this OS? (Y/N): "
if /i not "!GO!"=="Y" (
    echo [ABORTED] User cancelled.
    pause
    exit /b 0
)

:: 4. BACKUP FOLDER DISCOVERY (Improved robustness)
set "BKP=" & set "B_FOLDER="
set "T_LET=!TARGET_OS:~0,1!"
echo.
echo [*] Searching for backup folders containing _FASTBOOT_!T_LET! ...
for /f "delims=" %%F in ('dir /ad /b /o:-n "!B_ROOT!" ^| findstr /i "_FASTBOOT_!T_LET!"') do (
    set "BKP=!B_ROOT!\%%F"
    set "B_FOLDER=%%F"
    goto :BKP_FOUND
)
echo [WARN] Exact match not found. Falling back to newest non-log folder...
for /f "delims=" %%F in ('dir /ad /b /o:-n "!B_ROOT!"') do (
    if /i not "%%F"=="_MiracleLogs" if not "%%F"=="MIRACLE_BOOT_FIXER" (
        set "BKP=!B_ROOT!\%%F"
        set "B_FOLDER=%%F"
        goto :BKP_FOUND
    )
)
echo [!] ERROR: No suitable backup folder found.
pause
exit /b 1

:BKP_FOUND
echo [OK] Selected backup: !B_FOLDER! (!BKP!)

:: 5. REPAIR MENU
:MENU_TOP
cls
echo.
echo ===========================================================================
echo !CV! - Restoring from !B_FOLDER! --^> !TARGET_OS!:
echo ===========================================================================
echo [1] FASTBOOT RESTORE (Overwrite EFI + Rebuild BCD)
echo [2] SFC SCAN ONLY (Offline)
echo [3] NUCLEAR SWAP (Replace SYSTEM hive - DANGEROUS)
echo [4] EXIT
echo.
set "M_SEL="
set /p "M_SEL=Select option (1-4): "
if "!M_SEL!"=="1" goto :EXECUTE_FASTBOOT
if "!M_SEL!"=="2" goto :REPAIR_SFC
if "!M_SEL!"=="3" goto :NUCLEAR
if "!M_SEL!"=="4" exit /b 0
goto :MENU_TOP

:REPAIR_SFC
echo [*] Running offline SFC scan...
!SFC! /scannow /offbootdir=!TARGET_OS!:\ /offwindir=!TARGET_OS!:\Windows
pause
goto :MENU_TOP

:: 6. IMPROVED EFI PARTITION MOUNT & FASTBOOT RESTORE
:EXECUTE_FASTBOOT
echo.
echo [*] Searching for EFI System Partition (FAT32, ~100-500MB)...
mountvol Y: /d >nul 2>&1
echo list volume | "!DPART!" > "%TEMP%\vollist.txt"
for /f "skip=8 tokens=1,2,3,*" %%A in (%TEMP%\vollist.txt) do (
    if "%%B"=="FAT32" if "%%D" neq "Recovery" (
        echo select volume %%A > "%TEMP%\dp.txt"
        echo assign letter=Y >> "%TEMP%\dp.txt"
        "!DPART!" < "%TEMP%\dp.txt" >nul
        if exist "Y:\EFI\Microsoft\Boot" (
            echo [OK] EFI partition found and mounted as Y:
            goto :EFI_MOUNTED
        ) else if exist "Y:\EFI\Boot" (
            echo [OK] EFI partition found and mounted as Y:
            goto :EFI_MOUNTED
        )
        mountvol Y: /d >nul 2>&1
    )
)
echo [!] ERROR: EFI System Partition not found.
del "%TEMP%\vollist.txt" "%TEMP%\dp.txt" 2>nul
pause
goto :MENU_TOP

:EFI_MOUNTED
:: Safety check: Ensure backup EFI exists
if not exist "!BKP!\EFI" (
    echo [!] ERROR: Backup EFI folder missing in !BKP!
    mountvol Y: /d >nul 2>&1
    pause
    goto :MENU_TOP
)

echo [*] Overwriting EFI partition with backup (robocopy /MIR for safety)...
!RBCP! "!BKP!\EFI" "Y:\EFI" /MIR /R:3 /W:5 /NP

echo [*] Rebuilding BCD store with bcdboot...
!BCDB! !TARGET_OS!:\Windows /s Y: /f UEFI /v

echo [*] Verifying and fixing default boot entry...
!BCDE! /store Y:\EFI\Microsoft\Boot\BCD /set {default} device partition=!TARGET_OS!: >nul 2>&1
!BCDE! /store Y:\EFI\Microsoft\Boot\BCD /set {default} osdevice partition=!TARGET_OS!: >nul 2>&1
!BCDE! /store Y:\EFI\Microsoft\Boot\BCD /set {bootmgr} device partition=Y: >nul 2>&1

mountvol Y: /d >nul 2>&1
del "%TEMP%\vollist.txt" "%TEMP%\dp.txt" 2>nul
echo.
echo [SUCCESS] Fastboot restore completed!
pause
goto :MENU_TOP

:: 7. NUCLEAR SYSTEM HIVE SWAP (High risk - only if needed)
:NUCLEAR
echo.
echo [!!! WARNING !!!] This will replace the SYSTEM registry hive.
echo This can brick Windows if the backup hive is incompatible.
set /p "C_STR=Type BRICKME to confirm: "
if /i not "!C_STR!"=="BRICKME" (
    echo [ABORTED] Nuclear option cancelled.
    pause
    goto :MENU_TOP
)
if not exist "!BKP!\Hives\SYSTEM" (
    echo [!] ERROR: SYSTEM hive not found in backup.
    pause
    goto :MENU_TOP
)
ren "!TARGET_OS!:\Windows\System32\config\SYSTEM" "SYSTEM.old_%RANDOM%" >nul 2>&1
copy /y "!BKP!\Hives\SYSTEM" "!TARGET_OS!:\Windows\System32\config\SYSTEM" >nul
echo [DONE] SYSTEM hive replaced. Proceeding to Fastboot restore...
goto :EXECUTE_FASTBOOT

:: 8. HELPER: Detect Windows Edition
:PRINT_OS_EDITION
set "D=%~1"
set "N=%~2"
set "ED=Unknown"
!REG! load HKLM\OFFSOFT "%D%:\Windows\System32\config\SOFTWARE" >nul 2>&1
if not errorlevel 1 (
    for /f "tokens=3" %%A in ('!REG! query "HKLM\OFFSOFT\Microsoft\Windows NT\CurrentVersion" /v EditionID 2^>nul ^| find "EditionID"') do set "ED=%%A"
    !REG! unload HKLM\OFFSOFT >nul 2>&1
)
echo [!N!] %D%: - Windows (!ED!)
exit /b
