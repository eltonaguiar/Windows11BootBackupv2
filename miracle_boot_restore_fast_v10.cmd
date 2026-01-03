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
set /p "TARGET=Enter Target OS Drive Letter to fix (e.g. C): "
set "TARGET=%TARGET::=%"

if not exist "!TARGET!:\Windows" (
    echo [!] ERROR: Target !TARGET!:\Windows not found.
    pause & exit /b
)

:: 3. Identify Target EFI Physical Location
echo [*] Mapping !TARGET!: to physical hardware...
for /f %%d in ('powershell -Command "(Get-Partition -DriveLetter !TARGET!).DiskNumber"') do set "TDNUM=%%d"
for /f %%p in ('powershell -Command "(Get-Partition -DiskNumber !TDNUM! | Where-Object {$_.GptType -eq '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}'}).PartitionNumber"') do set "TPNUM=%%p"

echo [*] Target identified: Disk !TDNUM! | Partition !TPNUM!
set /p "CONFIRM=Type 'CONFIRM' to execute surgical restore: "
if /i "%CONFIRM%" neq "CONFIRM" exit /b

:: 4. Restore EFI structure
echo [*] Mounting EFI partition...
mountvol Y: /D >nul 2>&1
(echo select disk !TDNUM! & echo select partition !TPNUM! & echo assign letter=Y) | diskpart >nul

if not exist Y:\ (
    echo [!] ERROR: Failed to mount EFI partition to Y:.
    pause & exit /b
)

echo [*] Restoring EFI files...
robocopy "%BKP%\EFI" Y:\EFI /E /R:1 /W:1 /V

:: 5. Surgical BCD Signature Repair
echo [*] Re-signing BCD signatures for Disk !TDNUM!...
bcdedit /import "%BKP%\BCD_Backup" /clean
bcdedit /store Y:\EFI\Microsoft\Boot\BCD /set {bootmgr} device partition=Y:
bcdedit /store Y:\EFI\Microsoft\Boot\BCD /set {default} device partition=!TARGET!:
bcdedit /store Y:\EFI\Microsoft\Boot\BCD /set {default} osdevice partition=!TARGET!:

:: 6. Inject Drivers
echo [*] Injecting Drivers into !TARGET!: ...
dism /Image:!TARGET!:\ /Add-Driver /Driver:"%BKP%\Drivers" /Recurse

:: 7. Registry Hive Restore
echo [*] Restoring Boot-Critical Hives...
reg load HKLM\OFF_SYS "!TARGET!:\Windows\System32\config\SYSTEM"
reg restore HKLM\OFF_SYS "%BKP%\Hives\SYSTEM"
reg unload HKLM\OFF_SYS

reg load HKLM\OFF_SOFT "!TARGET!:\Windows\System32\config\SOFTWARE"
reg restore HKLM\OFF_SOFT "%BKP%\Hives\SOFTWARE"
reg unload HKLM\OFF_SOFT

:: 8. Cleanup
mountvol Y: /D
echo.
echo ---------------------------------------------------------------------------
echo [SUCCESS] Restore Complete.
echo [ADVICE] If Windows fails to load, boot to CMD and run: 
echo          bcdboot !TARGET!:\Windows /f UEFI
echo ---------------------------------------------------------------------------
pause