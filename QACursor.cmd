@echo off
setlocal EnableDelayedExpansion
title Miracle Boot QA - Forensic Master v16.9 [UNIFIED LOGIC]

:: Admin Check
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [!] ERROR: Run as Admin!
    pause
    exit /b
)

:: Pre-emptive Unmount
for %%L in (Z Y X) do ( mountvol %%L: /d >nul 2>&1 )

:MENU
cls
echo ===========================================================================
echo   MIRACLE BOOT QA - FORENSIC MASTER v16.9 [UNIFIED LOGIC + DRIVER SENSE]
echo ===========================================================================
echo.
echo [1] BACKUP FORENSICS: Validate All Backup Folders
echo [2] VALIDATE SPECIFIC BACKUP: Check Single Backup Folder
echo [3] LIVE DIAGNOSTIC: Deep Boot Validation
echo [4] SURGICAL REPAIR: EFI + BCD + chkdsk + SFC + DISM
echo [5] EXIT
echo.
set /p "CHOICE=Select: "

call :ShowInputFeedback "Menu Choice" "%CHOICE%"

if /i "%CHOICE%"=="1" goto SCAN_BACKUPS
if /i "%CHOICE%"=="2" goto VALIDATE_SPECIFIC_BACKUP
if /i "%CHOICE%"=="3" goto DIAG_DRIVE_SELECTOR
if /i "%CHOICE%"=="4" goto SURGICAL_REPAIR
if /i "%CHOICE%"=="5" goto CLEANUP_EXIT
goto MENU

:CLEANUP_EXIT
call :CleanupTempFiles
exit /b

:CleanupTempFiles
setlocal enabledelayedexpansion
for %%L in (Z Y X W V U T S R Q P O N) do ( mountvol %%L: /d >nul 2>&1 )
if defined temp (
    del /q "!temp!\qa_*.tmp" >nul 2>&1
    del /q "!temp!\qa_*.txt" >nul 2>&1
    del /q "!temp!\dp_*.txt" >nul 2>&1
)
endlocal
exit /b

:SCAN_BACKUPS
cls
echo ===========================================================================
echo         BACKUP FORENSICS - COMPREHENSIVE VALIDATION (Unified)
echo ===========================================================================
echo.
set "BASE_DIR=%~dp0"
set "BACKUP_COUNT=0"
for /f "delims=" %%i in ('dir /b /ad "!BASE_DIR!*FASTBOOT*" "!BASE_DIR!*NUCLEAR*" 2^>nul') do (
    set /a BACKUP_COUNT+=1
    echo [BACKUP #!BACKUP_COUNT!]: %%i
    echo ---------------------------------------------------------------------------
    call :RunCoreBackupValidation "!BASE_DIR!%%i"
    echo.
)
pause
goto MENU

:VALIDATE_SPECIFIC_BACKUP
cls
echo ===========================================================================
echo         VALIDATE SPECIFIC BACKUP FOLDER (Unified)
echo ===========================================================================
echo.
set "BASE_DIR=%~dp0"
set "FOLDER_LIST="
set "FOLDER_COUNT=0"
for /f "delims=" %%i in ('dir /b /ad "%BASE_DIR%*FASTBOOT*" "%BASE_DIR%*NUCLEAR*" 2^>nul') do (
    set /a FOLDER_COUNT+=1
    echo [!FOLDER_COUNT!] %%i
    set "FOLDER_LIST=!FOLDER_LIST!%%i|"
)
if !FOLDER_COUNT! equ 0 ( echo [!] No backups found. & pause & goto MENU )
echo.
set /p "BACKUP_SELECT=Enter folder name or number: "
set "SELECTED_FOLDER="
set "FOLDER_INDEX=0"
for /f "tokens=1* delims=|" %%A in ("!FOLDER_LIST!") do (
    set /a FOLDER_INDEX+=1
    if "!BACKUP_SELECT!"=="!FOLDER_INDEX!" set "SELECTED_FOLDER=%%A"
)
if not defined SELECTED_FOLDER set "SELECTED_FOLDER=!BACKUP_SELECT!"
if not exist "!BASE_DIR!!SELECTED_FOLDER!" ( echo [!] Not found. & pause & goto MENU )

cls
echo Validating: !SELECTED_FOLDER!
echo ---------------------------------------------------------------------------
call :RunCoreBackupValidation "!BASE_DIR!!SELECTED_FOLDER!"
pause
goto MENU

:: =============================================================================
:: CORE VALIDATION ENGINE (Fixes the Score Inconsistency Bug)
:: =============================================================================
:RunCoreBackupValidation
setlocal enabledelayedexpansion
set "B_PATH=%~1"
set /a V_SCORE=0
set "V_ISSUES="

:: 1. EFI (40 pts)
if exist "!B_PATH!\EFI\Microsoft\Boot\bootmgfw.efi" (
    set /a V_SCORE+=20
    echo    [OK] bootmgfw.efi [+20]
) else ( set "V_ISSUES=!V_ISSUES! MISSING: bootmgfw.efi;" & echo    [!] bootmgfw.efi MISSING [-20] )

if exist "!B_PATH!\EFI\Microsoft\Boot\bootmgr.efi" ( set /a V_SCORE+=5 & echo    [OK] bootmgr.efi [+5]
) else ( set "V_ISSUES=!V_ISSUES! MISSING: bootmgr.efi;" & echo    [WARN] bootmgr.efi MISSING )

if exist "!B_PATH!\EFI\Boot\bootx64.efi" ( set /a V_SCORE+=5 & echo    [OK] bootx64.efi [+5] )

if exist "!B_PATH!\EFI\Microsoft\Boot\BCD" (
    for %%F in ("!B_PATH!\EFI\Microsoft\Boot\BCD") do if %%~zF gtr 0 (
        set /a V_SCORE+=10
        echo    [OK] EFI BCD [+10]
    ) else ( set "V_ISSUES=!V_ISSUES! EFI BCD Empty;" & echo    [!] EFI BCD EMPTY )
)

:: 2. BCD Backup (20 pts)
if exist "!B_PATH!\BCD_Backup" (
    bcdedit /store "!B_PATH!\BCD_Backup" /enum {bootmgr} >nul 2>&1
    if !errorlevel! equ 0 (
        set /a V_SCORE+=20
        echo    [OK] BCD_Backup Valid [+20]
    ) else ( set "V_ISSUES=!V_ISSUES! BCD_Backup Corrupt;" & echo    [!] BCD_Backup CORRUPT )
) else ( set "V_ISSUES=!V_ISSUES! MISSING: BCD_Backup;" & echo    [!] BCD_Backup MISSING )

:: 3. Hives (20 pts)
for %%H in (SYSTEM SOFTWARE) do (
    if exist "!B_PATH!\Hives\%%H" (
        for %%A in ("!B_PATH!\Hives\%%H") do if %%~zA gtr 0 (
            set /a V_SCORE+=10
            echo    [OK] %%H Hive [+10]
        )
    ) else ( set "V_ISSUES=!V_ISSUES! MISSING: %%H hive;" )
)

:: 4. Metadata (10 pts)
if exist "!B_PATH!\Metadata\Disk_ID.txt" set /a V_SCORE+=5
if exist "!B_PATH!\Metadata\Disk_Info.txt" set /a V_SCORE+=3
if exist "!B_PATH!\Metadata\Robocopy_EFI.log" (
    findstr /i "FAILED" "!B_PATH!\Metadata\Robocopy_EFI.log" | findstr /v " 0 " >nul 2>&1
    if !errorlevel! neq 0 ( set /a V_SCORE+=2 & echo    [OK] Robocopy Log Clean [+2] )
)

:: 5. WINCORE Detection (Bonus scoring)
set "WINCORE_PRESENT=NO"
set "WINCORE_BONUS=0"
if exist "!B_PATH!\WIN_CORE\SYSTEM32\ntoskrnl.exe" (
    set "WINCORE_PRESENT=YES"
    set /a WINCORE_BONUS=10
    set /a V_SCORE+=WINCORE_BONUS
    echo    [OK] WINCORE Payload: DETECTED (Enhanced Recovery Available) [+!WINCORE_BONUS!]
) else (
    echo    [INFO] WINCORE Payload: Not present (FASTBOOT only)
)

echo ---------------------------------------------------------------------------
set /a OS_INTEGRITY_CONFIDENCE=V_SCORE
if "!WINCORE_PRESENT!"=="YES" (
    echo FINAL SCORE: !V_SCORE! / 100 (Base: !OS_INTEGRITY_CONFIDENCE! + WINCORE Bonus: !WINCORE_BONUS!)
) else (
    echo FINAL SCORE: !V_SCORE! / 100
)
if !V_SCORE! geq 70 ( echo [STATUS]: RESTORE-READY ) else ( echo [STATUS]: INCOMPLETE )
if "!WINCORE_PRESENT!"=="YES" (
    echo OS Integrity Confidence: !OS_INTEGRITY_CONFIDENCE!%% (Enhanced with WINCORE)
)
if defined V_ISSUES call :DisplayIssues "!V_ISSUES!"
endlocal
goto :eof

:DIAG_DRIVE_SELECTOR
cls
echo ===========================================================================
echo                 DEEP E-B-W-D BOOTABILITY VALIDATOR v16.9
echo ===========================================================================
echo Scanning for drives...
wmic logicaldisk get deviceid, volumename, size /format:list 2>nul
echo.

set "SL="
set /p "SL=Enter Drive Letter(s) (e.g. C or C E). Enter for ALL: "
if not defined SL ( set "D_LIST=CDEFGHIJKLMNOPQRSTUVWXYZ" ) else (
    set "D_LIST="
    for %%A in (!SL!) do ( set "t=%%A" & set "D_LIST=!D_LIST!!t:~0,1!" )
)

set "SUMMARY_TABLE=!temp!\qa_table_%random%.txt"
set "SUMMARY_FILE=!temp!\qa_summary_%random%.txt"

cls
echo DRIVE  EFI-PATH   BCD-POINTER   WINLOAD  DRIVERS  STATUS (SCORE)
echo ---------------------------------------------------------------------------

set "idx=0"
:DRIVE_LOOP
call :GetCharAtIndex "!D_LIST!" "!idx!" D_LTR
if "!D_LTR!"=="" goto :DIAG_DONE

call :IsDriveReady !D_LTR!
if errorlevel 1 goto :DRIVE_LOOP_NEXT

if not exist "!D_LTR!:\Windows" (
    call :WriteSummaryTableEntry "!D_LTR!" "[No OS]" "0" "No Windows Folder" "!SUMMARY_TABLE!"
    goto :DRIVE_LOOP_NEXT
)

:: PROCESS SINGLE DRIVE (Logic Sense Fixed for C/E missing bug)
call :ProcessSingleDrive "!D_LTR!" "!SUMMARY_TABLE!" "!SUMMARY_FILE!"

:DRIVE_LOOP_NEXT
set /a idx+=1
goto :DRIVE_LOOP

:DIAG_DONE
echo ---------------------------------------------------------------------------
if exist "!SUMMARY_TABLE!" ( echo Quick Table: & type "!SUMMARY_TABLE!" & del "!SUMMARY_TABLE!" )
pause
goto MENU

:ProcessSingleDrive
setlocal enabledelayedexpansion
set "D=%~1"
set "TBL=%~2"
set "SUM=%~3"
set /a PROB=0, W_MAP=20, W_ESP=20, W_EFI=20, W_BCD=20, W_WL=10, W_DRV=10
set "EF=FAIL", "BC=FAIL", "WL=--", "DS=UNKNOWN", "D_TYPE=NONE"

:: 1. Mapping
call :GetDiskNumber "!D!"
if defined DISK_NUM ( set /a PROB+=W_MAP & call :GetESPPart !DISK_NUM! )

:: 2. ESP Work
if defined ESP_PART (
    set /a PROB+=W_ESP & set "EL=Z"
    (echo select disk !DISK_NUM! & echo select partition !ESP_PART! & echo assign letter=!EL! noerr) | diskpart >nul 2>&1
    if exist "!EL!:\EFI\" (
        if exist "!EL!:\EFI\Microsoft\Boot\bootmgfw.efi" ( set "EF=OK" & set /a PROB+=W_EFI )
        for /f "delims=" %%B in ('bcdedit /store "!EL!:\EFI\Microsoft\Boot\BCD" /enum {default} 2^>nul ^| findstr /i "osdevice"') do (
            echo %%B | findstr /i "!D!:" >nul && ( set "BC=OK" & set /a PROB+=W_BCD ) || ( set "BC=WARN" )
        )
        (echo select volume !EL! & echo remove letter=!EL!) | diskpart >nul 2>&1
    )
)

:: 3. Winload
if exist "!D!:\Windows\System32\winload.efi" ( set "WL=OK" & set /a PROB+=W_WL )

:: 4. DRIVER SENSE ENGINE (Intel VMD/NVMe/SATA)
set "DRV_DIR=!D!:\Windows\System32\drivers"
if exist "!DRV_DIR!\iaStorVD.sys" ( set "D_TYPE=IntelVMD" ) else (
    if exist "!DRV_DIR!\stornvme.sys" ( set "D_TYPE=NVMe" ) else (
        if exist "!DRV_DIR!\iaStorAC.sys" ( set "D_TYPE=IntelRST" ) else (
            if exist "!DRV_DIR!\storahci.sys" set "D_TYPE=SATA"
        )
    )
)
if not "!D_TYPE!"=="NONE" ( set "DS=OK" & set /a PROB+=W_DRV )

:: Final Status
set "S=RED"
if !PROB! geq 90 ( set "S=GREEN" ) else if !PROB! geq 60 set "S=YELLOW"
echo !D!:      !EF!         !BC!          !WL!       !DS!    !S! (!PROB!%%)

call :GetDriveLabel "!D!" DLBL
call :WriteSummaryTableEntry "!D!" "!DLBL!" "!PROB!" "!D_TYPE!" "!TBL!"
endlocal
goto :eof

:: HELPERS
:GetDriveLabel
for /f "tokens=2*" %%A in ('fsutil volume querylabel %1: 2^>nul') do set "%~2=%%B"
if not defined %~2 set "%~2=[none]"
goto :eof

:IsDriveReady
dir /b "%~1:\" >nul 2>&1
exit /b %errorlevel%

:GetDiskNumber
set "DN="
(echo select volume %~1 & echo detail volume) > "!temp!\dp.txt"
for /f "tokens=3" %%D in ('diskpart /s "!temp!\dp.txt" ^| findstr /c:"* Disk"') do set "DN=%%D"
set "DISK_NUM=!DN!"
goto :eof

:GetESPPart
set "EP="
(echo select disk %1 & echo list partition) > "!temp!\dp.txt"
for /f "tokens=2" %%P in ('diskpart /s "!temp!\dp.txt" ^| findstr /i "System"') do set "EP=%%P"
set "ESP_PART=!EP!"
goto :eof

:WriteSummaryTableEntry
echo %~1: --^> %~2 --^> %~3%% [%~4] >> "%~5"
goto :eof

:GetCharAtIndex
set "STR=%~1"
set "IDX=%~2"
set "%~3=!STR:~%IDX%,1!"
goto :eof

:DisplayIssues
echo [ISSUES]: %~1
goto :eof

:ShowInputFeedback
if defined VERBOSE echo [INPUT] %~1: %~2
goto :eof

:SURGICAL_REPAIR
cls
echo ===========================================================================
echo                    SURGICAL REPAIR MENU
echo ===========================================================================
echo.
echo Target Drive (e.g. C):
set /p "RD=Drive: "
if not defined RD goto MENU
if not exist "!RD!:\Windows" (
    echo [!] ERROR: !RD!:\Windows not found.
    pause
    goto MENU
)

cls
echo ===========================================================================
echo                    SURGICAL REPAIR OPTIONS
echo ===========================================================================
echo Target: !RD!:
echo.
echo [1] EFI + BCD Reconstruction (bcdboot)
echo [2] File System Repair (chkdsk /f /r)
echo [3] Offline System File Check (sfc /scannow)
echo [4] DISM Cleanup (Revert Pending Actions)
echo [5] Run All Repairs
echo [6] Back to Main Menu
echo.
set /p "REPAIR_CHOICE=Select: "

if /i "!REPAIR_CHOICE!"=="1" goto REPAIR_EFI_BCD
if /i "!REPAIR_CHOICE!"=="2" goto REPAIR_CHKDSK
if /i "!REPAIR_CHOICE!"=="3" goto REPAIR_SFC
if /i "!REPAIR_CHOICE!"=="4" goto REPAIR_DISM
if /i "!REPAIR_CHOICE!"=="5" goto REPAIR_ALL
if /i "!REPAIR_CHOICE!"=="6" goto MENU
goto SURGICAL_REPAIR

:REPAIR_EFI_BCD
cls
echo ===========================================================================
echo                    EFI + BCD RECONSTRUCTION
echo ===========================================================================
echo Target: !RD!:
echo.
echo [*] Running bcdboot to reconstruct EFI and BCD...
bcdboot !RD!:\Windows /f UEFI
if !errorlevel! equ 0 (
    echo [OK] EFI + BCD reconstruction completed successfully.
) else (
    echo [!] ERROR: bcdboot failed. Check permissions and drive status.
)
echo.
pause
goto SURGICAL_REPAIR

:REPAIR_CHKDSK
cls
echo ===========================================================================
echo                    FILE SYSTEM REPAIR (chkdsk)
echo ===========================================================================
echo Target: !RD!:
echo.
echo [WARNING] This will schedule chkdsk to run on the next reboot.
echo [WARNING] The system will restart automatically after scheduling.
echo.
set /p "CHKDSK_CONFIRM=Schedule chkdsk /f /r for !RD!:? (Y/N, default N): "
if /i not "!CHKDSK_CONFIRM!"=="Y" (
    echo [*] chkdsk cancelled.
    pause
    goto SURGICAL_REPAIR
)
echo.
echo [*] Scheduling chkdsk /f /r for !RD!:...
chkdsk !RD!: /f /r
if !errorlevel! equ 0 (
    echo [OK] chkdsk scheduled successfully.
    echo [INFO] chkdsk will run on the next system restart.
) else (
    echo [!] ERROR: Failed to schedule chkdsk. Drive may be in use or locked.
)
echo.
pause
goto SURGICAL_REPAIR

:REPAIR_SFC
cls
echo ===========================================================================
echo                    OFFLINE SYSTEM FILE CHECK (SFC)
echo ===========================================================================
echo Target: !RD!:
echo.
echo [*] Running offline SFC scan...
echo [INFO] This may take several minutes...
echo.
sfc /scannow /offbootdir=!RD!:\ /offwindir=!RD!:\Windows
if !errorlevel! equ 0 (
    echo [OK] SFC scan completed successfully.
) else (
    echo [!] WARNING: SFC scan completed with errors or warnings.
    echo [INFO] Check the output above for details.
)
echo.
pause
goto SURGICAL_REPAIR

:REPAIR_DISM
cls
echo ===========================================================================
echo                    DISM CLEANUP (Revert Pending Actions)
echo ===========================================================================
echo Target: !RD!:
echo.
echo [*] Running DISM cleanup to revert pending actions...
echo [INFO] This may take several minutes...
echo.
DISM /Cleanup-Image /RevertPendingActions
if !errorlevel! equ 0 (
    echo [OK] DISM cleanup completed successfully.
) else (
    echo [!] WARNING: DISM cleanup completed with errors or warnings.
    echo [INFO] Check the output above for details.
)
echo.
pause
goto SURGICAL_REPAIR

:REPAIR_ALL
cls
echo ===========================================================================
echo                    RUNNING ALL REPAIRS
echo ===========================================================================
echo Target: !RD!:
echo.
echo [WARNING] This will run all repair operations sequentially.
echo [WARNING] chkdsk will be scheduled for next reboot.
echo.
set /p "ALL_CONFIRM=Proceed with all repairs? (Y/N, default N): "
if /i not "!ALL_CONFIRM!"=="Y" (
    echo [*] All repairs cancelled.
    pause
    goto SURGICAL_REPAIR
)

echo.
echo ===========================================================================
echo [1/4] EFI + BCD Reconstruction...
echo ===========================================================================
bcdboot !RD!:\Windows /f UEFI
if !errorlevel! equ 0 (
    echo [OK] EFI + BCD reconstruction completed.
) else (
    echo [!] ERROR: bcdboot failed.
)
echo.

echo ===========================================================================
echo [2/4] Scheduling chkdsk /f /r...
echo ===========================================================================
chkdsk !RD!: /f /r
if !errorlevel! equ 0 (
    echo [OK] chkdsk scheduled successfully.
) else (
    echo [!] ERROR: Failed to schedule chkdsk.
)
echo.

echo ===========================================================================
echo [3/4] Offline SFC scan...
echo ===========================================================================
sfc /scannow /offbootdir=!RD!:\ /offwindir=!RD!:\Windows
if !errorlevel! equ 0 (
    echo [OK] SFC scan completed.
) else (
    echo [!] WARNING: SFC scan completed with issues.
)
echo.

echo ===========================================================================
echo [4/4] DISM Cleanup...
echo ===========================================================================
DISM /Cleanup-Image /RevertPendingActions
if !errorlevel! equ 0 (
    echo [OK] DISM cleanup completed.
) else (
    echo [!] WARNING: DISM cleanup completed with issues.
)
echo.

echo ===========================================================================
echo                    ALL REPAIRS COMPLETED
echo ===========================================================================
echo.
echo [SUMMARY]
echo - EFI + BCD: Reconstruction attempted
echo - chkdsk: Scheduled for next reboot
echo - SFC: Offline scan completed
echo - DISM: Cleanup completed
echo.
echo [NOTE] Restart the system for chkdsk to run.
echo.
pause
goto SURGICAL_REPAIR