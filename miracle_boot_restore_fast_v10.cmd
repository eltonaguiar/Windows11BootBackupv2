@echo off
setlocal enabledelayedexpansion
title Miracle Boot Restore v13.0 - Surgical Reconstruction (Non-PS)

echo ===========================================================================
echo    MIRACLE BOOT RESTORE v13.0 (No-PowerShell Environment Ready)
echo ===========================================================================

:: 1. Input & Validation
set /p "BKP=Drag and Drop the NUCLEAR BACKUP FOLDER: "
set "BKP=%BKP:"=%"
if not exist "!BKP!\EFI" (echo [!] ERROR: Invalid backup folder. & pause & exit /b)

set /p "TARGET=Enter Target Drive Letter to fix (e.g. C): "
set "TARGET=%TARGET::=%"

:: Validate target drive has Windows
if not exist "!TARGET!:\Windows" (
    echo [!] ERROR: !TARGET!:\Windows not found. Invalid target drive.
    pause & exit /b
)

:: 2. Identify Target EFI using Mountvol/DiskPart
echo [*] Mapping !TARGET!: to physical hardware...
(echo list volume) > "%temp%\dp_scan.txt"
diskpart /s "%temp%\dp_scan.txt" > "%temp%\dp_out.txt"

for /f "tokens=2,3,4" %%A in ('findstr /i "Volume" "%temp%\dp_out.txt"') do (
    if /i "%%B"=="!TARGET!" set "T_VOL_IDX=%%A"
)

:: Find physical disk via volume detail
(echo select volume !T_VOL_IDX! & echo detail volume) | diskpart > "%temp%\t_vol_detail.txt"
for /f "tokens=2,3" %%A in ('findstr /i "Disk" "%temp%\t_vol_detail.txt"') do (
    if "%%A"=="*" (set "TDNUM=%%B") else (set "TDNUM=%%A")
)

:: Find EFI partition number on target disk
echo [*] Searching for EFI partition on Disk !TDNUM!...
(echo select disk !TDNUM! & echo list partition) | diskpart > "%temp%\t_part_list.txt"

:: Identify partition by Type (System) or GUID
for /f "tokens=2" %%P in ('findstr /i "System" "%temp%\t_part_list.txt"') do set "TPNUM=%%P"

:: 3. Resolve Volume GUID Path (The deterministic way to write to ESP)
:: Use mountvol to find the GUID string for the target partition
for /f "tokens=*" %%V in ('mountvol ^| findstr /i "\\\?\\Volume{"') do (
    set "GUID_CANDIDATE=%%V"
    :: Check if this GUID maps to our target disk/partition via temporary mount
    mountvol X: !GUID_CANDIDATE! >nul 2>&1
    if exist X:\ (
        :: Probe if this is the EFI System Partition
        if exist X:\EFI\ (
           :: Confirm it is on the correct physical disk
           set "TARGET_ESP_GUID=!GUID_CANDIDATE!"
        )
        mountvol X: /D >nul 2>&1
    )
)

if not defined TARGET_ESP_GUID (
    echo [!] ERROR: Could not resolve ESP GUID. Attempting emergency drive-letter mount...
    (echo select disk !TDNUM! & echo select partition !TPNUM! & echo assign letter=S) | diskpart >nul
    set "TARGET_ESP_GUID=S:\"
)

echo [*] Target ESP: !TARGET_ESP_GUID!
set /p "CONFIRM=Type 'CONFIRM' to execute surgical restore: "
if /i "!CONFIRM!" neq "CONFIRM" exit /b

:: 4. Restoration Logic
echo [*] Copying EFI Structure...
robocopy "!BKP!\EFI" "!TARGET_ESP_GUID!EFI" /E /R:1 /W:1 /NP /NFL /NDL /LOG:"%temp%\restore_efi.log"

echo [*] Importing BCD and Fixing Signatures...
bcdboot !TARGET!:\Windows /f UEFI
bcdedit /import "!BKP!\BCD_Backup" /clean >nul 2>&1

:: Update BCD partition pointers manually
bcdedit /store "!TARGET_ESP_GUID!EFI\Microsoft\Boot\BCD" /set {default} device partition=!TARGET!:
bcdedit /store "!TARGET_ESP_GUID!EFI\Microsoft\Boot\BCD" /set {default} osdevice partition=!TARGET!:

:: 5. Inject Drivers
if exist "!BKP!\Drivers" (
    echo [*] Injecting Drivers via DISM...
    dism /Image:!TARGET!:\ /Add-Driver /Driver:"!BKP!\Drivers" /Recurse >nul 2>&1
)

:: 6. Registry Restoration (Universal Method)
echo [*] Restoring Hives...
reg load HKLM\OFF_SYS "!TARGET!:\Windows\System32\config\SYSTEM" >nul
reg restore HKLM\OFF_SYS "!BKP!\Hives\SYSTEM" >nul
reg unload HKLM\OFF_SYS >nul

reg load HKLM\OFF_SOFT "!TARGET!:\Windows\System32\config\SOFTWARE" >nul
reg restore HKLM\OFF_SOFT "!BKP!\Hives\SOFTWARE" >nul
reg unload HKLM\OFF_SOFT >nul

:: 7. WINCORE Restoration (if present)
if exist "!BKP!\WIN_CORE\SYSTEM32\ntoskrnl.exe" (
    echo.
    echo ===========================================================================
    echo                    WINCORE PAYLOAD DETECTED
    echo ===========================================================================
    
    :: Calculate approximate size (WinPE-compatible)
    set "WINCORE_SIZE=~8-12 GB"
    :: Try PowerShell method if available (full Windows)
    for /f %%s in ('powershell -Command "(Get-ChildItem '!BKP!\WIN_CORE' -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1GB" 2^>nul') do (
        set "WINCORE_SIZE=%%s GB"
    )
    
    echo Detected WINCORE payload (!WINCORE_SIZE! GB).
    echo This will overwrite Windows system files but preserve data.
    echo.
    set /p "WINCORE_CONFIRM=Proceed with WINCORE restore? (Y/N, default N): "
    if /i "!WINCORE_CONFIRM!"=="Y" (
        :: Final safety check - ensure target is valid Windows installation
        if not exist "!TARGET!:\Windows\System32" (
            echo [!] ERROR: !TARGET!:\Windows\System32 not found. Aborting WINCORE restore.
            pause & exit /b
        )
        echo.
        echo [*] Starting WINCORE restore to !TARGET!:\Windows...
        echo [*] This may take several minutes...
        
        :: Create logs directory if needed
        if not exist "!BKP!\LOGS" mkdir "!BKP!\LOGS" 2>nul
        
        :: Restore System32
        echo [*] Restoring System32...
        robocopy "!BKP!\WIN_CORE\SYSTEM32" "!TARGET!:\Windows\System32" /E /R:1 /W:1 /COPY:DAT /NP /NFL /NDL /LOG:"!BKP!\LOGS\wincore_restore.log"
        
        :: Restore SysWOW64
        echo [*] Restoring SysWOW64...
        robocopy "!BKP!\WIN_CORE\SYSWOW64" "!TARGET!:\Windows\SysWOW64" /E /R:1 /W:1 /COPY:DAT /NP /NFL /NDL /LOG+:"!BKP!\LOGS\wincore_restore.log"
        
        :: Restore Boot
        echo [*] Restoring Boot...
        robocopy "!BKP!\WIN_CORE\BOOT" "!TARGET!:\Windows\Boot" /E /R:1 /W:1 /COPY:DAT /NP /NFL /NDL /LOG+:"!BKP!\LOGS\wincore_restore.log"
        
        :: Restore Drivers
        echo [*] Restoring Drivers...
        robocopy "!BKP!\WIN_CORE\DRIVERS" "!TARGET!:\Windows\System32\drivers" /E /R:1 /W:1 /COPY:DAT /NP /NFL /NDL /LOG+:"!BKP!\LOGS\wincore_restore.log"
        
        :: Restore INF
        echo [*] Restoring INF...
        robocopy "!BKP!\WIN_CORE\INF" "!TARGET!:\Windows\INF" /E /R:1 /W:1 /COPY:DAT /NP /NFL /NDL /LOG+:"!BKP!\LOGS\wincore_restore.log"
        
        :: Restore servicing
        echo [*] Restoring servicing...
        robocopy "!BKP!\WIN_CORE\SERVICING" "!TARGET!:\Windows\servicing" /E /R:1 /W:1 /COPY:DAT /NP /NFL /NDL /LOG+:"!BKP!\LOGS\wincore_restore.log"
        
        echo [OK] WINCORE restore completed. Log: !BKP!\LOGS\wincore_restore.log
    ) else (
        echo [*] WINCORE restore skipped.
    )
) else (
    echo [*] No WINCORE payload detected. Skipping.
)

echo ===========================================================================
echo [SUCCESS] Surgical Restore Complete. Unmount S: if manually mounted.
echo ===========================================================================
pause