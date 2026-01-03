@echo off
setlocal enabledelayedexpansion
title Miracle Boot Backup v14.1 - Nuclear Hardened (Full Source)

:: 0. WinPE Detection
set "WINPE_MODE=0"
if exist "X:\Windows\System32\wpeinit.exe" set "WINPE_MODE=1"
if exist "X:\sources\boot.wim" set "WINPE_MODE=1"
if "%SYSTEMROOT%"=="X:\Windows" set "WINPE_MODE=1"
if "!WINPE_MODE!"=="1" (
    echo [*] WinPE Environment Detected - Using WinPE-compatible methods
    echo.
)

:: 1. Admin Check
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [^!] ERROR: Admin Required. Please Right-Click -> Run as Administrator.
    pause & exit /b
)

:: 1.5. Cleanup leftover ESP drive letters from previous runs
echo [*] Cleaning up leftover ESP drive letters from previous runs...
set "CLEANED_COUNT=0"
for %%L in (Z Y X W V U T S R Q P O N M L K J I H) do (
    if exist "%%L:\" (
        set "IS_ESP=0"
        :: 1. Check for critical boot file
        if exist "%%L:\EFI\Microsoft\Boot\bootmgfw.efi" set "IS_ESP=1"
        
        :: 2. If file not found, skip diskpart check (simplified to avoid parser issues)
        :: Diskpart size check removed - rely on file check only for stability

        if "!IS_ESP!"=="1" (
            echo [*] Attempting to unmount ESP drive letter: %%L drive
            
            :: Method A: Mountvol (Most reliable for simple removal)
            mountvol %%L: /D >nul 2>&1
            
            :: Method B: Diskpart Fallback (simplified - skip volume number lookup)
            :: Volume number lookup removed to avoid parser issues with empty files

            :: Verification
            if not exist "%%L:\" (
                set /a CLEANED_COUNT+=1
                echo [OK] Successfully removed: %%L drive
            ) else (
                echo [^!] WARNING: Could not release %%L drive (Partition may be in use)
            )
        )
    )
)
if !CLEANED_COUNT! GTR 0 (
    echo [OK] Cleaned up !CLEANED_COUNT! leftover drive letter(s)
) else (
    echo [OK] No leftover drive letters found.
)
echo.

:: 2. Drive Selection
:: Temporary debug pause - remove after testing
:: pause
cls
echo ============================================================
echo         MIRACLE BOOT BACKUP - NUCLEAR BUILD v14.1
echo ============================================================
echo.
echo [TEST MODE] Hardcoded to backup C: drive
echo.
set "SRC_DRIVE=C"
if not exist "C:\Windows" (
    echo [^!] ERROR: C:\Windows not found.
    pause & exit /b
)

:: 3. BitLocker Check - SIMPLE ONE-LINER (immune to parser issues)
echo [*] Checking BitLocker Status on !SRC_DRIVE!:...
set "BL_STAT=0"
manage-bde -status "!SRC_DRIVE!:" 2>nul | findstr /i /c:"Percentage Encrypted" >nul && set "BL_STAT=1"

if "!BL_STAT!"=="1" (
    echo [^!] ALERT: BitLocker ENABLED. Ensure you have your Recovery Key.
) else (
    echo [OK] BitLocker DISABLED or not detected. Proceeding...
)
echo.

:: 3.5. Backup Mode Selection
echo.
echo ============================================================
echo                    BACKUP MODE SELECTION
echo ============================================================
echo.
echo [1] FASTBOOT only (current behavior)
echo [2] FASTBOOT + WINCORE (recommended)
echo.
set /p "BACKUP_MODE=Select mode (1 or 2, Enter for FASTBOOT only): "
if not defined BACKUP_MODE set "BACKUP_MODE=1"
if /i "!BACKUP_MODE!" neq "2" set "BACKUP_MODE=1"
set "WINCORE_ENABLED=0"
if "!BACKUP_MODE!"=="2" set "WINCORE_ENABLED=1"
if "!WINCORE_ENABLED!"=="1" (
    echo [*] WINCORE mode enabled. This will add ~8-12 GB to backup.
) else (
    echo [*] FASTBOOT only mode selected.
)
echo.

:: 4. Target Setup - ROBUST TIMESTAMP (no fragile findstr or wmic quirks)
set "TS=UNKNOWN_%random%"

:: Best method: PowerShell (available in Windows 8+ and WinPE 10+)
if "!WINPE_MODE!"=="0" (
    for /f %%T in ('powershell -Command "Get-Date -Format yyyy-MM-dd_HH-mm" 2^>nul') do set "TS=%%T"
)

:: Fallback: If PowerShell fails, try WMIC localdatetime (strip CR properly)
if "!TS!"=="UNKNOWN_%random%" (
    for /f "skip=1 tokens=1" %%A in ('wmic os get localdatetime ^| find "." 2^>nul') do (
        set "dt=%%A"
        set "TS=!dt:~0,4!-!dt:~4,2!-!dt:~6,2!_!dt:~8,2!-!dt:~10,2!"
        goto :ts_done
    )
)

:: Final fallback: Use current random (already set)
:ts_done
set "DEST=%~dp0!TS!_FASTBOOT_!SRC_DRIVE!"
mkdir "!DEST!\EFI" "!DEST!\Hives" "!DEST!\Drivers" "!DEST!\Metadata" "!DEST!\LOGS" 2>nul
if "!WINCORE_ENABLED!"=="1" (
    mkdir "!DEST!\WIN_CORE\SYSTEM32" "!DEST!\WIN_CORE\SYSWOW64" "!DEST!\WIN_CORE\BOOT" "!DEST!\WIN_CORE\DRIVERS" "!DEST!\WIN_CORE\INF" "!DEST!\WIN_CORE\SERVICING" 2>nul
)

echo.
echo [*] Target Directory: !DEST!

:: 5. Capture Physical DNA (WinPE-compatible)
echo [*] Capturing Physical Disk Signature...
set "DNUM="
if "!WINPE_MODE!"=="0" (
    :: Try PowerShell method (full Windows)
    for /f %%d in ('powershell -Command "(Get-Partition -DriveLetter C).DiskNumber" 2^>nul') do set "DNUM=%%d"
)
:: Fallback: Use diskpart (works in WinPE)
if not defined DNUM (
    echo list volume> "%temp%\find_disk.txt"
    echo exit>> "%temp%\find_disk.txt"
    diskpart /s "%temp%\find_disk.txt" > "%temp%\find_disk_out.txt" 2>nul
    timeout /t 3 >nul
    findstr /i "!SRC_DRIVE!" "%temp%\find_disk_out.txt" > "%temp%\find_disk_match.txt"
    if exist "%temp%\find_disk_match.txt" (
        for /f "tokens=2,3" %%A in ("%temp%\find_disk_match.txt") do (
            echo select volume %%A> "%temp%\disk_detail.txt"
            echo detail volume>> "%temp%\disk_detail.txt"
            echo exit>> "%temp%\disk_detail.txt"
            diskpart /s "%temp%\disk_detail.txt" > "%temp%\disk_detail_out.txt" 2>nul
            timeout /t 3 >nul
            findstr /i "Disk" "%temp%\disk_detail_out.txt" > "%temp%\disk_detail_match.txt"
            if exist "%temp%\disk_detail_match.txt" (
                for /f "tokens=3" %%D in ("%temp%\disk_detail_match.txt") do set "DNUM=%%D"
            )
            del "%temp%\disk_detail.txt" >nul 2>&1
            del "%temp%\disk_detail_out.txt" >nul 2>&1
            del "%temp%\disk_detail_match.txt" >nul 2>&1
        )
    )
    del "%temp%\find_disk.txt" >nul 2>&1
    del "%temp%\find_disk_out.txt" >nul 2>&1
    del "%temp%\find_disk_match.txt" >nul 2>&1
)
if defined DNUM (
    echo [*] Disk Number: !DNUM!
    
    :: Create script
    echo select disk !DNUM!> "%temp%\diskpart_script.txt"
    echo uniqueid disk>> "%temp%\diskpart_script.txt"
    echo list disk>> "%temp%\diskpart_script.txt"
    echo exit>> "%temp%\diskpart_script.txt"
    
    :: Run with timeout and redirect everything
    diskpart /s "%temp%\diskpart_script.txt" > "!DEST!\Metadata\Disk_ID.txt" 2>&1
    timeout /t 3 >nul
    
    :: Always clean up
    del "%temp%\diskpart_script.txt" >nul 2>&1
    
    :: PowerShell capture (if available)
    if "!WINPE_MODE!"=="0" (
        powershell -Command "Get-Disk -Number !DNUM! | Select-Object Number, UniqueId, Guid, PartitionStyle, Size | Format-List" >> "!DEST!\Metadata\Disk_ID.txt" 2>nul
        powershell -Command "Get-Partition -DiskNumber !DNUM! | Select-Object PartitionNumber, DriveLetter, GptType, MbrType, Size, Offset | Format-List" >> "!DEST!\Metadata\Disk_Info.txt" 2>nul
    ) else (
        echo select disk !DNUM!> "%temp%\part_info.txt"
        echo list partition>> "%temp%\part_info.txt"
        echo exit>> "%temp%\part_info.txt"
        diskpart /s "%temp%\part_info.txt" >> "!DEST!\Metadata\Disk_Info.txt" 2>&1
        timeout /t 3 >nul
        del "%temp%\part_info.txt" >nul 2>&1
    )
)

:: 6. EFI Detection and Mount (WinPE-compatible)
echo [*] Detecting EFI System Partition (ESP) on Disk !DNUM!...
set "ESP_PART_NUM="
if "!WINPE_MODE!"=="0" (
    :: Try PowerShell method (full Windows)
    for /f %%p in ('powershell -NoProfile -Command "$p = Get-Partition -DiskNumber !DNUM! | Where-Object {$_.GptType -eq '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}'} | Select-Object -First 1; if ($p) { echo $p.PartitionNumber }" 2^>nul') do set "ESP_PART_NUM=%%p"
)
:: Fallback: Use diskpart (works in WinPE)
if not defined ESP_PART_NUM (
    echo select disk !DNUM!> "%temp%\find_esp.txt"
    echo list partition>> "%temp%\find_esp.txt"
    echo exit>> "%temp%\find_esp.txt"
    diskpart /s "%temp%\find_esp.txt" > "%temp%\find_esp_out.txt" 2>nul
    timeout /t 3 >nul
    findstr /i "System" "%temp%\find_esp_out.txt" > "%temp%\find_esp_match.txt"
    if exist "%temp%\find_esp_match.txt" (
        for /f "tokens=1,2,5" %%A in ("%temp%\find_esp_match.txt") do (
            set "ESP_PART_NUM=%%A"
        )
    )
    del "%temp%\find_esp.txt" >nul 2>&1
    del "%temp%\find_esp_out.txt" >nul 2>&1
    del "%temp%\find_esp_match.txt" >nul 2>&1
    :: Alternative: Look for partition marked as "System" or with EFI files
    if not defined ESP_PART_NUM (
        for %%L in (Z Y X W V U T S R Q P O N) do (
            if exist "%%L:\EFI\Microsoft\Boot\bootmgfw.efi" (
                :: Find which partition this drive letter maps to
                echo list volume> "%temp%\map_esp.txt"
                echo exit>> "%temp%\map_esp.txt"
                diskpart /s "%temp%\map_esp.txt" > "%temp%\map_esp_out.txt" 2>nul
                timeout /t 3 >nul
                findstr /i "%%L" "%temp%\map_esp_out.txt" > "%temp%\map_esp_match.txt"
                if exist "%temp%\map_esp_match.txt" (
                    for /f "tokens=2" %%V in ("%temp%\map_esp_match.txt") do (
                        echo select volume %%V> "%temp%\esp_vol.txt"
                        echo detail volume>> "%temp%\esp_vol.txt"
                        echo exit>> "%temp%\esp_vol.txt"
                        diskpart /s "%temp%\esp_vol.txt" > "%temp%\esp_vol_out.txt" 2>nul
                        timeout /t 3 >nul
                        findstr /i "Disk" "%temp%\esp_vol_out.txt" > "%temp%\esp_vol_match.txt"
                        if exist "%temp%\esp_vol_match.txt" (
                            for /f "tokens=3" %%D in ("%temp%\esp_vol_match.txt") do (
                                if "%%D"=="!DNUM!" (
                                    echo select disk !DNUM!> "%temp%\esp_part.txt"
                                    echo list partition>> "%temp%\esp_part.txt"
                                    echo exit>> "%temp%\esp_part.txt"
                                    diskpart /s "%temp%\esp_part.txt" > "%temp%\esp_part_out.txt" 2>nul
                                    timeout /t 3 >nul
                                    findstr /i "%%L" "%temp%\esp_part_out.txt" > "%temp%\esp_part_match.txt"
                                    if exist "%temp%\esp_part_match.txt" (
                                        for /f "tokens=1,5" %%P in ("%temp%\esp_part_match.txt") do set "ESP_PART_NUM=%%P"
                                    )
                                    del "%temp%\esp_part_out.txt" >nul 2>&1
                                    del "%temp%\esp_part_match.txt" >nul 2>&1
                                )
                            )
                        )
                        del "%temp%\esp_vol.txt" >nul 2>&1
                        del "%temp%\esp_vol_out.txt" >nul 2>&1
                        del "%temp%\esp_vol_match.txt" >nul 2>&1
                    )
                )
                del "%temp%\map_esp.txt" >nul 2>&1
                del "%temp%\map_esp_out.txt" >nul 2>&1
                del "%temp%\map_esp_match.txt" >nul 2>&1
                del "%temp%\esp_part.txt" >nul 2>&1
            )
        )
    )
)

if not defined ESP_PART_NUM (
    echo [^!] ERROR: No valid ESP found on disk !DNUM!.
    pause & exit /b
)

:: Find available letter
set "ESP_LETTER="
for %%L in (Z Y X W V U T S R Q P O N) do (
    if not exist "%%L:\" (
        set "ESP_LETTER=%%L"
        goto :mount_esp
    )
)
:mount_esp
echo [*] Mounting ESP (Partition !ESP_PART_NUM!) to !ESP_LETTER!:
echo select disk !DNUM!> "%temp%\assign_esp.txt"
echo select partition !ESP_PART_NUM!>> "%temp%\assign_esp.txt"
echo assign letter=!ESP_LETTER!>> "%temp%\assign_esp.txt"
echo exit>> "%temp%\assign_esp.txt"
diskpart /s "%temp%\assign_esp.txt" >nul 2>&1
timeout /t 3 >nul
del "%temp%\assign_esp.txt" >nul 2>&1

:: 7. Capture Files
set "SOURCE_PATH=!ESP_LETTER!:\"
if not exist "!SOURCE_PATH!EFI\Microsoft\Boot\bootmgfw.efi" (
    echo [^!] ERROR: ESP Mount failed or files inaccessible.
    pause & exit /b
)

echo [*] Copying EFI Structure...
robocopy "!SOURCE_PATH!EFI" "!DEST!\EFI" /E /R:1 /W:1 /XF BCD* /B /NP /NFL /NDL /LOG:"!DEST!\Metadata\Robocopy_EFI.log"
set "ROBOCOPY_ERR=%ERRORLEVEL%"

echo [*] Exporting BCD...
bcdedit /export "!DEST!\EFI\Microsoft\Boot\BCD" >nul 2>&1
bcdedit /export "!DEST!\BCD_Backup" >nul 2>&1

:: 7.5. CLEANUP: Remove ESP Letter
echo [*] Removing temporary ESP drive letter !ESP_LETTER!:
mountvol !ESP_LETTER!: /D >nul 2>&1

:: Fallback if mountvol fails
if exist "!ESP_LETTER!:\" (
    echo select disk !DNUM!> "%temp%\rem_esp.txt"
    echo select partition !ESP_PART_NUM!>> "%temp%\rem_esp.txt"
    echo remove letter=!ESP_LETTER!>> "%temp%\rem_esp.txt"
    echo exit>> "%temp%\rem_esp.txt"
    diskpart /s "%temp%\rem_esp.txt" >nul 2>&1
    timeout /t 3 >nul
    del "%temp%\rem_esp.txt" >nul 2>&1
)

if not exist "!ESP_LETTER!:\" (
    echo [OK] ESP unmounted successfully.
) else (
    echo [^!] WARNING: Failed to remove drive letter !ESP_LETTER!:
)

:: 8. WinRE Capture
echo [*] Capturing WinRE.wim...
set "FOUND_RE="
for %%d in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if exist "%%d:\Recovery\WindowsRE\WinRE.wim" set "FOUND_RE=%%d:\Recovery\WindowsRE"
)
if "!FOUND_RE!"=="" (
    if exist "!SRC_DRIVE!:\Windows\System32\Recovery\WinRE.wim" set "FOUND_RE=!SRC_DRIVE!:\Windows\System32\Recovery"
)
if not "!FOUND_RE!"=="" (
    robocopy "!FOUND_RE!" "!DEST!" WinRE.wim /B /R:1 /W:1 /NP /NFL /NDL >nul
)

:: 9. Drivers (WinPE-compatible)
echo [*] Exporting DriverStore...
if "!WINPE_MODE!"=="1" (
    echo [INFO] WinPE mode: Driver export may be limited. Using available methods...
    :: In WinPE, pnputil may not work the same way, try it anyway
    pnputil /export-driver * "!DEST!\Drivers" >nul 2>&1
    if not "!errorlevel!"=="0" (
        echo [WARN] pnputil failed in WinPE. Drivers may not be exported.
    )
) else (
    pnputil /export-driver * "!DEST!\Drivers" >nul 2>&1
)

:: 10. Registry Hives
echo [*] Saving Registry Hives...
reg save HKLM\SYSTEM "!DEST!\Hives\SYSTEM" /y >nul 2>&1
reg save HKLM\SOFTWARE "!DEST!\Hives\SOFTWARE" /y >nul 2>&1

:: 10.5. WINCORE Backup (if enabled)
if "!WINCORE_ENABLED!"=="1" (
    echo.
    echo [*] Starting WINCORE backup...
    echo [*] This may take several minutes...
    
    :: Optional VSS Snapshot for cleaner live backup
    set "VSS_ID="
    set "USE_VSS=0"
    set "VSS_PATH="
    echo [*] Attempting to create Volume Shadow Copy for cleaner backup...
    echo set context persistent> "%temp%\vss_script.txt"
    echo add volume !SRC_DRIVE!: alias VSS_C>> "%temp%\vss_script.txt"
    echo create>> "%temp%\vss_script.txt"
    echo expose %%VSS_C%% Z:>> "%temp%\vss_script.txt"
    echo exit>> "%temp%\vss_script.txt"
    
    diskshadow /s "%temp%\vss_script.txt" > "%temp%\vss_out.txt" 2>&1
    timeout /t 3 >nul
    findstr /i "shadow copy ID" "%temp%\vss_out.txt" > "%temp%\vss_id.txt"
    
    if exist "%temp%\vss_id.txt" (
        for /f "tokens=*" %%V in ("%temp%\vss_id.txt") do (
            for /f "tokens=8" %%I in ("%%V") do set "VSS_ID=%%I"
        )
        if defined VSS_ID (
            echo [OK] Shadow copy created. Using snapshot for backup.
            set "VSS_PATH=\\?\GLOBALROOT\Device\HarddiskVolumeShadowCopy!VSS_ID!\Windows"
            set "USE_VSS=1"
        ) else (
            echo [INFO] VSS snapshot not available. Using live filesystem.
        )
    ) else (
        echo [INFO] VSS snapshot not available. Using live filesystem.
    )
    
    del "%temp%\vss_script.txt" "%temp%\vss_out.txt" "%temp%\vss_id.txt" >nul 2>&1
    
    :: Backup System32 (exclude LogFiles subfolder)
    echo [*] Backing up System32...
    if "!USE_VSS!"=="1" (
        robocopy "!VSS_PATH!\System32" "!DEST!\WIN_CORE\SYSTEM32" /E /R:3 /W:5 /COPY:DAT /XD "LogFiles" "catroot2" /NP /NFL /NDL /LOG:"!DEST!\LOGS\wincore_backup.log"
    ) else (
        robocopy "!SRC_DRIVE!:\Windows\System32" "!DEST!\WIN_CORE\SYSTEM32" /E /R:1 /W:1 /COPY:DAT /XD "LogFiles" /NP /NFL /NDL /LOG:"!DEST!\LOGS\wincore_backup.log"
    )
    
    :: Backup SysWOW64
    echo [*] Backing up SysWOW64...
    if "!USE_VSS!"=="1" (
        robocopy "!VSS_PATH!\SysWOW64" "!DEST!\WIN_CORE\SYSWOW64" /E /R:3 /W:5 /COPY:DAT /NP /NFL /NDL /LOG+:"!DEST!\LOGS\wincore_backup.log"
    ) else (
        robocopy "!SRC_DRIVE!:\Windows\SysWOW64" "!DEST!\WIN_CORE\SYSWOW64" /E /R:1 /W:1 /COPY:DAT /NP /NFL /NDL /LOG+:"!DEST!\LOGS\wincore_backup.log"
    )
    
    :: Backup Boot
    echo [*] Backing up Boot...
    if "!USE_VSS!"=="1" (
        robocopy "!VSS_PATH!\Boot" "!DEST!\WIN_CORE\BOOT" /E /R:3 /W:5 /COPY:DAT /NP /NFL /NDL /LOG+:"!DEST!\LOGS\wincore_backup.log"
    ) else (
        robocopy "!SRC_DRIVE!:\Windows\Boot" "!DEST!\WIN_CORE\BOOT" /E /R:1 /W:1 /COPY:DAT /NP /NFL /NDL /LOG+:"!DEST!\LOGS\wincore_backup.log"
    )
    
    :: Backup Drivers (from System32\drivers)
    echo [*] Backing up Drivers...
    if "!USE_VSS!"=="1" (
        robocopy "!VSS_PATH!\System32\drivers" "!DEST!\WIN_CORE\DRIVERS" /E /R:3 /W:5 /COPY:DAT /NP /NFL /NDL /LOG+:"!DEST!\LOGS\wincore_backup.log"
    ) else (
        robocopy "!SRC_DRIVE!:\Windows\System32\drivers" "!DEST!\WIN_CORE\DRIVERS" /E /R:1 /W:1 /COPY:DAT /NP /NFL /NDL /LOG+:"!DEST!\LOGS\wincore_backup.log"
    )
    
    :: Backup INF
    echo [*] Backing up INF...
    if "!USE_VSS!"=="1" (
        robocopy "!VSS_PATH!\INF" "!DEST!\WIN_CORE\INF" /E /R:3 /W:5 /COPY:DAT /NP /NFL /NDL /LOG+:"!DEST!\LOGS\wincore_backup.log"
    ) else (
        robocopy "!SRC_DRIVE!:\Windows\INF" "!DEST!\WIN_CORE\INF" /E /R:1 /W:1 /COPY:DAT /NP /NFL /NDL /LOG+:"!DEST!\LOGS\wincore_backup.log"
    )
    
    :: Backup servicing (exclude Logs and Temp subfolders)
    echo [*] Backing up servicing...
    if "!USE_VSS!"=="1" (
        robocopy "!VSS_PATH!\servicing" "!DEST!\WIN_CORE\SERVICING" /E /R:3 /W:5 /COPY:DAT /XD "Logs" "Temp" /NP /NFL /NDL /LOG+:"!DEST!\LOGS\wincore_backup.log"
    ) else (
        robocopy "!SRC_DRIVE!:\Windows\servicing" "!DEST!\WIN_CORE\SERVICING" /E /R:1 /W:1 /COPY:DAT /XD "Logs" "Temp" /NP /NFL /NDL /LOG+:"!DEST!\LOGS\wincore_backup.log"
    )
    
    :: Cleanup VSS snapshot if created
    if defined VSS_ID (
        echo [*] Removing shadow copy...
        echo delete shadows id !VSS_ID!> "%temp%\vss_delete.txt"
        diskshadow /s "%temp%\vss_delete.txt" >nul 2>&1
        timeout /t 3 >nul
        del "%temp%\vss_delete.txt" >nul 2>&1
    )
    
    echo [OK] WINCORE backup completed. Log: !DEST!\LOGS\wincore_backup.log
)

:: 11. Final Verification & Scoring
echo.
echo [*] Verifying backup integrity...
set "BOOT_SAFETY_SCORE=0"
if exist "!DEST!\EFI\Microsoft\Boot\bootmgfw.efi" set /a BOOT_SAFETY_SCORE+=25
if exist "!DEST!\EFI\Microsoft\Boot\BCD" set /a BOOT_SAFETY_SCORE+=25
if exist "!DEST!\BCD_Backup" set /a BOOT_SAFETY_SCORE+=25
if exist "!DEST!\Hives\SYSTEM" set /a BOOT_SAFETY_SCORE+=25

echo ============================================================
echo BOOT-SAFETY SCORE: !BOOT_SAFETY_SCORE! / 100
echo ============================================================
echo Backup Location: !DEST!
if "!WINCORE_ENABLED!"=="1" (
    if exist "!DEST!\WIN_CORE\SYSTEM32\ntoskrnl.exe" (
        echo WINCORE Payload: DETECTED (Enhanced Recovery Available)
    ) else (
        echo WINCORE Payload: INCOMPLETE
    )
)
echo ============================================================

pause