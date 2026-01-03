@echo off
setlocal enabledelayedexpansion
title Miracle Boot Backup v13.8 - Nuclear Hardened (Full Source)

:: 1. Admin Check
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [!] ERROR: Admin Required. Please Right-Click -> Run as Administrator.
    pause & exit /b
)

:: 2. Drive Selection
cls
echo ============================================================
echo        MIRACLE BOOT BACKUP - NUCLEAR BUILD v13.8
echo ============================================================
echo.
echo Available Drives:
echo ------------------------------------------------------------
powershell -Command "Get-CimInstance Win32_LogicalDisk | Select-Object DeviceID, VolumeName, @{Name='Size(GB)';Expression={[math]::round($_.Size / 1GB, 2)}} | Format-Table -AutoSize"
echo ------------------------------------------------------------
echo.
set /p "SRC_DRIVE=Enter the OS Drive Letter to backup (e.g., C): "
set "SRC_DRIVE=%SRC_DRIVE::=%"

if not exist "%SRC_DRIVE%:\Windows" (
    echo [!] ERROR: %SRC_DRIVE%:\Windows not found.
    pause & exit /b
)

:: 3. Precision BitLocker Check
echo [*] Checking BitLocker Status on !SRC_DRIVE!:...
for /f "delims=" %%B in ('powershell -Command "(Get-BitLockerVolume -MountPoint !SRC_DRIVE!:).ProtectionStatus" 2^>nul') do set "BL_STAT=%%B"
if "!BL_STAT!"=="1" (
    echo [!] ALERT: BitLocker ENABLED. Ensure you have your Recovery Key.
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

:: 5. Capture Physical DNA (Disk Signatures)
echo [*] Capturing Physical Disk Signature...
for /f %%d in ('powershell -Command "(Get-Partition -DriveLetter !SRC_DRIVE!).DiskNumber" 2^>nul') do set "DNUM=%%d"
(echo select disk !DNUM! & echo uniqueid disk) | diskpart > "!DEST!\Metadata\Disk_ID.txt"
bcdedit /enum all /v > "!DEST!\Metadata\BCD_Full_Enum.txt"

:: 6. EFI Mount Bypass
echo [*] Attempting native EFI access via MountVol /S...
mountvol Z: /S >nul 2>&1

if not exist Z:\ (
    echo [!] MountVol /S failed. Attempting Symbolic Link Bypass...
    for /f "tokens=*" %%g in ('powershell -Command "$p = Get-Partition -DiskNumber !DNUM! | Where-Object {$_.GptType -eq '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}'}; $v = Get-Volume -Partition $p; $v.Path"') do set "EFI_GUID=%%g"
    mklink /d "%temp%\EFIBypass" "!EFI_GUID!" >nul 2>&1
    set "SOURCE_PATH=%temp%\EFIBypass"
) else (
    set "SOURCE_PATH=Z:"
)

:: 7. Capture Files
echo [*] Copying EFI Structure...
robocopy "!SOURCE_PATH!\EFI" "!DEST!\EFI" /E /R:1 /W:1 /XF BCD* /V /B

echo [*] Exporting BCD...
bcdedit /export "!DEST!\EFI\Microsoft\Boot\BCD"
bcdedit /export "!DEST!\BCD_Backup"

:: Cleanup Mount
if exist "%temp%\EFIBypass" rmdir "%temp%\EFIBypass"
mountvol Z: /D >nul 2>&1

:: 8. WinRE Capture
echo [*] Capturing WinRE.wim...
set "FOUND_RE="
for %%d in (C D E F G) do (if exist "%%d:\Recovery\WindowsRE\WinRE.wim" set "FOUND_RE=%%d:\Recovery\WindowsRE")
if "!FOUND_RE!"=="" (if exist "%SRC_DRIVE%:\Windows\System32\Recovery\WinRE.wim" set "FOUND_RE=%SRC_DRIVE%:\Windows\System32\Recovery")
if not "!FOUND_RE!"=="" (
    robocopy "!FOUND_RE!" "!DEST!" WinRE.wim /B /R:1 /W:1 >nul
)

:: 9. Drivers
echo [*] Exporting DriverStore...
pnputil /export-driver * "!DEST!\Drivers" >nul

:: 10. Registry Hives
echo [*] Saving Registry Hives...
set "CURR_DRIVE=!SRC_DRIVE!:"
if /i "!CURR_DRIVE!"=="%SystemDrive%" (
    reg save HKLM\SYSTEM "!DEST!\Hives\SYSTEM" /y >nul
    reg save HKLM\SOFTWARE "!DEST!\Hives\SOFTWARE" /y >nul
) else (
    reg load HKLM\T_SYS "!SRC_DRIVE!:\Windows\System32\config\SYSTEM" >nul
    reg save HKLM\T_SYS "!DEST!\Hives\SYSTEM" /y >nul
    reg unload HKLM\T_SYS >nul
    reg load HKLM\T_SOFT "!SRC_DRIVE!:\Windows\System32\config\SOFTWARE" >nul
    reg save HKLM\T_SOFT "!DEST!\Hives\SOFTWARE" /y >nul
    reg unload HKLM\T_SOFT >nul
)

echo.
echo ------------------------------------------------------------
echo [SUCCESS] Nuclear Backup Created: !DEST!
echo ------------------------------------------------------------
pause