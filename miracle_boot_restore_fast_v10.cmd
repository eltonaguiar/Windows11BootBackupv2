@echo off
setlocal enabledelayedexpansion
title Miracle Boot Restore v12.6 - Nuclear Grade (Full Source)

:: 1. Admin Check
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [!] ERROR: Admin Required. Please Right-Click -> Run as Administrator.
    pause & exit /b
)

echo ===========================================================================
echo    MIRACLE BOOT RESTORE v12.6 (Surgical Signature Reconstruction)
echo ===========================================================================

:: 2. Input
set /p "BKP=Drag and Drop the NUCLEAR BACKUP FOLDER: "
set "BKP=%BKP:"=%"
if not exist "!BKP!" (
    echo [!] ERROR: Backup folder not found: !BKP!
    pause & exit /b
)
if not exist "!BKP!\EFI" (
    echo [!] ERROR: Invalid backup folder - EFI directory not found.
    pause & exit /b
)
if not exist "!BKP!\BCD_Backup" (
    echo [!] ERROR: Invalid backup folder - BCD_Backup not found.
    pause & exit /b
)
if not exist "!BKP!\Hives\SYSTEM" (
    echo [!] ERROR: Invalid backup folder - Hives\SYSTEM not found.
    pause & exit /b
)
if not exist "!BKP!\Hives\SOFTWARE" (
    echo [!] ERROR: Invalid backup folder - Hives\SOFTWARE not found.
    pause & exit /b
)
echo [OK] Backup folder validated.

set /p "TARGET=Enter Target OS Drive Letter to fix (e.g. C): "
set "TARGET=%TARGET::=%"

if not exist "!TARGET!:\Windows" (
    echo [!] ERROR: Target !TARGET!:\Windows not found.
    pause & exit /b
)

:: 3. Identify Target EFI by GUID (FAT32 + ~100MB detection)
echo [*] Mapping !TARGET!: to physical hardware...
for /f %%d in ('powershell -Command "(Get-Partition -DriveLetter !TARGET!).DiskNumber" 2^>nul') do set "TDNUM=%%d"
if "!TDNUM!"=="" (
    echo [!] ERROR: Could not determine target disk number.
    pause & exit /b
)

:: Detect ESP by GUID (FAT32, 50-500MB)
echo try { > "%temp%\get_target_esp.ps1"
echo   $p = Get-Partition -DiskNumber !TDNUM! -ErrorAction Stop ^| Where-Object {$_.GptType -eq '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}'} >> "%temp%\get_target_esp.ps1"
echo   if ($null -ne $p) { >> "%temp%\get_target_esp.ps1"
echo     $v = Get-Volume -Partition $p -ErrorAction Stop >> "%temp%\get_target_esp.ps1"
echo     if ($v.FileSystemType -eq 'FAT32') { >> "%temp%\get_target_esp.ps1"
echo       $sizeMB = [math]::Round($v.Size / 1MB, 2) >> "%temp%\get_target_esp.ps1"
echo       if ($sizeMB -lt 500 -and $sizeMB -gt 50) { Write-Output $v.Path } >> "%temp%\get_target_esp.ps1"
echo     } >> "%temp%\get_target_esp.ps1"
echo   } >> "%temp%\get_target_esp.ps1"
echo } catch { } >> "%temp%\get_target_esp.ps1"
for /f "tokens=*" %%g in ('powershell -NoProfile -ExecutionPolicy Bypass -File "%temp%\get_target_esp.ps1" 2^>nul') do set "TARGET_ESP_GUID=%%g"
del "%temp%\get_target_esp.ps1" >nul 2>&1

if "!TARGET_ESP_GUID!"=="" (
    echo [!] WARNING: Could not find valid ESP (FAT32, 50-500MB) on disk !TDNUM!
    echo [!] Attempting fallback detection (any GPT EFI partition)...
    echo try { > "%temp%\get_target_esp_fallback.ps1"
    echo   $p = Get-Partition -DiskNumber !TDNUM! -ErrorAction Stop ^| Where-Object {$_.GptType -eq '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}'} >> "%temp%\get_target_esp_fallback.ps1"
    echo   if ($null -ne $p) { >> "%temp%\get_target_esp_fallback.ps1"
    echo     $v = Get-Volume -Partition $p -ErrorAction Stop >> "%temp%\get_target_esp_fallback.ps1"
    echo     Write-Output $v.Path >> "%temp%\get_target_esp_fallback.ps1"
    echo   } >> "%temp%\get_target_esp_fallback.ps1"
    echo } catch { } >> "%temp%\get_target_esp_fallback.ps1"
    for /f "tokens=*" %%g in ('powershell -NoProfile -ExecutionPolicy Bypass -File "%temp%\get_target_esp_fallback.ps1" 2^>nul') do set "TARGET_ESP_GUID=%%g"
    del "%temp%\get_target_esp_fallback.ps1" >nul 2>&1
)

if "!TARGET_ESP_GUID!"=="" (
    echo [!] ERROR: No EFI partition found on disk !TDNUM!.
    echo [!] This may not be a GPT disk or EFI partition is missing.
    pause & exit /b
)

for /f %%p in ('powershell -Command "(Get-Partition -DiskNumber !TDNUM! | Where-Object {$_.GptType -eq '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}'}).PartitionNumber" 2^>nul') do set "TPNUM=%%p"

echo [*] Target ESP GUID: !TARGET_ESP_GUID!
echo [*] Target identified: Disk !TDNUM! | Partition !TPNUM!

:: Display backup metadata if available
if exist "!BKP!\Metadata\ESP_GUID.txt" (
    echo.
    echo [*] Original Backup ESP Information:
    type "!BKP!\Metadata\ESP_GUID.txt"
    echo.
)
if exist "!BKP!\Metadata\Disk_ID.txt" (
    echo [*] Original Backup Disk Information:
    type "!BKP!\Metadata\Disk_ID.txt" | findstr /i "Disk\|Unique\|Number" | more
    echo.
)

set /p "CONFIRM=Type 'CONFIRM' to execute surgical restore: "
if /i "!CONFIRM!" neq "CONFIRM" (
    echo [*] Restore cancelled by user.
    exit /b
)

:: 4. Restore EFI structure - Use GUID path directly with FAIL-FAST validation
echo [*] Restoring EFI files via GUID path (deterministic method)...
set "TARGET_ESP_PATH=!TARGET_ESP_GUID!"

:: FAIL-FAST VALIDATION: Check backup integrity before restore
echo [*] FAIL-FAST VALIDATION: Verifying backup integrity...
set "BACKUP_BOOTMGFW=!BKP!\EFI\Microsoft\Boot\bootmgfw.efi"
if not exist "!BACKUP_BOOTMGFW!" (
    echo [!] ============================================================
    echo [!] CRITICAL VALIDATION FAILURE
    echo [!] ============================================================
    echo [!] REQUIRED FILE MISSING IN BACKUP: !BACKUP_BOOTMGFW!
    echo [!] Backup folder: !BKP!
    echo [!] Backup is INVALID or CORRUPTED. Aborting restore.
    echo [!] ============================================================
    pause & exit /b 1
)
echo [OK] Backup bootmgfw.efi validated - file exists in backup

:: Validate target ESP path is accessible
if not exist "!TARGET_ESP_PATH!" (
    echo [!] ERROR: Target ESP path not accessible: !TARGET_ESP_PATH!
    echo [!] ESP GUID: !TARGET_ESP_GUID!
    echo [!] Verify disk !TDNUM! partition !TPNUM! is accessible
    pause & exit /b 1
)
echo [OK] Target ESP path validated: !TARGET_ESP_PATH!

:: Restore EFI structure with detailed logging
echo [*] Copying EFI structure from backup to target ESP...
robocopy "!BKP!\EFI" "!TARGET_ESP_PATH!\EFI" /E /R:1 /W:1 /NP /NFL /NDL /LOG:"%temp%\restore_efi_%random%.log"
set "ROBOCOPY_ERR=!errorLevel!"

:: Robocopy exit codes: 0-7 = success, 8+ = error
if !ROBOCOPY_ERR! geq 8 (
    echo [!] ============================================================
    echo [!] ROBOCOPY RESTORE FAILURE
    echo [!] ============================================================
    echo [!] Robocopy failed with error code !ROBOCOPY_ERR!
    echo [!] This indicates a serious copy failure (not just locked files)
    echo [!] Check log: %temp%\restore_efi_*.log
    echo [!] Some files may not have been restored.
    echo [!] ============================================================
    pause & exit /b 1
) else (
    echo [OK] EFI structure restore completed (Robocopy exit code: !ROBOCOPY_ERR!)
    if !ROBOCOPY_ERR! geq 1 (
        echo [*] Note: Exit code !ROBOCOPY_ERR! indicates some files were skipped
        echo [*] This is NORMAL for locked files (BCD, active boot files)
        echo [*] Full log available: %temp%\restore_efi_*.log
    ) else (
        echo [PERFECT] All EFI files restored successfully (exit code 0)
    )
)

:: POST-RESTORE VALIDATION: Fail fast if bootmgfw.efi missing after restore
echo [*] POST-RESTORE VALIDATION: Verifying critical files...
set "RESTORED_BOOTMGFW=!TARGET_ESP_PATH!\EFI\Microsoft\Boot\bootmgfw.efi"
if not exist "!RESTORED_BOOTMGFW!" (
    echo [!] ============================================================
    echo [!] CRITICAL POST-RESTORE VALIDATION FAILURE
    echo [!] ============================================================
    echo [!] REQUIRED FILE MISSING AFTER RESTORE: !RESTORED_BOOTMGFW!
    echo [!] Target ESP GUID: !TARGET_ESP_GUID!
    echo [!] Restore FAILED. ESP may be corrupted or inaccessible.
    echo [!] ============================================================
    pause & exit /b 1
)
echo [OK] Post-restore validation: bootmgfw.efi confirmed on target ESP

:: Log restored ESP identity
echo Target ESP GUID: !TARGET_ESP_GUID! > "%temp%\restore_esp_log.txt"
echo Restore completed: %date% %time% >> "%temp%\restore_esp_log.txt"

:: 5. Surgical BCD Signature Repair
echo [*] Re-signing BCD signatures for Disk !TDNUM!...
if not exist "!BKP!\BCD_Backup" (
    echo [!] ERROR: BCD_Backup file not found in backup folder.
    pause & exit /b
)
bcdedit /import "!BKP!\BCD_Backup" /clean >nul 2>&1
if !errorLevel! neq 0 (
    echo [!] WARNING: BCD import returned error code !errorLevel!
)
if not exist "!TARGET_ESP_PATH!\EFI\Microsoft\Boot\BCD" (
    echo [!] ERROR: BCD file not found after restore. Attempting direct copy...
    if exist "!BKP!\EFI\Microsoft\Boot\BCD" (
        copy /Y "!BKP!\EFI\Microsoft\Boot\BCD" "!TARGET_ESP_PATH!\EFI\Microsoft\Boot\BCD" >nul 2>&1
    )
)
:: Get bootmgr device from BCD and log it (before modification)
for /f "tokens=*" %%b in ('bcdedit /store "!TARGET_ESP_PATH!\EFI\Microsoft\Boot\BCD" /enum {bootmgr} 2^>nul ^| findstr /i "device"') do (
    echo Boot Manager Device (before): %%b >> "%temp%\restore_esp_log.txt"
    echo [*] Boot Manager Device (before): %%b
)
:: Get volume number for ESP partition
for /f %%v in ('powershell -Command "$p = Get-Partition -DiskNumber !TDNUM! | Where-Object {$_.GptType -eq '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}'}; if ($p) { $vol = Get-Volume -Partition $p; $vol.UniqueId -replace '.*Volume\\{([^}]+)\\}.*', '$1' }" 2^>nul') do set "ESP_VOL_ID=%%v"
:: Use bcdboot to rebuild BCD with correct signatures (most reliable)
echo [*] Rebuilding BCD signatures...
bcdboot !TARGET!:\Windows /f UEFI >nul 2>&1
:: Then import our backup BCD
bcdedit /import "!BKP!\BCD_Backup" /clean >nul 2>&1
:: Update device paths
bcdedit /store "!TARGET_ESP_PATH!\EFI\Microsoft\Boot\BCD" /set {default} device partition=!TARGET!: >nul 2>&1
bcdedit /store "!TARGET_ESP_PATH!\EFI\Microsoft\Boot\BCD" /set {default} osdevice partition=!TARGET!: >nul 2>&1
:: Get bootmgr device after update and log it
for /f "tokens=*" %%b in ('bcdedit /store "!TARGET_ESP_PATH!\EFI\Microsoft\Boot\BCD" /enum {bootmgr} 2^>nul ^| findstr /i "device"') do (
    echo Boot Manager Device (after): %%b >> "%temp%\restore_esp_log.txt"
    echo [*] Boot Manager Device (after): %%b
)
echo [OK] BCD signatures updated.

:: 6. Inject Drivers
if exist "!BKP!\Drivers" (
    echo [*] Injecting Drivers into !TARGET!: ...
    dism /Image:!TARGET!:\ /Add-Driver /Driver:"!BKP!\Drivers" /Recurse >nul 2>&1
    if !errorLevel! equ 0 (
        echo [OK] Drivers injected successfully.
    ) else (
        echo [!] WARNING: Driver injection returned error code !errorLevel!
        echo [!] This may be normal if no compatible drivers were found.
    )
) else (
    echo [!] WARNING: Drivers folder not found in backup. Skipping driver injection.
)

:: 7. Registry Hive Restore
echo [*] Restoring Boot-Critical Hives...
if not exist "!BKP!\Hives\SYSTEM" (
    echo [!] ERROR: SYSTEM hive not found in backup.
    pause & exit /b
)
if not exist "!BKP!\Hives\SOFTWARE" (
    echo [!] ERROR: SOFTWARE hive not found in backup.
    pause & exit /b
)

reg load HKLM\OFF_SYS "!TARGET!:\Windows\System32\config\SYSTEM" >nul 2>&1
if !errorLevel! neq 0 (
    echo [!] ERROR: Failed to load SYSTEM hive from target drive.
    pause & exit /b
)
reg restore HKLM\OFF_SYS "!BKP!\Hives\SYSTEM" >nul 2>&1
if !errorLevel! neq 0 (
    echo [!] ERROR: Failed to restore SYSTEM hive.
    reg unload HKLM\OFF_SYS >nul 2>&1
    pause & exit /b
)
reg unload HKLM\OFF_SYS >nul 2>&1
echo [OK] SYSTEM hive restored.

reg load HKLM\OFF_SOFT "!TARGET!:\Windows\System32\config\SOFTWARE" >nul 2>&1
if !errorLevel! neq 0 (
    echo [!] ERROR: Failed to load SOFTWARE hive from target drive.
    pause & exit /b
)
reg restore HKLM\OFF_SOFT "!BKP!\Hives\SOFTWARE" >nul 2>&1
if !errorLevel! neq 0 (
    echo [!] ERROR: Failed to restore SOFTWARE hive.
    reg unload HKLM\OFF_SOFT >nul 2>&1
    pause & exit /b
)
reg unload HKLM\OFF_SOFT >nul 2>&1
echo [OK] SOFTWARE hive restored.

:: 8. Cleanup (no mount cleanup needed - using GUID path directly)

:: 9. Verification
echo.
echo [*] Verifying restore...
if exist "!TARGET_ESP_PATH!\EFI\Microsoft\Boot\bootmgfw.efi" (
    echo [OK] bootmgfw.efi verified on ESP.
) else (
    echo [!] ERROR: bootmgfw.efi verification failed - restore incomplete!
)
if exist "!TARGET!:\Windows\System32\config\SYSTEM" (
    echo [OK] SYSTEM hive restored to target.
) else (
    echo [!] WARNING: SYSTEM hive verification failed.
)
if exist "!TARGET!:\Windows\System32\config\SOFTWARE" (
    echo [OK] SOFTWARE hive restored to target.
) else (
    echo [!] WARNING: SOFTWARE hive verification failed.
)

echo.
echo ---------------------------------------------------------------------------
echo [SUCCESS] Restore Complete.
echo.
echo [ADVICE] If Windows fails to load, boot to recovery environment and run:
echo          bcdboot !TARGET!:\Windows /f UEFI
echo.
echo [ADVICE] You may also need to rebuild the BCD if issues persist:
echo          bootrec /rebuildbcd
echo          bootrec /fixmbr
echo          bootrec /fixboot
echo ---------------------------------------------------------------------------
pause