@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ======================================================
REM MIRACLE BOOT BACKUP - FAST BOOT IMAGE (V7)
REM - Captures only boot-critical components for fast restore
REM - Does NOT touch Users / Program Files / data
REM ======================================================

REM --- Require admin ---
net session >nul 2>&1
if not "%errorlevel%"=="0" (
  echo [ERROR] Run this as Administrator.
  pause
  exit /b 1
)

REM --- Destination root ---
set "DESTROOT=G:\MIRACLE_BOOT_FIXER"
if not exist "G:\" (
  echo [ERROR] G: drive not found. Connect your backup drive.
  pause
  exit /b 1
)
if not exist "%DESTROOT%\" mkdir "%DESTROOT%" >nul 2>&1

echo ======================================================
echo MIRACLE BOOT BACKUP - FAST BOOT IMAGE (V7)
echo ======================================================

REM --- Drive Selection ---
echo [LIST] Detected Windows installations:
for %%D in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
  if exist "%%D:\Windows\System32\config\SYSTEM" (
    echo   - %%D:
  )
)
echo.
set /p "SOURCE_DRIVE=Which drive are we backing up? (Enter letter only, e.g. C): "
if "%SOURCE_DRIVE%"=="" (
  echo [ERROR] No drive provided.
  pause & exit /b 1
)

REM Strip colon/spaces just in case
set "SOURCE_DRIVE=%SOURCE_DRIVE: =%"
set "SOURCE_DRIVE=%SOURCE_DRIVE::=%"
set "SRC=%SOURCE_DRIVE%:"

if not exist "%SRC%\Windows\System32\config\SYSTEM" (
  echo [ERROR] %SRC% is not a valid Windows drive.
  pause & exit /b 1
)

REM --- Timestamp ---
for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format ''yyyy-MM-dd_HH-mm-ss''"') do set "TS=%%I"
set "OUT=%DESTROOT%\%TS%_FASTBOOT_%SOURCE_DRIVE%"
set "LOGS=%OUT%\LOGS"
set "DRIVERS=%OUT%\DRIVERS_EXPORT"
set "WINBOOT=%OUT%\WIN_BOOT"
set "HIVES=%WINBOOT%\HIVES"
set "CORE=%WINBOOT%\CORE_FILES"
set "COREDRV=%WINBOOT%\CORE_DRIVERS"
set "DRVSTORE=%WINBOOT%\DRIVERSTORE_STORAGE"

mkdir "%LOGS%" 2>nul
mkdir "%DRIVERS%" 2>nul
mkdir "%HIVES%" 2>nul
mkdir "%CORE%" 2>nul
mkdir "%COREDRV%" 2>nul
mkdir "%DRVSTORE%" 2>nul

echo [OK] Output folder: "%OUT%"

REM --- Detect Boot Mode ---
set "BOOT_MODE=LEGACY"
bcdedit | find /i "winload.efi" >nul && set "BOOT_MODE=UEFI"
echo [INFO] Boot mode detected: %BOOT_MODE%

REM --- Backup EFI (UEFI) or Boot folder (Legacy) ---
if /i "%BOOT_MODE%"=="UEFI" (
  call :BACKUP_UEFI
) else (
  call :BACKUP_LEGACY
)

REM --- Export BCD and boot config ---
echo [INFO] Exporting BCD store...
bcdedit /export "%OUT%\BCD_EXPORT.bcd" > "%LOGS%\bcd_export.txt" 2>&1
bcdedit /enum all > "%OUT%\BCD_ENUM.txt" 2>&1

REM --- Save disk layout (best-effort: disk 0 only) ---
echo [INFO] Saving disk layout...
(
  echo list disk
  echo list volume
  echo select disk 0
  echo list partition
) > "%LOGS%\layout_cmd.txt"
diskpart /s "%LOGS%\layout_cmd.txt" > "%OUT%\DISK_LAYOUT.txt" 2>&1

REM --- Export 3rd-party drivers (good for migrations) ---
echo [INFO] Exporting 3rd-party drivers (pnputil export-driver)...
pnputil /export-driver * "%DRIVERS%" > "%LOGS%\driver_export.txt" 2>&1

REM ======================================================
REM FAST BOOT PAYLOAD (boot-critical subset)
REM ======================================================

echo [INFO] Capturing boot-critical Windows files from %SRC% ...

REM Core boot loaders / kernel bits
call :COPY_FILE "%SRC%\Windows\System32\winload.efi"        "%CORE%"
call :COPY_FILE "%SRC%\Windows\System32\winresume.efi"      "%CORE%"
call :COPY_FILE "%SRC%\Windows\System32\ntoskrnl.exe"        "%CORE%"
call :COPY_FILE "%SRC%\Windows\System32\hal.dll"             "%CORE%"
call :COPY_FILE "%SRC%\Windows\System32\ci.dll"              "%CORE%"
call :COPY_FILE "%SRC%\Windows\System32\clfs.sys"            "%CORE%"

REM Registry hives (critical)
echo [INFO] Capturing registry hives...
call :COPY_FILE "%SRC%\Windows\System32\config\SYSTEM"   "%HIVES%"
call :COPY_FILE "%SRC%\Windows\System32\config\SOFTWARE" "%HIVES%"
call :COPY_FILE "%SRC%\Windows\System32\config\SAM"      "%HIVES%"
call :COPY_FILE "%SRC%\Windows\System32\config\SECURITY" "%HIVES%"
call :COPY_FILE "%SRC%\Windows\System32\config\DEFAULT"  "%HIVES%"

REM Boot-critical drivers (common)
echo [INFO] Capturing core storage/boot drivers...
for %%F in (
  acpi.sys
  partmgr.sys
  volmgr.sys
  volmgrx.sys
  mountmgr.sys
  disk.sys
  classpnp.sys
  storport.sys
  stornvme.sys
  storahci.sys
  pci.sys
  pcidex.sys
  msrpc.sys
  fltmgr.sys
  wdf01000.sys
) do (
  call :COPY_FILE "%SRC%\Windows\System32\drivers\%%F" "%COREDRV%"
)

REM Intel / RST / VMD (if present)
for %%F in (
  iaStorA.sys
  iaStorAC.sys
  iaStorAV.sys
  iaStorV.sys
  vmd.sys
) do (
  if exist "%SRC%\Windows\System32\drivers\%%F" (
    call :COPY_FILE "%SRC%\Windows\System32\drivers\%%F" "%COREDRV%"
  )
)

REM Storage-related DriverStore packages (best-effort)
echo [INFO] Capturing storage-related DriverStore packages (best-effort)...
call :COPY_DRVSTORE_MATCH "iaStor" "%SRC%\Windows\System32\DriverStore\FileRepository" "%DRVSTORE%"
call :COPY_DRVSTORE_MATCH "vmd"    "%SRC%\Windows\System32\DriverStore\FileRepository" "%DRVSTORE%"
call :COPY_DRVSTORE_MATCH "stornvme" "%SRC%\Windows\System32\DriverStore\FileRepository" "%DRVSTORE%"
call :COPY_DRVSTORE_MATCH "storahci" "%SRC%\Windows\System32\DriverStore\FileRepository" "%DRVSTORE%"

REM --- Cleanup: keep last 10 backups ---
for /f "skip=10 delims=" %%A in ('dir "%DESTROOT%" /b /ad /o-n') do (
  rd /s /q "%DESTROOT%\%%A" >nul 2>&1
)

echo.
echo [DONE] FAST BOOT backup for %SRC% complete.
echo        Folder: "%OUT%"
pause
exit /b 0

REM =========================
REM Helpers
REM =========================
:COPY_FILE
set "SRCFILE=%~1"
set "DSTDIR=%~2"
if exist "%SRCFILE%" (
  copy /y "%SRCFILE%" "%DSTDIR%\" >nul 2>&1
  if errorlevel 1 (
    echo [WARN] Failed to copy: "%SRCFILE%" >> "%LOGS%\fastboot_copy_warnings.txt"
  )
) else (
  echo [WARN] Missing: "%SRCFILE%" >> "%LOGS%\fastboot_missing.txt"
)
exit /b 0

:COPY_DRVSTORE_MATCH
set "NEEDLE=%~1"
set "REPO=%~2"
set "OUTDIR=%~3"
if not exist "%REPO%\" exit /b 0
for /f "delims=" %%D in ('dir /b /ad "%REPO%\*%NEEDLE%*" 2^>nul') do (
  robocopy "%REPO%\%%D" "%OUTDIR%\%%D" /MIR /R:1 /W:1 /XJ >nul
)
exit /b 0

:BACKUP_UEFI
set "MNT="
for %%L in (T U V W X Y Z) do (
  if not exist "%%L:\" (
    set "MNT=%%L:"
    goto :found_uefi_letter
  )
)
:found_uefi_letter
if "%MNT%"=="" (
  echo [ERROR] No free drive letter available to mount EFI.
  exit /b 1
)
mountvol %MNT% /S > "%LOGS%\mountvol_efi.txt" 2>&1
if not exist "%MNT%\EFI\" (
  echo [ERROR] Could not mount EFI partition to %MNT%
  exit /b 1
)
echo [INFO] Backing up EFI from %MNT% ...
robocopy "%MNT%\EFI" "%OUT%\EFI" /MIR /B /R:2 /W:2 /XJ /FFT /COPY:DAT /DCOPY:DAT > "%LOGS%\robocopy_efi.txt"
mountvol %MNT% /D >nul 2>&1
exit /b 0

:BACKUP_LEGACY
echo [INFO] Legacy boot detected - copying Boot folder if present...
if exist "%SRC%\Boot\" (
  robocopy "%SRC%\Boot" "%OUT%\Boot" /MIR /B /R:2 /W:2 /XJ /FFT /COPY:DAT /DCOPY:DAT > "%LOGS%\robocopy_boot.txt"
) else (
  echo [WARN] %SRC%\Boot not found. >> "%LOGS%\legacy_warnings.txt"
)
exit /b 0
