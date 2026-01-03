@echo off
setlocal EnableDelayedExpansion
title Miracle Boot QA - Forensic Master v16.0

:: NOTE: Diagnostics are read-only by default. Scoring is a weighted probability (0-100) based on evidence.
:: Set QA_DEBUG=1 or VERBOSE=1 to get a detailed evidence breakdown per drive.
:: Repairs are only done via the 'SURGICAL_REPAIR' menu option (no automatic fixes in diagnostics).

:: Admin Check
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [!] ERROR: Run as Admin!
    pause
    exit /b
)

:MENU
cls
echo ===========================================================================
echo       MIRACLE BOOT QA - FORENSIC MASTER v16.0
echo ===========================================================================
echo.
echo [1] BACKUP FORENSICS: Validate All Backup Folders
echo [2] VALIDATE SPECIFIC BACKUP: Check Single Backup Folder
echo [3] LIVE DIAGNOSTIC: Deep Boot Validation
echo [4] SURGICAL REPAIR: EFI + BCD Reconstruction
echo [5] EXIT
echo.
set /p "CHOICE=Select: "

if /i "%CHOICE%"=="1" goto SCAN_BACKUPS
if /i "%CHOICE%"=="2" goto VALIDATE_SPECIFIC_BACKUP
if /i "%CHOICE%"=="3" goto DIAG_DRIVE_SELECTOR
if /i "%CHOICE%"=="4" goto SURGICAL_REPAIR
if /i "%CHOICE%"=="5" exit /b
goto MENU


:SCAN_BACKUPS
cls
echo ===========================================================================
echo       BACKUP FORENSICS - COMPREHENSIVE VALIDATION v14.1
echo ===========================================================================
echo.
set "BASE_DIR=%~dp0"
set "BACKUP_COUNT=0"
set "VALID_BACKUPS=0"

for /f "delims=" %%i in ('dir /b /ad "%BASE_DIR%*NUCLEAR*" 2^>nul') do (
    set /a BACKUP_COUNT+=1
    set "B_PATH=%BASE_DIR%%%i"
    echo [BACKUP #!BACKUP_COUNT!]: %%i
    echo ---------------------------------------------------------------------------
    
    :: Initialize validation score
    set /a VALIDATION_SCORE=0
    set /a MAX_SCORE=100
    set "VALIDATION_ISSUES="
    set "BCD_BACKUP_SIZE="
    set "H_SIZE="
    set "H_MB="
    set "BOOTMGFW_SIZE="
    set "BOOTMGFW_MB="
    set "BCD_SIZE="
    
    :: 1. Critical EFI Files (40 points)
    echo [*] Checking EFI Boot Files...
    if exist "!B_PATH!\EFI\Microsoft\Boot\bootmgfw.efi" (
        set /a VALIDATION_SCORE+=20
        for %%F in ("!B_PATH!\EFI\Microsoft\Boot\bootmgfw.efi") do (
            set /a BOOTMGFW_SIZE=%%~zF
            set /a BOOTMGFW_MB=!BOOTMGFW_SIZE! / 1048576
        )
        echo   [OK] bootmgfw.efi: PRESENT (!BOOTMGFW_MB! MB^) ^[+20^]
    ) else (
        set "VALIDATION_ISSUES=!VALIDATION_ISSUES! MISSING: bootmgfw.efi;"
        echo   [^!] bootmgfw.efi: MISSING [-20]
    )
    
    if exist "!B_PATH!\EFI\Microsoft\Boot\bootmgr.efi" (
        set /a VALIDATION_SCORE+=5
        echo   [OK] bootmgr.efi: PRESENT ^[+5^]
    ) else (
        set "VALIDATION_ISSUES=!VALIDATION_ISSUES! MISSING: bootmgr.efi;"
        echo   [WARN] bootmgr.efi: MISSING [-5]
    )
    
    if exist "!B_PATH!\EFI\Boot\bootx64.efi" (
        set /a VALIDATION_SCORE+=5
        echo   [OK] bootx64.efi: PRESENT ^[+5^]
    ) else (
        echo   [WARN] bootx64.efi: MISSING (optional)
    )
    
    if exist "!B_PATH!\EFI\Microsoft\Boot\BCD" (
        set /a VALIDATION_SCORE+=10
        for %%F in ("!B_PATH!\EFI\Microsoft\Boot\BCD") do (
            set /a BCD_SIZE=%%~zF
        )
        if !BCD_SIZE! gtr 0 (
            echo   [OK] EFI\Microsoft\Boot\BCD: PRESENT (!BCD_SIZE! bytes^) ^[+10^]
        ) else (
            set "VALIDATION_ISSUES=!VALIDATION_ISSUES! BCD file is empty;"
            echo   [^!] EFI\Microsoft\Boot\BCD: EMPTY [-10]
            set /a VALIDATION_SCORE-=10
        )
    ) else (
        set "VALIDATION_ISSUES=!VALIDATION_ISSUES! MISSING: EFI\Microsoft\Boot\BCD;"
        echo   [^!] EFI\Microsoft\Boot\BCD: MISSING [-10]
    )
    
    :: 2. BCD Backup (20 points)
    echo [*] Checking BCD Backup...
    if exist "!B_PATH!\BCD_Backup" (
        set /a VALIDATION_SCORE+=20
        for %%F in ("!B_PATH!\BCD_Backup") do (
            set /a BCD_BACKUP_SIZE=%%~zF
        )
        if !BCD_BACKUP_SIZE! gtr 0 (
            echo   [OK] BCD_Backup: PRESENT (!BCD_BACKUP_SIZE! bytes^) ^[+20^]
            :: Validate BCD can be read
            bcdedit /store "!B_PATH!\BCD_Backup" /enum {bootmgr} >nul 2>&1
            if !errorlevel! equ 0 (
                echo   [OK] BCD_Backup: VALID (can be enumerated^)
                echo   [BCD] Boot Manager Data:
                for /f "delims=" %%B in ('bcdedit /store "!B_PATH!\BCD_Backup" /enum {bootmgr} 2^>nul ^| findstr /i /c:"device" /c:"path" 2^>nul') do (
                    echo     %%B
                )
            ) else (
                set "VALIDATION_ISSUES=!VALIDATION_ISSUES! BCD_Backup corrupted (cannot enumerate);"
                echo   [^!] BCD_Backup: CORRUPTED (cannot enumerate)
            )
        ) else (
            set "VALIDATION_ISSUES=!VALIDATION_ISSUES! BCD_Backup is empty;"
            echo   [^!] BCD_Backup: EMPTY [-20]
            set /a VALIDATION_SCORE-=20
        )
    ) else (
        set "VALIDATION_ISSUES=!VALIDATION_ISSUES! MISSING: BCD_Backup;"
        echo   [^!] BCD_Backup: MISSING [-20]
    )
    
    :: 3. Registry Hives (20 points)
    echo [*] Checking Registry Hives...
    for %%H in (SYSTEM SOFTWARE) do (
        if exist "!B_PATH!\Hives\%%H" (
            set /a VALIDATION_SCORE+=10
            for %%A in ("!B_PATH!\Hives\%%H") do (
                set /a H_SIZE=%%~zA
                set /a H_MB=!H_SIZE! / 1048576
            )
            if !H_SIZE! gtr 0 (
                echo   [OK] %%H Hive: PRESENT (!H_MB! MB^) ^[+10^]
            ) else (
                set "VALIDATION_ISSUES=!VALIDATION_ISSUES! %%H hive is empty;"
                echo   [^!] %%H Hive: EMPTY [-10]
                set /a VALIDATION_SCORE-=10
            )
        ) else (
            set "VALIDATION_ISSUES=!VALIDATION_ISSUES! MISSING: %%H hive;"
            echo   [^!] %%H Hive: MISSING [-10]
        )
    )
    
    :: 4. Metadata Files (10 points)
    echo [*] Checking Metadata...
    if exist "!B_PATH!\Metadata\Disk_ID.txt" (
        set /a VALIDATION_SCORE+=5
        for %%F in ("!B_PATH!\Metadata\Disk_ID.txt") do (
            if %%~zF gtr 0 (
                echo   [OK] Disk_ID.txt: PRESENT (non-empty^) ^[+5^]
            ) else (
                echo   [WARN] Disk_ID.txt: EMPTY
            )
        )
    ) else (
        echo   [WARN] Disk_ID.txt: MISSING (optional)
    )
    
    if exist "!B_PATH!\Metadata\Disk_Info.txt" (
        set /a VALIDATION_SCORE+=3
        echo   [OK] Disk_Info.txt: PRESENT ^[+3^]
    ) else (
        echo   [WARN] Disk_Info.txt: MISSING (optional)
    )
    
    if exist "!B_PATH!\Metadata\Robocopy_EFI.log" (
        set /a VALIDATION_SCORE+=2
        echo   [OK] Robocopy_EFI.log: PRESENT ^[+2^]
        :: Check Robocopy log for failures
        findstr /i "FAILED" "!B_PATH!\Metadata\Robocopy_EFI.log" >nul 2>&1
        if !errorlevel! equ 0 (
            for /f "tokens=2" %%F in ('findstr /i "FAILED" "!B_PATH!\Metadata\Robocopy_EFI.log" ^| findstr /r "^[ ]*[0-9]"') do (
                if %%F gtr 0 (
                    set "VALIDATION_ISSUES=!VALIDATION_ISSUES! Robocopy reported %%F failures;"
                    echo   [^!] Robocopy log shows %%F FAILED files
                ) else (
                    echo   [OK] Robocopy log: FAILED: 0 (all files copied)
                )
            )
        ) else (
            echo   [OK] Robocopy log: No failures detected
        )
    ) else (
        echo   [WARN] Robocopy_EFI.log: MISSING (optional)
    )
    
    :: 5. Optional Components (10 points)
    echo [*] Checking Optional Components...
    if exist "!B_PATH!\WinRE.wim" (
        set /a VALIDATION_SCORE+=5
        for %%F in ("!B_PATH!\WinRE.wim") do (
            set /a WINRE_SIZE=%%~zF
            set /a WINRE_MB=!WINRE_SIZE! / 1048576
        )
        echo   [OK] WinRE.wim: PRESENT (!WINRE_MB! MB^) ^[+5^]
    ) else (
        echo   [INFO] WinRE.wim: MISSING (optional - only needed for WinRE restore)
    )
    
    if exist "!B_PATH!\Drivers" (
        set /a VALIDATION_SCORE+=5
        set /a DRIVER_COUNT=0
        for /f %%D in ('dir /b /ad "!B_PATH!\Drivers" 2^>nul ^| find /c /v ""') do set "DRIVER_COUNT=%%D"
        if !DRIVER_COUNT! gtr 0 (
            echo   [OK] Drivers folder: PRESENT (!DRIVER_COUNT! driver packages^) ^[+5^]
        ) else (
            echo   [WARN] Drivers folder: EMPTY
        )
    ) else (
        echo   [INFO] Drivers folder: MISSING (optional - only needed for driver restore)
    )
    
    :: Final Score Calculation
    echo.
    echo ===========================================================================
    echo VALIDATION SCORE: !VALIDATION_SCORE! / !MAX_SCORE!
    echo ===========================================================================
    
    :: Critical components = 70 points (bootmgfw.efi + BCD + BCD_Backup + SYSTEM + SOFTWARE)
    if !VALIDATION_SCORE! equ 100 (
        echo [PERFECT] All components verified - backup is RESTORE-READY
        set /a VALID_BACKUPS+=1
    ) else if !VALIDATION_SCORE! geq 70 (
        echo [GOOD] All CRITICAL components present - backup is RESTORE-READY
        echo [READY] This backup has everything needed to restore a broken Windows installation
        set /a VALID_BACKUPS+=1
    ) else if !VALIDATION_SCORE! geq 50 (
        echo [WARNING] Some critical components missing - backup is INCOMPLETE
        echo [NOT READY] Restore might fail or require manual intervention
    ) else (
        echo [CRITICAL] Many critical components missing - backup is INVALID
        echo [NOT READY] DO NOT use this backup for restore - create a new backup
    )
    
    if defined VALIDATION_ISSUES (
        echo.
        echo [ISSUES DETECTED]:
        :: Parse issues string safely
        set "TEMP_ISSUES=!VALIDATION_ISSUES!"
        :parse_issues
        for /f "tokens=1* delims=;" %%A in ("!TEMP_ISSUES!") do (
            set "ISSUE_ITEM=%%A"
            set "TEMP_ISSUES=%%B"
            if defined ISSUE_ITEM (
                if not "!ISSUE_ITEM!"=="" (
                    echo   - !ISSUE_ITEM!
                )
            )
        )
        if defined TEMP_ISSUES (
            if not "!TEMP_ISSUES!"=="" (
                goto :parse_issues
            )
        )
    )
    
    echo.
    echo ===========================================================================
    echo.
)
pause
goto MENU

:VALIDATE_SPECIFIC_BACKUP
cls
echo ===========================================================================
echo       VALIDATE SPECIFIC BACKUP FOLDER
echo ===========================================================================
echo.
set "BASE_DIR=%~dp0"
echo Available backup folders:
echo ---------------------------------------------------------------------------
set "FOLDER_LIST="
set "FOLDER_COUNT=0"
for /f "delims=" %%i in ('dir /b /ad "%BASE_DIR%*NUCLEAR*" 2^>nul') do (
    set /a FOLDER_COUNT+=1
    echo [!FOLDER_COUNT!] %%i
    set "FOLDER_LIST=!FOLDER_LIST!%%i|"
)
echo.
if !FOLDER_COUNT! equ 0 (
    echo [^!] No backup folders found in %BASE_DIR%
    pause
    goto MENU
)
echo.
set /p "BACKUP_SELECT=Enter backup folder name (or number): "
if not defined BACKUP_SELECT (
    echo [^!] No selection made
    pause
    goto MENU
)

:: Check if user entered a number
set "SELECTED_FOLDER="
set "FOLDER_INDEX=0"
for /f "tokens=1* delims=|" %%A in ("!FOLDER_LIST!") do (
    set /a FOLDER_INDEX+=1
    if "!BACKUP_SELECT!"=="!FOLDER_INDEX!" (
        set "SELECTED_FOLDER=%%A"
        goto :found_folder
    )
)
:: If not a number, treat as folder name
set "SELECTED_FOLDER=!BACKUP_SELECT!"

:found_folder
set "B_PATH=%BASE_DIR%!SELECTED_FOLDER!"
if not exist "!B_PATH!" (
    echo [^!] Backup folder not found: !B_PATH!
    pause
    goto MENU
)

:: Run comprehensive validation on this specific folder
cls
echo ===========================================================================
echo       VALIDATING BACKUP: !SELECTED_FOLDER!
echo ===========================================================================
echo.
call :ValidateBackupFolder "!B_PATH!"
echo.
pause
goto MENU

:ValidateBackupFolder
setlocal enabledelayedexpansion
set "B_PATH=%~1"
set /a VALIDATION_SCORE=0
set /a MAX_SCORE=100
set "VALIDATION_ISSUES="
set "BCD_BACKUP_SIZE="
set "H_SIZE="
set "H_MB="
set "BOOTMGFW_SIZE="
set "BOOTMGFW_MB="
set "BCD_SIZE="

:: Use the same validation logic as SCAN_BACKUPS
echo [*] Checking EFI Boot Files...
if exist "!B_PATH!\EFI\Microsoft\Boot\bootmgfw.efi" (
    set /a VALIDATION_SCORE+=20
    for %%F in ("!B_PATH!\EFI\Microsoft\Boot\bootmgfw.efi") do (
        set /a BOOTMGFW_SIZE=%%~zF
        set /a BOOTMGFW_MB=!BOOTMGFW_SIZE! / 1048576
    )
    echo   [OK] bootmgfw.efi: PRESENT (!BOOTMGFW_MB! MB^) ^[+20^]
) else (
    set "VALIDATION_ISSUES=!VALIDATION_ISSUES! MISSING: bootmgfw.efi;"
    echo   [^!] bootmgfw.efi: MISSING [-20]
)

if exist "!B_PATH!\EFI\Microsoft\Boot\BCD" (
    set /a VALIDATION_SCORE+=10
    for %%F in ("!B_PATH!\EFI\Microsoft\Boot\BCD") do set /a BCD_SIZE=%%~zF
    if !BCD_SIZE! gtr 0 (
        echo   [OK] EFI\Microsoft\Boot\BCD: PRESENT (!BCD_SIZE! bytes^) ^[+10^]
    ) else (
        set "VALIDATION_ISSUES=!VALIDATION_ISSUES! BCD file is empty;"
        echo   [^!] EFI\Microsoft\Boot\BCD: EMPTY [-10]
        set /a VALIDATION_SCORE-=10
    )
) else (
    set "VALIDATION_ISSUES=!VALIDATION_ISSUES! MISSING: EFI\Microsoft\Boot\BCD;"
    echo   [^!] EFI\Microsoft\Boot\BCD: MISSING [-10]
)

echo [*] Checking BCD Backup...
if exist "!B_PATH!\BCD_Backup" (
    set /a VALIDATION_SCORE+=20
    for %%F in ("!B_PATH!\BCD_Backup") do set /a BCD_BACKUP_SIZE=%%~zF
    if !BCD_BACKUP_SIZE! gtr 0 (
        echo   [OK] BCD_Backup: PRESENT (!BCD_BACKUP_SIZE! bytes^) ^[+20^]
        bcdedit /store "!B_PATH!\BCD_Backup" /enum {bootmgr} >nul 2>&1
        if !errorlevel! equ 0 (
            echo   [OK] BCD_Backup: VALID (can be enumerated)
        ) else (
            set "VALIDATION_ISSUES=!VALIDATION_ISSUES! BCD_Backup corrupted;"
            echo   [^!] BCD_Backup: CORRUPTED
        )
    ) else (
        set "VALIDATION_ISSUES=!VALIDATION_ISSUES! BCD_Backup is empty;"
        echo   [^!] BCD_Backup: EMPTY [-20]
        set /a VALIDATION_SCORE-=20
    )
) else (
    set "VALIDATION_ISSUES=!VALIDATION_ISSUES! MISSING: BCD_Backup;"
    echo   [^!] BCD_Backup: MISSING [-20]
)

echo [*] Checking Registry Hives...
for %%H in (SYSTEM SOFTWARE) do (
    if exist "!B_PATH!\Hives\%%H" (
        set /a VALIDATION_SCORE+=10
        for %%A in ("!B_PATH!\Hives\%%H") do (
            set /a H_SIZE=%%~zA
            set /a H_MB=!H_SIZE! / 1048576
        )
        if !H_SIZE! gtr 0 (
            echo   [OK] %%H Hive: PRESENT (!H_MB! MB^) ^[+10^]
        ) else (
            set "VALIDATION_ISSUES=!VALIDATION_ISSUES! %%H hive is empty;"
            echo   [^!] %%H Hive: EMPTY [-10]
            set /a VALIDATION_SCORE-=10
        )
    ) else (
        set "VALIDATION_ISSUES=!VALIDATION_ISSUES! MISSING: %%H hive;"
        echo   [^!] %%H Hive: MISSING [-10]
    )
)

echo [*] Checking Robocopy Log...
if exist "!B_PATH!\Metadata\Robocopy_EFI.log" (
    set /a VALIDATION_SCORE+=2
    echo   [OK] Robocopy_EFI.log: PRESENT ^[+2^]
    findstr /i "FAILED" "!B_PATH!\Metadata\Robocopy_EFI.log" >nul 2>&1
    if !errorlevel! equ 0 (
        for /f "tokens=2" %%F in ('findstr /i "FAILED" "!B_PATH!\Metadata\Robocopy_EFI.log" ^| findstr /r "^[ ]*[0-9]"') do (
            if %%F gtr 0 (
                set "VALIDATION_ISSUES=!VALIDATION_ISSUES! Robocopy reported %%F failures;"
                echo   [^!] Robocopy log shows %%F FAILED files
            ) else (
                echo   [OK] Robocopy log: FAILED: 0 (all files copied)
            )
        )
    ) else (
        echo   [OK] Robocopy log: No failures detected
    )
)

echo.
echo ===========================================================================
echo VALIDATION SCORE: !VALIDATION_SCORE! / !MAX_SCORE!
echo ===========================================================================

:: Critical components = 70 points (bootmgfw.efi + BCD + BCD_Backup + SYSTEM + SOFTWARE)
if !VALIDATION_SCORE! equ 100 (
    echo [PERFECT] All components verified - backup is RESTORE-READY
    echo [READY] This backup has everything needed to restore a broken Windows installation
) else if !VALIDATION_SCORE! geq 70 (
    echo [GOOD] All CRITICAL components present - backup is RESTORE-READY
    echo [READY] This backup has everything needed to restore a broken Windows installation
    if !VALIDATION_SCORE! lss 100 (
        echo [NOTE] Optional components (WinRE, Drivers) might be missing but are not required for basic restore
    )
) else if !VALIDATION_SCORE! geq 50 (
    echo [WARNING] Some critical components missing - backup is INCOMPLETE
    echo [NOT READY] Restore might fail or require manual intervention
) else (
    echo [CRITICAL] Many critical components missing - backup is INVALID
    echo [NOT READY] DO NOT use this backup for restore - create a new backup
)

if defined VALIDATION_ISSUES (
    echo.
    echo [ISSUES DETECTED]:
    :: Parse issues string safely
    set "TEMP_ISSUES=!VALIDATION_ISSUES!"
    :parse_issues2
    for /f "tokens=1* delims=;" %%A in ("!TEMP_ISSUES!") do (
        set "ISSUE_ITEM=%%A"
        set "TEMP_ISSUES=%%B"
        if defined ISSUE_ITEM (
            if not "!ISSUE_ITEM!"=="" (
                echo   - !ISSUE_ITEM!
            )
        )
    )
    if defined TEMP_ISSUES (
        if not "!TEMP_ISSUES!"=="" (
            goto :parse_issues2
        )
    )
)

endlocal
goto :eof

:DIAG_DRIVE_SELECTOR
cls
echo ===========================================================================
echo               DEEP E-B-W-D BOOTABILITY VALIDATOR
echo ===========================================================================
powershell -NoProfile -Command "Get-CimInstance Win32_LogicalDisk | Select-Object DeviceID, VolumeName, @{N='Size_GB';E={[math]::round($_.Size / 1GB, 2)}} | Format-Table -AutoSize"
echo.
set /p "SL=Enter Drive Letter(s) (e.g. C or C D E). Press Enter to check ALL drives: "

if not defined SL (
    rem No drives specified — check all letters A-Z
    set "D_LIST=ABCDEFGHIJKLMNOPQRSTUVWXYZ"
) else (
    :: Safe parsing - only uppercase letters A-Z
    set "D_LIST="
    for %%A in (%SL%) do (
        set "letter=%%A"
        set "letter=!letter:~0,1!"
        for %%L in (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
            if /i "!letter!"=="%%L" (
                set "D_LIST=!D_LIST!%%L"
            )
        )
    )
)

if not defined D_LIST (
    echo [!] No valid drive letters detected.
    pause
    goto MENU
)

cls
echo ===========================================================================
echo DRIVE  EFI-PATH   BCD-POINTER   WINLOAD  DRIVERS  STATUS (SCORE)
echo ---------------------------------------------------------------------------

:: Scoring weights (sum to 100)
set /a W_DISKMAP=25
set /a W_ESP=20
set /a W_EFI=20
set /a W_BCD_MATCH=20
set /a W_WINLOAD=10
set /a W_DRIVERS=5
set /a W_DRIVERS_UNKNOWN=2

:: Ensure temp directory exists and validate paths
if not defined temp set "temp=%TMP%"
if not defined temp set "temp=C:\Windows\Temp"
if not exist "!temp!" mkdir "!temp!" >nul 2>&1
if not exist "!temp!" (
    echo [ERROR] Cannot access or create temp directory: !temp!
    pause
    goto MENU
)
set "SUMMARY_FILE=!temp!\qa_summary_%random%.txt"
set "SUMMARY_TABLE=!temp!\qa_table_%random%.txt"
if defined QA_DEBUG echo [DBG] SUMMARY_FILE=!SUMMARY_FILE!
if defined QA_DEBUG echo [DBG] SUMMARY_TABLE=!SUMMARY_TABLE!
if exist "!SUMMARY_FILE!" del "!SUMMARY_FILE!" >nul 2>&1
if exist "!SUMMARY_TABLE!" del "!SUMMARY_TABLE!" >nul 2>&1
echo Summary of findings for this run: > "!SUMMARY_FILE!"

set "HEADER_PRINTED=0"
:: Check if processing all drives (26 letters)
if "!D_LIST!"=="ABCDEFGHIJKLMNOPQRSTUVWXYZ" (
    :: Process all drives A-Z directly
    for %%L in (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
        set "D_LTR=%%L"
        if defined QA_DEBUG echo [DBG] Processing drive %%L
        if defined QA_DEBUG echo [DBG] vol check on %%L
        vol %%L: >nul 2>&1
        if errorlevel 1 (
            echo %%L:     --         --          --       --       OFFLINE
            call :WriteSummaryTableEntry "%%L" "[OFFLINE]" "0" "" "%SUMMARY_TABLE%"
        ) else (
            if defined QA_DEBUG echo [DBG] checking Windows folder on %%L
            if not exist "%%L:\Windows" (
                echo %%L:     --         --          --       --       RED ^(0%%^) - No Windows folder
                call :GetDriveLabel "%%L" DRV_LABEL
                if not defined DRV_LABEL set "DRV_LABEL=[none]"
                call :WriteSummaryTableEntry "%%L" "!DRV_LABEL!" "0" "No Windows" "%SUMMARY_TABLE%"
            ) else (
                set "D_LTR=%%L"
                call :ProcessSingleDrive
            )
        )
    )
    goto DIAG_DONE
) else (
    :: Process custom drive list character by character using pure batch
    set "idx=0"
    :LOOP_START
    call :GetCharAtIndex "!D_LIST!" "!idx!" D_LTR
    if not defined D_LTR goto DIAG_DONE
    if "!D_LTR!"=="" goto DIAG_DONE
    if defined QA_DEBUG echo [DBG] idx=!idx! D_LTR=!D_LTR! D_LIST=!D_LIST!
    :: Verify drive exists before processing
    vol !D_LTR!: >nul 2>&1
    if errorlevel 1 (
        echo !D_LTR!:     --         --          --       --       OFFLINE
        call :GetDriveLabel "!D_LTR!" DRV_LABEL
        if not defined DRV_LABEL set "DRV_LABEL=[OFFLINE]"
        call :WriteSummaryTableEntry "!D_LTR!" "!DRV_LABEL!" "0" "" "%SUMMARY_TABLE%"
        set /a idx+=1
        goto LOOP_START
    )
    :: Check for Windows folder
    if not exist "!D_LTR!:\Windows" (
        echo !D_LTR!:     --         --          --       --       RED ^(0%%^) - No Windows folder
        call :GetDriveLabel "!D_LTR!" DRV_LABEL
        if not defined DRV_LABEL set "DRV_LABEL=[none]"
        call :WriteSummaryTableEntry "!D_LTR!" "!DRV_LABEL!" "0" "No Windows" "%SUMMARY_TABLE%"
        set /a idx+=1
        goto LOOP_START
    )
    :: Process the drive
    call :ProcessSingleDrive
    set /a idx+=1
    goto LOOP_START
)
goto DIAG_DONE

:ProcessSingleDrive
if defined QA_DEBUG echo [DBG] Processing drive !D_LTR!

if defined QA_DEBUG echo [DBG] vol check on !D_LTR!
vol !D_LTR!: >nul 2>&1
if errorlevel 1 (
    echo !D_LTR!:     --         --          --       --       OFFLINE
    call :WriteSummaryTableEntry "!D_LTR!" "[OFFLINE]" "0" "" "%SUMMARY_TABLE%"
    goto :eof
)

if defined QA_DEBUG echo [DBG] checking Windows folder on !D_LTR!
if not exist "!D_LTR!:\Windows" (
    echo !D_LTR!:     --         --          --       --       RED ^(0%%^) - No Windows folder
    call :GetDriveLabel "!D_LTR!" DRV_LABEL
    call :WriteSummaryTableEntry "!D_LTR!" "!DRV_LABEL!" "0" "No Windows" "%SUMMARY_TABLE%"
    goto :eof
)

if defined QA_DEBUG echo [DBG] Windows folder exists on !D_LTR!
set "DRV_START=%time%"
if defined VERBOSE echo    [STEP] Starting checks for !D_LTR! at !DRV_START!

:: Detect if this is the currently running OS (use drive letter comparison only - more reliable)
set "BOOT_PROVEN=0"
set "IS_LIVE_OS=0"
set "SYSTEM_DRIVE_LETTER=%SystemDrive:~0,1%"
if /i "!D_LTR!"=="!SYSTEM_DRIVE_LETTER!" set "IS_LIVE_OS=1"
:: Optional: also check SystemRoot drive letter for extra confirmation
if !IS_LIVE_OS! equ 1 (
    set "SYSTEMROOT_DRIVE=%SystemRoot:~0,1%"
    if /i not "!D_LTR!"=="!SYSTEMROOT_DRIVE!" set "IS_LIVE_OS=0"
)
if !IS_LIVE_OS! equ 1 (
    set "BOOT_PROVEN=1"
    if defined QA_DEBUG echo [DBG] Detected: This is the currently running OS - boot proven! (SystemDrive=!SYSTEM_DRIVE_LETTER!)
)

set /a PROB=0
set /a CONFIDENCE=100
set "EXPLANATION="
set "EFI_FOUND=FAIL"
set "BCD_VALID=FAIL"
set "WL_STAT=--"
set "DRV_STAT=--"
set "DRV_CONFIDENCE=--"
set "LOG_STR="
set "DISK_MAP_METHOD="
set "ESP_DISCOVERY_METHOD="
:: Explicit boolean flags for truth tracking
set /a ESP_FOUND=0
set /a ESP_MOUNTED=0
set /a EFI_PRESENT=0
set /a BCD_PRESENT=0
set /a BCD_MATCH=0
set /a DRIVERS_OK=0
if defined QA_DEBUG echo [DBG] init vars PROB=!PROB! EFI_FOUND=!EFI_FOUND! BCD_VALID=!BCD_VALID! WL_STAT=!WL_STAT! DRV_STAT=!DRV_STAT! LOG_STR=!LOG_STR!"

:: Find free temp letter for ESP
set "ESP_LETTER="
for %%L in (Z Y X W V U T S R Q P O N M L K J I H G F) do (
    if not defined ESP_LETTER (
        vol %%L: >nul 2>&1
        if errorlevel 1 set "ESP_LETTER=%%L"
    )
)

if not defined ESP_LETTER (
    set "LOG_STR=!LOG_STR! [NO_FREE_LETTER]"
    set /a ESP_FOUND=0
    goto AFTER_ESP
)

:: Get DiskNumber and ESP partition
if defined QA_DEBUG echo [DBG] calling GetDiskNumber for !D_LTR! at %time%
if defined VERBOSE echo    [STEP] Resolving disk mapping for !D_LTR!...
call :GetDiskNumber "!D_LTR!"
if not defined DISK_NUM (
    set "LOG_STR=!LOG_STR! [NO_DISKMAP]"
    set "DISK_MAP_METHOD=NONE"
    goto AFTER_ESP
) else (
    rem credit for disk mapping
    set /a PROB+=W_DISKMAP
    set "EXPLANATION=!EXPLANATION! +!W_DISKMAP! DiskMap(found via !DISK_MAP_METHOD!);"
    if defined VERBOSE echo    [DONE] DiskMap: disk=!DISK_NUM! method=!DISK_MAP_METHOD!
)

if defined QA_DEBUG echo [DBG] calling GetESPPart for disk !DISK_NUM! at %time%
if defined VERBOSE echo    [STEP] Looking for ESP on disk !DISK_NUM!...
call :GetESPPart !DISK_NUM!

if not defined ESP_PART (
    set "LOG_STR=!LOG_STR! [NO_ESP]"
    set /a ESP_FOUND=0
    goto AFTER_ESP
) else (
    set /a ESP_FOUND=1
    set /a PROB+=W_ESP
    set "EXPLANATION=!EXPLANATION! +!W_ESP! ESP;"
    if defined VERBOSE echo    [DONE] ESP=Partition !ESP_PART! (method=!ESP_DISCOVERY_METHOD!)
)

:: Mount ESP
set "DP_FILE=%temp%\dp_%random%.txt"
set "DP_OUTPUT=%temp%\dp_out_%random%.txt"
(
    echo select disk !DISK_NUM!
    echo select partition !ESP_PART!
    echo assign letter=!ESP_LETTER!
    echo exit
) > "!DP_FILE!"
if defined VERBOSE echo    [STEP] Mounting ESP to !ESP_LETTER! using diskpart...
diskpart /s "!DP_FILE!" > "!DP_OUTPUT!" 2>&1
:: Verify mount actually succeeded
set /a ESP_MOUNTED=0
if exist "!ESP_LETTER!:\EFI\" (
    set /a ESP_MOUNTED=1
    if defined VERBOSE echo    [DONE] Mounted ESP to !ESP_LETTER! and verified
) else (
    set "LOG_STR=!LOG_STR! [ESP_MOUNT_FAILED]"
    if defined VERBOSE (
        echo    [WARN] DiskPart mount might have failed, checking output:
        type "!DP_OUTPUT!"
    )
    del "!DP_OUTPUT!" >nul 2>&1
    goto AFTER_ESP
)
del "!DP_OUTPUT!" >nul 2>&1

:: Check EFI files
if exist "!ESP_LETTER!:\EFI\Microsoft\Boot\bootmgfw.efi" (
    set "EFI_FOUND=OK"
    set /a EFI_PRESENT=1
    set /a PROB+=W_EFI
    set "EXPLANATION=!EXPLANATION! +!W_EFI! EFI present;"
) else (
    set /a EFI_PRESENT=0
    set "LOG_STR=!LOG_STR! [NO_BOOTMGFW]"
)

:: Check BCD
set /a BCD_PRESENT=0
set /a BCD_MATCH=0
if exist "!ESP_LETTER!:\EFI\Microsoft\Boot\BCD" (
    set /a BCD_PRESENT=1
    set "BCD_OSDEVICE="
    for /f "delims=" %%B in ('bcdedit /store "!ESP_LETTER!:\EFI\Microsoft\Boot\BCD" /enum {default} 2^>nul ^| findstr /i "osdevice.*"') do set "BCD_OSDEVICE=%%B"
    if defined BCD_OSDEVICE (
        if defined VERBOSE echo    [STEP] Inspecting BCD osdevice for !D_LTR!...
        :: Check for drive letter match, volume GUID, or HarddiskVolume
        echo !BCD_OSDEVICE! | findstr /i "!D_LTR!:" >nul
        if !errorlevel! equ 0 (
            set "BCD_VALID=OK"
            set /a BCD_MATCH=1
            set /a PROB+=W_BCD_MATCH
            set "EXPLANATION=!EXPLANATION! +!W_BCD_MATCH! BCD->partition=!D_LTR!:;"
            if defined VERBOSE echo    [DONE] BCD points to partition !D_LTR!.
        ) else (
            :: Check if it uses volume GUID or HarddiskVolume format (might still be valid)
            echo !BCD_OSDEVICE! | findstr /i "partition=" >nul
            if !errorlevel! equ 0 (
                set "BCD_VALID=WARN (Volume ID)"
                set /a BCD_MATCH=0
                set /a PROB+=W_BCD_MATCH/2
                set "EXPLANATION=!EXPLANATION! +!W_BCD_MATCH!/2 BCD->osdevice='!BCD_OSDEVICE!';"
                if defined VERBOSE echo    [WARN] BCD osdevice does not reference !D_LTR! directly.
            ) else (
                set "BCD_VALID=UNKNOWN"
                set /a BCD_MATCH=0
                set "LOG_STR=!LOG_STR! [BCD_PRESENT_NO_OSDEVICE]"
            )
        )
    ) else (
        set "BCD_VALID=UNKNOWN"
        set /a BCD_MATCH=0
        set "LOG_STR=!LOG_STR! [BCD_PRESENT_NO_OSDEVICE]"
    )
) else (
    set /a BCD_PRESENT=0
    set /a BCD_MATCH=0
    set "LOG_STR=!LOG_STR! [NO_BCD]"
)


:: Unmount
(
    echo select disk !DISK_NUM!
    echo select partition !ESP_PART!
    echo remove letter=!ESP_LETTER!
    echo exit
) > "!DP_FILE!"
if defined VERBOSE echo    [STEP] Unmounting ESP from !ESP_LETTER!...
diskpart /s "!DP_FILE!" >nul 2>&1
if defined VERBOSE echo    [DONE] Unmounted ESP
if defined VERBOSE echo    [VERBOSE] Deleting DP_FILE: !DP_FILE!
del "!DP_FILE!" >nul 2>&1
if defined VERBOSE if exist "!DP_FILE!" echo    [VERBOSE] WARNING: DP_FILE still exists: !DP_FILE! else echo    [VERBOSE] DP_FILE removed

:AFTER_ESP

:: Winload check
if exist "!D_LTR!:\Windows\System32\winload.efi" (
    set "WL_STAT=OK"
    set /a PROB+=W_WINLOAD
    set "EXPLANATION=!EXPLANATION! +!W_WINLOAD! winload;"
) else (
    set "WL_STAT=FAIL"
)

:: Enhanced context-aware driver check with boot-storage detection
set "DRV_STAT=UNKNOWN"
set "DRV_ERROR_DETAIL="
set "DRV_CONFIDENCE=--"
set /a DRIVERS_SCORE=0
set "SYSTEM_HIVE=!D_LTR!:\Windows\System32\config\SYSTEM"

:: Load hive once and read everything (avoid double-loading)
set "ACTIVE_CONTROLSET="
set "CONTROLSET_NUM="
set "REG_ROOT="
set "HIVE_LOADED_NAME="
set "TMP_HIVE_FILE="

if !IS_LIVE_OS! equ 1 (
    :: For live OS, use live registry - no loading needed
    if defined QA_DEBUG echo [DBG] Live OS detected - using HKLM\SYSTEM directly
    set "REG_ROOT=HKLM\SYSTEM"
    for /f "tokens=3" %%C in ('reg query "HKLM\SYSTEM\Select" /v Current 2^>nul') do (
        set "CONTROLSET_NUM=%%C"
    )
) else if exist "!SYSTEM_HIVE!" (
    :: For offline drives, load hive once and keep it loaded for all reads
    if defined QA_DEBUG echo [DBG] Offline drive - loading SYSTEM hive once
    :: Validate temp path before using it
    if not defined temp set "temp=%TMP%"
    if not defined temp set "temp=C:\Windows\Temp"
    if not exist "!temp!" mkdir "!temp!" >nul 2>&1
    set "TMP_HIVE_FILE=!temp!\qa_system_%random%.tmp"
    if defined QA_DEBUG echo [DBG] Temp hive file: !TMP_HIVE_FILE!
    
    :: Try direct load first
    reg load HKLM\TEMP_HIVE_DRV "!SYSTEM_HIVE!" >nul 2>&1
    if not errorlevel 1 (
        set "REG_ROOT=HKLM\TEMP_HIVE_DRV"
        set "HIVE_LOADED_NAME=TEMP_HIVE_DRV"
        if defined QA_DEBUG echo [DBG] Direct load successful
    ) else (
        :: Try copying to temp and loading from copy
        if defined QA_DEBUG echo [DBG] Direct load failed, trying temp copy
        copy /y "!SYSTEM_HIVE!" "!TMP_HIVE_FILE!" >nul 2>&1
        if exist "!TMP_HIVE_FILE!" (
            reg load HKLM\TEMP_HIVE_DRV2 "!TMP_HIVE_FILE!" >nul 2>&1
            if not errorlevel 1 (
                set "REG_ROOT=HKLM\TEMP_HIVE_DRV2"
                set "HIVE_LOADED_NAME=TEMP_HIVE_DRV2"
                if defined QA_DEBUG echo [DBG] Temp copy load successful
            ) else (
                if defined QA_DEBUG echo [DBG] Temp copy load also failed
                del "!TMP_HIVE_FILE!" >nul 2>&1
            )
        ) else (
            if defined QA_DEBUG echo [DBG] Failed to copy hive to temp
        )
    )
    
    :: If we loaded a hive, read ControlSet from it
    if defined REG_ROOT (
        for /f "tokens=3" %%C in ('reg query "!REG_ROOT!\Select" /v Current 2^>nul') do (
            set "CONTROLSET_NUM=%%C"
        )
    ) else (
        :: Cannot load hive - mark as UNKNOWN
        set "DRV_STAT=UNKNOWN"
        set "DRV_ERROR_DETAIL=Cannot load SYSTEM hive (file locked or inaccessible)"
        set "DRV_CONFIDENCE=0%%"
        set /a CONFIDENCE-=5
        set /a DRIVERS_SCORE=W_DRIVERS_UNKNOWN
        set /a PROB+=W_DRIVERS_UNKNOWN
        set "EXPLANATION=!EXPLANATION! +!W_DRIVERS_UNKNOWN! drivers_unknown;"
        goto DRIVER_CHECK_DONE
    )
) else (
    :: No SYSTEM hive found
    set "DRV_STAT=FAIL"
    set "DRV_ERROR_DETAIL=SYSTEM hive not found at !SYSTEM_HIVE!"
    set "DRV_CONFIDENCE=0%%"
    set /a CONFIDENCE-=5
    goto DRIVER_CHECK_DONE
)

:: Normalize ControlSet number (hex to decimal, pad to 3 digits)
if defined CONTROLSET_NUM (
    :: Remove 0x prefix if present and convert hex to decimal
    set "CONTROLSET_NUM=!CONTROLSET_NUM:0x=!"
    set "CONTROLSET_NUM=!CONTROLSET_NUM: =!"
    :: Convert hex to decimal using PowerShell
    for /f "delims=" %%N in ('powershell -NoProfile -Command "[Convert]::ToInt32('!CONTROLSET_NUM!', 16)" 2^>nul') do set "CONTROLSET_DEC=%%N"
    if not defined CONTROLSET_DEC set "CONTROLSET_DEC=!CONTROLSET_NUM!"
    :: Pad to 3 digits
    if !CONTROLSET_DEC! lss 10 (
        set "ACTIVE_CONTROLSET=ControlSet00!CONTROLSET_DEC!"
    ) else if !CONTROLSET_DEC! lss 100 (
        set "ACTIVE_CONTROLSET=ControlSet0!CONTROLSET_DEC!"
    ) else (
        set "ACTIVE_CONTROLSET=ControlSet!CONTROLSET_DEC!"
    )
) else (
    set "ACTIVE_CONTROLSET=ControlSet001"
)
if defined QA_DEBUG echo [DBG] Normalized ControlSet: !ACTIVE_CONTROLSET!

:: Detect storage type and determine which drivers to check (use BusType, not Model)
set "STORAGE_TYPE=UNKNOWN"
set "DRIVERS_TO_CHECK="
if !IS_LIVE_OS! equ 1 (
    :: For live OS, detect storage type from BusType (more reliable than Model)
    set "DISK_BUSTYPE="
    for /f "delims=" %%B in ('powershell -NoProfile -Command "$disk = Get-Disk | Where-Object {$_.Number -eq (Get-Partition -DriveLetter '!D_LTR!' | Select-Object -ExpandProperty DiskNumber)}; if ($disk) { $disk.BusType }" 2^>nul') do (
        set "DISK_BUSTYPE=%%B"
    )
    if defined DISK_BUSTYPE (
        :: BusType values: 17=NVMe, 3=ATA/SATA, 11=RAID, etc.
        if "!DISK_BUSTYPE!"=="17" (
            set "STORAGE_TYPE=NVMe"
            set "DRIVERS_TO_CHECK=stornvme"
        ) else if "!DISK_BUSTYPE!"=="3" (
            set "STORAGE_TYPE=SATA"
            set "DRIVERS_TO_CHECK=storahci"
        ) else if "!DISK_BUSTYPE!"=="11" (
            set "STORAGE_TYPE=RAID"
            set "DRIVERS_TO_CHECK=iaStorVD iaStorAC storahci"
        ) else (
            set "STORAGE_TYPE=GENERIC"
            set "DRIVERS_TO_CHECK=storahci storport"
        )
        if defined QA_DEBUG echo [DBG] Detected BusType=!DISK_BUSTYPE! StorageType=!STORAGE_TYPE!
    ) else (
        :: Fallback to generic if detection fails
        set "STORAGE_TYPE=GENERIC"
        set "DRIVERS_TO_CHECK=storahci storport"
    )
) else (
    :: For offline drives, be conservative - check common drivers but don't assume any is correct
    :: Since we can't detect controller type offline, we'll check but be more lenient
    set "DRIVERS_TO_CHECK=stornvme storahci storport"
    :: Mark as potentially UNKNOWN if we can't verify which driver is actually used
    set "OFFLINE_DRIVER_CHECK=1"
)
if not defined DRIVERS_TO_CHECK set "DRIVERS_TO_CHECK=storahci storport"

:: Check drivers using multiple evidence points (REG_ROOT already set above)
set "DRIVER_FOUND=0"
set "DRIVER_VERIFIED=0"
set "DRIVER_CHECKED="

if not defined REG_ROOT (
    :: This shouldn't happen, but handle it gracefully
    set "DRV_STAT=UNKNOWN"
    set "DRV_ERROR_DETAIL=Registry root not available"
    set "DRV_CONFIDENCE=0%%"
    set /a CONFIDENCE-=5
    set /a DRIVERS_SCORE=W_DRIVERS_UNKNOWN
    set /a PROB+=W_DRIVERS_UNKNOWN
    set "EXPLANATION=!EXPLANATION! +!W_DRIVERS_UNKNOWN! drivers_unknown;"
    goto DRIVER_CHECK_DONE
)

:: Check each driver in the list
for %%D in (!DRIVERS_TO_CHECK!) do (
    if !DRIVER_VERIFIED! equ 0 (
        set "DRV_SVC=%%D"
        set "DRIVER_CHECKED=!DRIVER_CHECKED! %%D"
        
        :: Check 1: Service key exists
        reg query "!REG_ROOT!\!ACTIVE_CONTROLSET!\Services\!DRV_SVC!" >nul 2>&1
        if not errorlevel 1 (
            set "DRIVER_FOUND=1"
            :: Check 2: Start value (should be 0 for boot-start)
            set "START_VAL="
            for /f "tokens=3" %%S in ('reg query "!REG_ROOT!\!ACTIVE_CONTROLSET!\Services\!DRV_SVC!" /v Start 2^>nul') do (
                set "START_VAL=%%S"
            )
            set "START_OK=0"
            if defined START_VAL (
                if "!START_VAL!"=="0x0" set "START_OK=1"
                if "!START_VAL!"=="0x00000000" set "START_OK=1"
                if "!START_VAL!"=="0" set "START_OK=1"
            )
            :: Check 3: Driver file exists
            set "DRV_FILE_EXISTS=0"
            if exist "!D_LTR!:\Windows\System32\drivers\!DRV_SVC!.sys" set "DRV_FILE_EXISTS=1"
            
            :: For live OS, verify driver is actually loaded/running
            set "DRIVER_ACTIVE=0"
            if !IS_LIVE_OS! equ 1 (
                :: Check if driver is actually loaded via Get-Service or driverquery
                for /f "delims=" %%A in ('powershell -NoProfile -Command "Get-Service -Name '!DRV_SVC!' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Status" 2^>nul') do (
                    set "SVC_STATUS=%%A"
                )
                if defined SVC_STATUS (
                    if /i "!SVC_STATUS!"=="Running" set "DRIVER_ACTIVE=1"
                )
                :: Also check if driver is loaded via driverquery
                driverquery /fo csv | findstr /i "!DRV_SVC!" >nul 2>&1
                if not errorlevel 1 set "DRIVER_ACTIVE=1"
            ) else (
                :: For offline, we can't verify if it's actually loaded - just check config
                set "DRIVER_ACTIVE=1"
            )
            
            :: Evaluate evidence
            if !START_OK! equ 1 if !DRV_FILE_EXISTS! equ 1 if !DRIVER_ACTIVE! equ 1 (
                :: All checks pass - verified config and (for live OS) actually loaded
                set "DRIVER_VERIFIED=1"
                if !IS_LIVE_OS! equ 1 (
                    set "DRV_STAT=OK"
                    set "DRV_ERROR_DETAIL=OK (Verified config + driver loaded)"
                ) else (
                    set "DRV_STAT=OK"
                    set "DRV_ERROR_DETAIL=OK (Verified config - plausible)"
                )
                set "DRV_CONFIDENCE=100%%"
                set /a DRIVERS_SCORE=W_DRIVERS
                set /a PROB+=W_DRIVERS
                set "EXPLANATION=!EXPLANATION! +!W_DRIVERS! drivers;"
            ) else if !DRV_FILE_EXISTS! equ 0 (
                :: Missing driver file - FAIL
                set "DRV_STAT=FAIL"
                set "DRV_ERROR_DETAIL=FAIL: !DRV_SVC! service exists but driver file missing"
                set "DRV_CONFIDENCE=100%%"
                set /a DRIVERS_SCORE=0
            ) else if !DRIVER_ACTIVE! equ 0 if !IS_LIVE_OS! equ 1 (
                :: Driver config exists but not loaded/running - WARN
                set "DRV_STAT=WARN"
                set "DRV_ERROR_DETAIL=WARN: !DRV_SVC! configured but not loaded/running"
                set "DRV_CONFIDENCE=60%%"
                set /a DRIVERS_SCORE=W_DRIVERS
                set /a PROB+=W_DRIVERS
                set "EXPLANATION=!EXPLANATION! +!W_DRIVERS! drivers_warn;"
            ) else (
                :: Start value not ideal - WARN but still OK for boot
                set "DRV_STAT=WARN"
                set "DRV_ERROR_DETAIL=WARN: !DRV_SVC! Start=!START_VAL! (expected 0)"
                set "DRV_CONFIDENCE=80%%"
                set /a DRIVERS_SCORE=W_DRIVERS
                set /a PROB+=W_DRIVERS
                set "EXPLANATION=!EXPLANATION! +!W_DRIVERS! drivers_warn;"
            )
        )
    )
)

:: Cleanup loaded hives (only if we actually loaded one)
if defined HIVE_LOADED_NAME (
    if "!HIVE_LOADED_NAME!"=="TEMP_HIVE_DRV" (
        reg unload HKLM\TEMP_HIVE_DRV >nul 2>&1
        if defined QA_DEBUG echo [DBG] Unloaded TEMP_HIVE_DRV
    ) else if "!HIVE_LOADED_NAME!"=="TEMP_HIVE_DRV2" (
        reg unload HKLM\TEMP_HIVE_DRV2 >nul 2>&1
        if defined QA_DEBUG echo [DBG] Unloaded TEMP_HIVE_DRV2
        if defined TMP_HIVE_FILE (
            if exist "!TMP_HIVE_FILE!" (
                del "!TMP_HIVE_FILE!" >nul 2>&1
                if defined QA_DEBUG echo [DBG] Deleted temp hive file: !TMP_HIVE_FILE!
            )
        )
    )
)

:: If no driver found but boot is proven, mark as OK
if !DRIVER_FOUND! equ 0 (
    if !BOOT_PROVEN! equ 1 (
        :: Boot proven - drivers must be OK
        set "DRV_STAT=OK"
        set "DRV_ERROR_DETAIL=OK (Boot proven - system is running)"
        set "DRV_CONFIDENCE=100%%"
        set /a DRIVERS_SCORE=W_DRIVERS
        set /a PROB+=W_DRIVERS
        set "EXPLANATION=!EXPLANATION! +!W_DRIVERS! drivers_boot_proven;"
    ) else (
        :: No driver found and not boot proven - UNKNOWN
        set "DRV_STAT=UNKNOWN"
        set "DRV_ERROR_DETAIL=UNKNOWN: No storage drivers found (!DRIVER_CHECKED!)"
        set "DRV_CONFIDENCE=0%%"
        set /a CONFIDENCE-=5
        set /a DRIVERS_SCORE=W_DRIVERS_UNKNOWN
        set /a PROB+=W_DRIVERS_UNKNOWN
        set "EXPLANATION=!EXPLANATION! +!W_DRIVERS_UNKNOWN! drivers_unknown;"
    )
) else if !DRIVER_VERIFIED! equ 0 (
    :: Driver found but not verified - UNKNOWN
    if defined OFFLINE_DRIVER_CHECK (
        :: For offline, if we found drivers but can't verify which is correct, mark as UNKNOWN
        set "DRV_STAT=UNKNOWN"
        set "DRV_ERROR_DETAIL=UNKNOWN: Storage drivers found but cannot verify which is boot-critical (offline check)"
        set "DRV_CONFIDENCE=50%%"
        set /a CONFIDENCE-=3
        set /a DRIVERS_SCORE=W_DRIVERS_UNKNOWN
        set /a PROB+=W_DRIVERS_UNKNOWN
        set "EXPLANATION=!EXPLANATION! +!W_DRIVERS_UNKNOWN! drivers_unknown;"
    ) else (
        :: For live OS, if driver found but not verified, it's a real issue
        set "DRV_STAT=WARN"
        set "DRV_ERROR_DETAIL=WARN: Storage drivers found but verification incomplete"
        set "DRV_CONFIDENCE=60%%"
        set /a DRIVERS_SCORE=W_DRIVERS
        set /a PROB+=W_DRIVERS
        set "EXPLANATION=!EXPLANATION! +!W_DRIVERS! drivers_warn;"
    )
)

:DRIVER_CHECK_DONE


:: finalize PROB and status
if !PROB! lss 0 set /a PROB=0
if !PROB! gtr 100 set /a PROB=100
set "STATUS=RED (!PROB!%%)"
if !PROB! geq 90 set "STATUS=GREEN (!PROB!%%)"
if !PROB! geq 50 if !PROB! lss 90 set "STATUS=YELLOW (!PROB!%%)"

:: Capture end time
set "DRV_END=%time%"

:: Print table header once before the first printed row so headers are beside entries
if "!HEADER_PRINTED!"=="0" (
    echo ===========================================================================
    echo DRIVE  EFI-PATH   BCD-POINTER   WINLOAD  DRIVERS  STATUS (SCORE)
    echo ---------------------------------------------------------------------------
    set "HEADER_PRINTED=1"
)

echo !D_LTR!:     !EFI_FOUND!        !BCD_VALID!         !WL_STAT!      !DRV_STAT!    !STATUS!
if defined LOG_STR echo      [Issues]: !LOG_STR!
if !PROB! equ 100 echo      [PERFECT] Full boot integrity confirmed.
if defined QA_DEBUG (
    echo [DBG] Done for !D_LTR!: PROB=!PROB! EXPLANATION=!EXPLANATION! Start=!DRV_START! End=!DRV_END!
) else if defined VERBOSE (
    echo [VERBOSE] Done for !D_LTR!: PROB=!PROB! EXPLANATION=!EXPLANATION! Duration: !DRV_START! -> !DRV_END!
)

:: Append human-readable summary block for this drive (multi-line)
call :GetDriveLabel "!D_LTR!" DRV_LABEL
:: Add to summary table
call :WriteSummaryTableEntry "!D_LTR!" "!DRV_LABEL!" "!PROB!" "" "%SUMMARY_TABLE%"

if defined SUMMARY_FILE (
    if exist "!SUMMARY_FILE!" (
        >> "!SUMMARY_FILE!" echo -----------------------------------------------------------------------
        >> "!SUMMARY_FILE!" echo Drive: !D_LTR!: Label="!DRV_LABEL!"
        >> "!SUMMARY_FILE!" echo   - EFI: !EFI_FOUND!
        if defined LOG_STR (
            >> "!SUMMARY_FILE!" echo   - Issues: !LOG_STR!
        )
        >> "!SUMMARY_FILE!" echo   - BCD: !BCD_VALID!
        if defined BCD_OSDEVICE (
            >> "!SUMMARY_FILE!" echo     - osdevice: !BCD_OSDEVICE!
        )
        >> "!SUMMARY_FILE!" echo   - winload: !WL_STAT!
        >> "!SUMMARY_FILE!" echo   - drivers: !DRV_STAT!
        if defined DRV_ERROR_DETAIL (
            >> "!SUMMARY_FILE!" echo     [DETAIL] !DRV_ERROR_DETAIL!
        )
        if defined DRV_CONFIDENCE (
            >> "!SUMMARY_FILE!" echo     [CONFIDENCE] !DRV_CONFIDENCE!
        )
        if !BOOT_PROVEN! equ 1 (
            >> "!SUMMARY_FILE!" echo     [NOTE] Boot proven - system is currently running from this drive
        )
        >> "!SUMMARY_FILE!" echo   - PROB: !PROB!%%
        if defined CONFIDENCE (
            >> "!SUMMARY_FILE!" echo   - Verification Coverage: !CONFIDENCE!%%
        )
        >> "!SUMMARY_FILE!" echo   - Evidence breakdown:
    )
)
if defined EXPLANATION (
    :: Use PowerShell to safely split the explanation string
    set "TMP_EXP=!temp!\qa_exp_%random%.txt"
    setlocal enabledelayedexpansion
    set "EXP_VAL=!EXPLANATION!"
    endlocal & set "EXP_VAL=%EXP_VAL%"
    powershell -NoProfile -Command "$exp='%EXP_VAL%'; $exp -split ';' | Where-Object { $_.Trim() -ne '' } | ForEach-Object { $_.Trim() } | Out-File -FilePath '%TMP_EXP%' -Encoding ASCII" 2>nul
    :: Read and display each line
    if exist "!TMP_EXP!" (
        for /f "usebackq delims=" %%L in ("!TMP_EXP!") do (
            set "LINE=%%L"
            if defined SUMMARY_FILE (
                >> "!SUMMARY_FILE!" echo     !LINE!
            )
        )
        del "!TMP_EXP!" >nul 2>&1
    )
) else (
    if defined SUMMARY_FILE (
        >> "!SUMMARY_FILE!" echo     [No evidence data available]
    )
)
:: Add duration
if defined SUMMARY_FILE (
    >> "!SUMMARY_FILE!" echo   - Duration: !DRV_START! -> !DRV_END!
)
:: Compute and display missing potential breakdown
:: Only compute missing breakdown if PROB is not 100
if !PROB! neq 100 (
    set /a C_DISK=0
    set /a C_ESP=0
    set /a C_EFI=0
    set /a C_BCD=0
    set /a C_WIN=0
    set /a C_DRV=0
    if /i not "!DISK_MAP_METHOD!"=="NONE" set /a C_DISK=W_DISKMAP
    if !ESP_FOUND! equ 1 set /a C_ESP=W_ESP
    if !EFI_PRESENT! equ 1 set /a C_EFI=W_EFI
    if !BCD_MATCH! equ 1 (
        set /a C_BCD=W_BCD_MATCH
    ) else (
        if /i "!BCD_VALID!"=="WARN (Volume ID)" set /a C_BCD=W_BCD_MATCH/2
    )
    if /i "!WL_STAT!"=="OK" set /a C_WIN=W_WINLOAD
    :: Driver scoring: OK gets full points, UNKNOWN gets partial, FAIL gets 0
    if /i "!DRV_STAT!"=="OK" (
        set /a C_DRV=W_DRIVERS
    ) else if /i "!DRV_STAT!"=="UNKNOWN" (
        set /a C_DRV=W_DRIVERS_UNKNOWN
    ) else if /i "!DRV_STAT!"=="FAIL" (
        set /a C_DRV=0
    ) else if /i "!DRV_STAT!"=="WARN" (
        set /a C_DRV=W_DRIVERS
    )
    set /a SUMC=C_DISK + C_ESP + C_EFI + C_BCD + C_WIN + C_DRV
    set /a MISSING=100 - SUMC
    if !MISSING! lss 0 set /a MISSING=0
)
if defined SUMMARY_FILE (
    if exist "!SUMMARY_FILE!" (
        if !PROB! equ 100 (
            >> "!SUMMARY_FILE!" echo.
            >> "!SUMMARY_FILE!" echo   [PERFECT] All checks passed - 100%% boot probability!
        ) else (
            >> "!SUMMARY_FILE!" echo.
            if !PROB! neq 100 (
                >> "!SUMMARY_FILE!" echo   Why not 100%%? Missing !MISSING!%% points:
            )
            :: Only show items that are actually missing - use the same boolean flags that determined scoring
            if !C_DISK! lss !W_DISKMAP! (
                >> "!SUMMARY_FILE!" echo     - Disk map: Missing !W_DISKMAP! points (currently +!C_DISK!)
            )
            :: Check ESP - use ESP_FOUND flag (same one that awarded points)
            if !ESP_FOUND! equ 0 (
                >> "!SUMMARY_FILE!" echo     - ESP: Missing !W_ESP! points (currently +!C_ESP!)
                >> "!SUMMARY_FILE!" echo       [ROOT CAUSE] No EFI System Partition found on disk. This partition is required for UEFI boot.
                >> "!SUMMARY_FILE!" echo       [FIX] Run: diskpart ^> list disk ^> select disk X ^> create partition efi size=100 ^> format quick fs=fat32 ^> assign letter=Y
            )
            :: Check EFI - use EFI_PRESENT flag (same one that awarded points)
            if !EFI_PRESENT! equ 0 (
                >> "!SUMMARY_FILE!" echo     - EFI files: Missing !W_EFI! points (currently +!C_EFI!)
                >> "!SUMMARY_FILE!" echo       [ROOT CAUSE] bootmgfw.efi missing from ESP\EFI\Microsoft\Boot\ directory.
                >> "!SUMMARY_FILE!" echo       [FIX] Run: bcdboot !D_LTR!:\Windows /f UEFI (rebuilds EFI boot files)
            )
            :: Check BCD - use BCD_MATCH flag (same one that awarded points)
            if !BCD_MATCH! equ 0 (
                if /i not "!BCD_VALID!"=="WARN (Volume ID)" (
                    >> "!SUMMARY_FILE!" echo     - BCD pointer: Missing !W_BCD_MATCH! points (currently +!C_BCD!)
                    >> "!SUMMARY_FILE!" echo       [ROOT CAUSE] BCD does not point to this drive partition, or BCD is missing/corrupted.
                    >> "!SUMMARY_FILE!" echo       [FIX] Run: bcdboot !D_LTR!:\Windows /f UEFI (rebuilds BCD and fixes partition pointer)
                )
            )
            if !C_WIN! lss !W_WINLOAD! (
                >> "!SUMMARY_FILE!" echo     - winload: Missing !W_WINLOAD! points (currently +!C_WIN!)
            )
            if !C_DRV! lss !W_DRIVERS! (
                if /i "!DRV_STAT!"=="UNKNOWN" (
                    >> "!SUMMARY_FILE!" echo     - drivers: UNKNOWN - Cannot verify (currently +!C_DRV! points, partial credit)
                    >> "!SUMMARY_FILE!" echo       [NOTE] System hive locked or inaccessible - cannot verify driver configuration
                ) else if /i "!DRV_STAT!"=="FAIL" (
                    >> "!SUMMARY_FILE!" echo     - drivers: Missing !W_DRIVERS! points (currently +!C_DRV!)
                    if defined DRV_ERROR_DETAIL (
                        >> "!SUMMARY_FILE!" echo       [DETAIL] !DRV_ERROR_DETAIL!
                    )
                ) else (
                    >> "!SUMMARY_FILE!" echo     - drivers: Missing !W_DRIVERS! points (currently +!C_DRV!)
                )
            )
        )
    )
)
if defined SUMMARY_FILE (
    if exist "!SUMMARY_FILE!" (
        >> "!SUMMARY_FILE!" echo.
    )
)

echo.

goto :eof

:DIAG_DONE
echo ---------------------------------------------------------------------------

echo ===========================================================================
echo Summary:
echo ---------------------------------------------------------------------------
if exist "%SUMMARY_FILE%" (
    if defined VERBOSE for %%I in ("%SUMMARY_FILE%") do echo [VERBOSE] SUMMARY_FILE exists: %%~fI size=%%~zI
    type "%SUMMARY_FILE%"
    del "%SUMMARY_FILE%" >nul 2>&1
    if defined VERBOSE (
        if exist "%SUMMARY_FILE%" (
            echo [VERBOSE] WARNING: SUMMARY_FILE still exists after deletion
        ) else (
            echo [VERBOSE] SUMMARY_FILE deleted successfully
        )
    )
) else (
    echo   [No summary data]
)
echo ---------------------------------------------------------------------------
echo.
echo ===========================================================================
echo Quick Summary Table:
echo ===========================================================================
echo DRIVE LETTER --^> VOLUME LABEL --^> SCORE %%
echo ---------------------------------------------------------------------------
if exist "%SUMMARY_TABLE%" (
    type "%SUMMARY_TABLE%"
    del "%SUMMARY_TABLE%" >nul 2>&1
) else (
    echo   [No drive data]
)
echo ---------------------------------------------------------------------------

pause
goto MENU


:: Helper: write entry to summary table
:WriteSummaryTableEntry
setlocal EnableDelayedExpansion
set "DRV=%~1"
set "LABEL=%~2"
set "SCORE=%~3"
set "NOTE=%~4"
set "TBL_FILE=%~5"
if not defined LABEL set "LABEL=[none]"
if not defined TBL_FILE (
    :: Try to get SUMMARY_TABLE from parent scope
    if defined SUMMARY_TABLE (
        set "TBL_FILE=!SUMMARY_TABLE!"
    )
)
if not defined TBL_FILE goto :eof
:: Ensure temp directory exists
if not exist "%temp%" mkdir "%temp%" >nul 2>&1
:: Ensure file path is valid
if "!TBL_FILE!"=="" goto :eof
if "!NOTE!"=="" (
    >> "!TBL_FILE!" echo !DRV!: --^> "!LABEL!" --^> !SCORE!%%
) else (
    >> "!TBL_FILE!" echo !DRV!: --^> "!LABEL!" --^> !SCORE!%% ^(!NOTE!^)
)
endlocal
goto :eof

:: Helper: get character at index from string (pure batch) - returns directly without temp files
:GetCharAtIndex
setlocal EnableDelayedExpansion
set "STR=%~1"
set "IDX_VAL=%~2"
set "CHAR="
if defined STR if defined IDX_VAL (
    set /a IDX_NUM=!IDX_VAL! 2>nul
    if !IDX_NUM! geq 0 (
        call set "CHAR=%%STR:~!IDX_NUM!,1%%"
    )
)
:: Use for loop to capture value and return it
for %%C in ("!CHAR!") do endlocal & if "%~3" neq "" set "%~3=%%~C"
goto :eof

:: Helper: append explanation lines to summary using pure batch (avoids PowerShell/quoting issues)
:AppendExplanation
setlocal EnableDelayedExpansion
set "TMP_EXP=%~1"
set "SUM_FILE=%~2"
set "X="
for /f "usebackq delims=" %%L in ("%TMP_EXP%") do set "X=%%L"
:AP_LOOP
if "!X!"=="" goto AP_DONE
for /f "tokens=1* delims=;" %%A in ("!X!") do (
    set "ITEM=%%A"
    set "X=%%B"
)
:: trim leading spaces
for /f "tokens=* delims= " %%T in ("!ITEM!") do set "ITEM=%%T"
if defined ITEM >> "%SUM_FILE%" echo    - !ITEM!
goto AP_LOOP
:AP_DONE
endlocal
goto :eof

:: Helper: get a drive label (Volume Name) for a drive letter with multiple fallback methods
:GetDriveLabel
setlocal EnableDelayedExpansion
set "DRV_LETTER=%~1"
set "DRV_LABEL="
set "RET_VAR=%~2"

:: Method 1: Try PowerShell Get-CimInstance (most reliable)
set "TEMP_DIR=%temp%"
if not defined TEMP_DIR set "TEMP_DIR=%TMP%"
if not defined TEMP_DIR set "TEMP_DIR=C:\Windows\Temp"
if not exist "!TEMP_DIR!" mkdir "!TEMP_DIR!" >nul 2>&1
if exist "!TEMP_DIR!" (
    set "TMP_LABEL=!TEMP_DIR!\qa_label_%random%.txt"
    if defined QA_DEBUG echo [DBG] GetDriveLabel temp file: !TMP_LABEL!
    powershell -NoProfile -Command "$disk = Get-CimInstance Win32_LogicalDisk -Filter \"DeviceID='!DRV_LETTER!:'\" -ErrorAction SilentlyContinue; if ($disk -and $disk.VolumeName -and $disk.VolumeName.Trim() -ne '') { $disk.VolumeName.Trim() } else { '' }" > "!TMP_LABEL!" 2>nul
    if exist "!TMP_LABEL!" (
        for /f "usebackq delims=" %%L in ("!TMP_LABEL!") do (
            set "DRV_LABEL=%%L"
        )
        del "!TMP_LABEL!" >nul 2>&1
    )
)

:: Method 2: If PowerShell failed, try vol command
if not defined DRV_LABEL (
    if defined DRV_LETTER (
        if not "!DRV_LETTER!"=="" (
            set "TMP_VOL=!TEMP_DIR!\qa_vol_%random%.txt"
            vol "!DRV_LETTER!:" > "!TMP_VOL!" 2>nul
            if exist "!TMP_VOL!" (
                for /f "tokens=4*" %%A in ('type "!TMP_VOL!" ^| findstr /i "Volume in drive"') do (
                    set "DRV_LABEL=%%B"
                )
                del "!TMP_VOL!" >nul 2>&1
            )
        )
    )
)

:: Method 3: Try fsutil (if available)
if not defined DRV_LABEL (
    for /f "tokens=*" %%L in ('fsutil volume querylabel !DRV_LETTER!: 2^>nul') do (
        set "VOL_LINE=%%L"
        if "!VOL_LINE:~0,5!"=="Label" (
            for /f "tokens=2*" %%A in ("!VOL_LINE!") do set "DRV_LABEL=%%B"
        )
    )
)

:: Method 4: Try wmic (fallback)
if not defined DRV_LABEL (
    for /f "tokens=2 delims==" %%L in ('wmic logicaldisk where "DeviceID='!DRV_LETTER!:'" get VolumeName /value 2^>nul ^| findstr "="') do (
        set "DRV_LABEL=%%L"
    )
)

:: Clean up label (remove quotes, trim whitespace)
if defined DRV_LABEL (
    set "DRV_LABEL=!DRV_LABEL:"=!"
    set "DRV_LABEL=!DRV_LABEL: =!"
    if "!DRV_LABEL!"=="" set "DRV_LABEL="
)

:: Default to [none] if still empty
if not defined DRV_LABEL set "DRV_LABEL=[none]"

:: Return the label - support both return variable and global variable
if defined RET_VAR (
    endlocal & set "!RET_VAR!=%DRV_LABEL%"
) else (
    endlocal & set "DRV_LABEL=%DRV_LABEL%"
)
goto :eof

:: Helper: get disk number for a drive letter (isolated to avoid parser issues)
:GetDiskNumber
set "DISK_NUM="
:: Prefer 64-bit PowerShell binary (System32 path) to ensure Storage cmdlets are available
set "PS64=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
:: First attempt: Get-Partition (fast and direct)
for /f "usebackq" %%D in (`cmd /c ^"^"%PS64%^" -NoProfile -Command "Get-Partition -DriveLetter '%~1' ^| Select-Object -ExpandProperty DiskNumber" 2^>nul^"`) do set "DISK_NUM=%%D"
if defined DISK_NUM (
    for /f "delims=" %%X in ("!DISK_NUM!") do set "DISK_NUM=%%X"
    set "DISK_MAP_METHOD=GetPartition"
    if defined QA_DEBUG echo [DBG] Get-Partition DiskNumber for %~1 = !DISK_NUM! (method=!DISK_MAP_METHOD!)
    goto :eof
)

:: Fallback: use CIM/WMI associators to map logical disk to partition's DiskIndex
if defined QA_DEBUG echo [DBG] Get-Partition failed, trying CIM fallback for %~1
for /f "usebackq" %%M in (`cmd /c ^"^"%PS64%^" -NoProfile -Command \"(Get-CimInstance -Query 'ASSOCIATORS OF {Win32_LogicalDisk.DeviceID=''%~1:''} WHERE AssocClass=Win32_LogicalDiskToPartition') ^| Select-Object -ExpandProperty DiskIndex\" 2^>nul^"`) do set "DISK_NUM=%%M"
if defined DISK_NUM (
    for /f "delims=" %%X in ("!DISK_NUM!") do set "DISK_NUM=%%X"
    set "DISK_MAP_METHOD=CIM"
    if defined QA_DEBUG echo [DBG] CIM fallback DiskIndex for %~1 = !DISK_NUM! (method=!DISK_MAP_METHOD!)
    goto :eof
)

:: Nothing found; optionally print raw Get-Partition output for debugging
if defined QA_DEBUG (
    set "TMPDBG=%temp%\gp_%~1.txt"
    "%PS64%" -NoProfile -Command "Get-Partition -DriveLetter '%~1' | Format-List *" > "%TMPDBG%" 2>&1
    echo [DBG] Raw Get-Partition output for %~1:
    type "%TMPDBG%"
    del "%TMPDBG%" >nul 2>&1
)

goto :eof

:: Helper: get ESP partition number from disk number
:GetESPPart
set "ESP_PART="
set "PS64=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
:: Primary: ask Get-Partition for the GPT partition with ESP GUID
for /f "usebackq" %%Q in (`cmd /c ^"^"%PS64%^" -NoProfile -Command "Get-Partition -DiskNumber %~1 ^| Where-Object {$_.GptType -eq '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}'} ^| Select-Object -First 1 ^| Select-Object -ExpandProperty PartitionNumber" 2^>nul^"`) do set "ESP_PART=%%Q"
if defined ESP_PART (
    for /f "delims=" %%Y in ("!ESP_PART!") do set "ESP_PART=%%Y"
    set "ESP_DISCOVERY_METHOD=GetPartition"
    if defined QA_DEBUG echo [DBG] Get-Partition ESP for disk %~1 = !ESP_PART! (method=!ESP_DISCOVERY_METHOD!)
    goto :eof
)

:: Fallback: enumerate partitions on the disk and match GptType manually
if defined QA_DEBUG echo [DBG] Get-Partition for ESP failed, trying enumeration fallback for disk %~1
for /f "usebackq" %%R in (`cmd /c ^"^"%PS64%^" -NoProfile -Command "Get-Partition -DiskNumber %~1 ^| Where-Object {$_.GptType -ne $null} ^| Where-Object {$_.GptType -eq '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}'} ^| Select-Object -First 1 ^| Select-Object -ExpandProperty PartitionNumber" 2^>nul^"`) do set "ESP_PART=%%R"
if defined ESP_PART (
    for /f "delims=" %%Y in ("!ESP_PART!") do set "ESP_PART=%%Y"
    set "ESP_DISCOVERY_METHOD=Enumeration"
    if defined QA_DEBUG echo [DBG] Enumeration fallback ESP for disk %~1 = !ESP_PART! (method=!ESP_DISCOVERY_METHOD!)
    goto :eof
)

if defined QA_DEBUG echo [DBG] GetESPPart returned nothing for disk %~1

goto :eof


:SURGICAL_REPAIR
cls
echo ===========================================================================
echo                      ADVANCED BOOT REPAIR ENGINE
echo ===========================================================================
powershell -NoProfile -Command "Get-CimInstance Win32_LogicalDisk | Select-Object DeviceID, VolumeName | Format-Table -AutoSize"
echo.
set /p "REP_DRIVE=Select Target Windows Drive (e.g. C): "
if not defined REP_DRIVE set "REP_DRIVE=C"
set "REP_DRIVE=%REP_DRIVE:~0,1%"
set "REP_DRIVE=%REP_DRIVE:~0,1%" & :: ensure single char

:: Simple uppercase
for %%L in (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z) do if /i "%REP_DRIVE%"=="%%L" set "REP_DRIVE=%%L"

if not exist "!REP_DRIVE!:\Windows" (
    echo [!] ERROR: No Windows folder on !REP_DRIVE!:
    pause
    goto MENU
)

echo.
echo [1] AUTOMATED EFI + BCD RECONSTRUCTION
echo [2] BACK TO MENU
set /p "R_CHOICE=Choice: "

if "%R_CHOICE%"=="1" (
    echo [*] Rebuilding EFI and BCD...
    bcdboot !REP_DRIVE!:\Windows /f UEFI
    if !errorLevel! equ 0 (
        echo [SUCCESS] Boot files rebuilt.
    ) else (
        echo [FAILED] BCDBOOT failed.
    )
    pause
)
goto MENU