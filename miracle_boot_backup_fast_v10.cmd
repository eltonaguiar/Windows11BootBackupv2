@echo off
setlocal enabledelayedexpansion
title Miracle Boot Backup v14.1 - Nuclear Hardened (Full Source)

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
        
        :: 2. If file not found, check partition size/type via PowerShell (More robust)
        if "!IS_ESP!"=="0" (
            for /f "tokens=*" %%s in ('powershell -NoProfile -Command "$vol = Get-Volume -DriveLetter '%%L' -ErrorAction SilentlyContinue; if ($vol -and $vol.Size -ge 50MB -and $vol.Size -le 600MB) { Write-Output 'ESP' }" 2^>nul') do (
                if "%%s"=="ESP" set "IS_ESP=1"
            )
        )

        if "!IS_ESP!"=="1" (
            echo [*] Attempting to unmount ESP drive letter: %%L:
            
            :: Method A: Mountvol (Most reliable for simple removal)
            mountvol %%L: /D >nul 2>&1
            
            :: Method B: Diskpart Fallback (if Mountvol fails due to locks)
            if exist "%%L:\" (
                (
                    echo select volume %%L
                    echo remove letter=%%L
                ) > "%temp%\clean_%%L.txt"
                diskpart /s "%temp%\clean_%%L.txt" >nul 2>&1
                del "%temp%\clean_%%L.txt" >nul 2>&1
            )

            :: Verification
            if not exist "%%L:\" (
                set /a CLEANED_COUNT+=1
                echo [OK] Successfully removed: %%L:
            ) else (
                echo [^!] WARNING: Could not release %%L: (Partition may be in use)
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

:: 3. Precision BitLocker Check
echo [*] Checking BitLocker Status on !SRC_DRIVE!:...
for /f "delims=" %%B in ('powershell -Command "(Get-BitLockerVolume -MountPoint !SRC_DRIVE!:).ProtectionStatus" 2^>nul') do set "BL_STAT=%%B"
if "!BL_STAT!"=="1" (
    echo [^!] ALERT: BitLocker ENABLED. Ensure you have your Recovery Key.
) else (
    echo [OK] BitLocker DISABLED. Proceeding...
)

:: 4. Target Setup
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set "dt=%%I"
set "TS=!dt:~0,4!-!dt:~4,2!-!dt:~6,2!_!dt:~8,2!-!dt:~10,2!"
set "DEST=%~dp0!TS!_NUCLEAR_!SRC_DRIVE!"
mkdir "!DEST!\EFI" "!DEST!\Hives" "!DEST!\Drivers" "!DEST!\Metadata" 2>nul

echo.
echo [*] Target Directory: !DEST!

:: 5. Capture Physical DNA
echo [*] Capturing Physical Disk Signature...
set "DNUM="
for /f %%d in ('powershell -Command "(Get-Partition -DriveLetter C).DiskNumber" 2^>nul') do set "DNUM=%%d"
if defined DNUM (
    echo [*] Disk Number: !DNUM!
    echo select disk !DNUM! > "%temp%\diskpart_script.txt"
    echo uniqueid disk >> "%temp%\diskpart_script.txt"
    echo list disk >> "%temp%\diskpart_script.txt"
    diskpart /s "%temp%\diskpart_script.txt" > "!DEST!\Metadata\Disk_ID.txt" 2>&1
    del "%temp%\diskpart_script.txt" >nul 2>&1
    
    :: Redundant PowerShell capture
    powershell -Command "Get-Disk -Number !DNUM! | Select-Object Number, UniqueId, Guid, PartitionStyle, Size | Format-List" >> "!DEST!\Metadata\Disk_ID.txt" 2>&1
    powershell -Command "Get-Partition -DiskNumber !DNUM! | Select-Object PartitionNumber, DriveLetter, GptType, MbrType, Size, Offset | Format-List" >> "!DEST!\Metadata\Disk_Info.txt" 2>&1
)

:: 6. EFI Detection and Mount
echo [*] Detecting EFI System Partition (ESP) on Disk !DNUM!...
set "ESP_PART_NUM="
for /f %%p in ('powershell -NoProfile -Command "$p = Get-Partition -DiskNumber !DNUM! | Where-Object {$_.GptType -eq '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}'} | Select-Object -First 1; if ($p) { echo $p.PartitionNumber }"') do set "ESP_PART_NUM=%%p"

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
(
    echo select disk !DNUM!
    echo select partition !ESP_PART_NUM!
    echo assign letter=!ESP_LETTER!
) > "%temp%\assign_esp.txt"
diskpart /s "%temp%\assign_esp.txt" >nul 2>&1
del "%temp%\assign_esp.txt" >nul 2>&1
timeout /t 2 /nobreak >nul

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
    (
        echo select disk !DNUM!
        echo select partition !ESP_PART_NUM!
        echo remove letter=!ESP_LETTER!
    ) > "%temp%\rem_esp.txt"
    diskpart /s "%temp%\rem_esp.txt" >nul 2>&1
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

:: 9. Drivers
echo [*] Exporting DriverStore...
pnputil /export-driver * "!DEST!\Drivers" >nul 2>&1

:: 10. Registry Hives
echo [*] Saving Registry Hives...
reg save HKLM\SYSTEM "!DEST!\Hives\SYSTEM" /y >nul 2>&1
reg save HKLM\SOFTWARE "!DEST!\Hives\SOFTWARE" /y >nul 2>&1

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
echo ============================================================

pause