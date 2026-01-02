@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ======================================================
REM MIRACLE BOOT RESTORE - FAST BOOT IMAGE (V7)
REM - Restores EFI + rebuilds BCD + optionally restores boot-critical payload
REM - Does NOT wipe Users / Program Files / data
REM - Best run from WinRE / Install USB Command Prompt
REM ======================================================

echo ======================================================
echo MIRACLE BOOT RESTORE - FAST BOOT IMAGE (V7)
echo ======================================================

REM --- Destination root ---
set "DESTROOT=G:\MIRACLE_BOOT_FIXER"
if not exist "%DESTROOT%\" (
  echo [ERROR] Backup root not found: %DESTROOT%
  echo         Connect the backup drive (expected G:) or edit DESTROOT.
  pause
  exit /b 1
)

REM --- Manual Drive Selection ---
echo [LIST] Windows installations detected:
for %%D in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
  if exist "%%D:\Windows\System32\config\SYSTEM" (
    echo   - %%D:
  )
)
echo.
set /p "TARGET_DRIVE=Which drive letter do you want to fix? (Enter letter only, e.g. E): "
if "%TARGET_DRIVE%"=="" (
  echo [ERROR] No drive provided.
  pause & exit /b 1
)

set "TARGET_DRIVE=%TARGET_DRIVE: =%"
set "TARGET_DRIVE=%TARGET_DRIVE::=%"
set "WIN=%TARGET_DRIVE%:"

if not exist "%WIN%\Windows\System32\config\SYSTEM" (
  echo [ERROR] No valid Windows installation found on %WIN%.
  pause & exit /b 1
)

echo [OK] Target confirmed: %WIN%

REM --- Setup mount letter for EFI ---
set "MNT="
for %%L in (S T U V W X Y Z) do (
  if not exist "%%L:\" (
    set "MNT=%%L:"
    goto :got_mnt
  )
)
:got_mnt
if "%MNT%"=="" (
  echo [ERROR] No free drive letter available to mount EFI.
  pause & exit /b 1
)

REM --- Gather top 3 recent backups (newest first) ---
echo [INFO] Searching for the 3 most recent backups...
set "count=0"
for /f "delims=" %%D in ('dir /b /ad /o-n "%DESTROOT%" 2^>nul') do (
  set /a count+=1
  set "backup[!count!]=%%D"
  if !count! GEQ 3 goto :found_backups
)
:found_backups

if %count% EQU 0 (
  echo [ERROR] No backup folders found.
  pause & exit /b 1
)

REM --- Ask whether to restore fast-boot payload ---
set "RESTORE_PAYLOAD=y"
echo.
set /p "RESTORE_PAYLOAD=Restore boot-critical payload (registry/boot drivers) too? (y/n) [y]: "
if "%RESTORE_PAYLOAD%"=="" set "RESTORE_PAYLOAD=y"

REM --- Restore Loop ---
for /l %%i in (1,1,%count%) do (
  set "CURRENT_BACKUP=!backup[%%i]!"
  set "BACKUP_PATH=%DESTROOT%\!CURRENT_BACKUP!"

  echo.
  echo ------------------------------------------------------
  echo ATTEMPT %%i: !CURRENT_BACKUP!
  echo ------------------------------------------------------

  REM 1) Mount EFI
  mountvol %MNT% /S >nul 2>&1
  if not exist "%MNT%\EFI\" (
    echo [ERROR] Could not mount EFI partition to %MNT%.
    goto :next_attempt
  )

  REM 2) Restore EFI files (if present)
  if exist "!BACKUP_PATH!\EFI\" (
    echo [INFO] Restoring EFI files...
    robocopy "!BACKUP_PATH!\EFI" "%MNT%\EFI" /MIR /B /R:1 /W:1 >nul
  ) else (
    echo [WARN] Backup has no EFI folder.
  )

  REM 3) Rebuild bootloader specifically for target Windows
  echo [INFO] Rebuilding boot entries for %WIN% ...
  bcdboot "%WIN%\Windows" /s %MNT% /f UEFI >nul 2>&1

  if NOT errorlevel 1 (
    echo [SUCCESS] EFI boot entries rebuilt.

    REM 4) Optional: restore payload (copy-only; no deletes)
    if /i "!RESTORE_PAYLOAD!"=="y" (
      call :RESTORE_FASTBOOT_PAYLOAD "!BACKUP_PATH!" "%WIN%"
    )

    mountvol %MNT% /D >nul 2>&1
    echo [DONE] Restore attempt succeeded using "!CURRENT_BACKUP!".
    pause
    exit /b 0
  )

  :next_attempt
  mountvol %MNT% /D >nul 2>&1
)

echo.
echo [FATAL] All available backups failed to restore.
pause
exit /b 1

REM =========================
REM Payload restore helper
REM =========================
:RESTORE_FASTBOOT_PAYLOAD
set "BP=%~1"
set "WD=%~2"

if not exist "%BP%\WIN_BOOT\" (
  echo [WARN] No WIN_BOOT payload found in this backup.
  exit /b 0
)

echo [INFO] Restoring boot-critical payload (copy-only; no user data touched)...

REM Restore core files
if exist "%BP%\WIN_BOOT\CORE_FILES\" (
  robocopy "%BP%\WIN_BOOT\CORE_FILES" "%WD%\Windows\System32" /E /R:1 /W:1 /NFL /NDL >nul
)

REM Restore core drivers
if exist "%BP%\WIN_BOOT\CORE_DRIVERS\" (
  robocopy "%BP%\WIN_BOOT\CORE_DRIVERS" "%WD%\Windows\System32\drivers" /E /R:1 /W:1 /NFL /NDL >nul
)

REM Restore storage-related DriverStore packages (copy-only)
if exist "%BP%\WIN_BOOT\DRIVERSTORE_STORAGE\" (
  if not exist "%WD%\Windows\System32\DriverStore\FileRepository\" (
    echo [WARN] Target DriverStore not found. Skipping DriverStore package restore.
  ) else (
    robocopy "%BP%\WIN_BOOT\DRIVERSTORE_STORAGE" "%WD%\Windows\System32\DriverStore\FileRepository" /E /R:1 /W:1 /NFL /NDL >nul
  )
)

REM Registry hives: only safe when target is offline
REM If user is running this inside full Windows on the same system drive, do NOT overwrite hives.
if /i "%WD%"=="%SystemDrive%" (
  echo [WARN] Target appears to be the LIVE OS (%SystemDrive%). Skipping hive restore to avoid bricking.
  echo        If you need hive restore, run this script from WinRE/USB where target is offline.
  exit /b 0
)

if exist "%BP%\WIN_BOOT\HIVES\SYSTEM" (
  echo [INFO] Restoring registry hives (offline only)...
  for %%H in (SYSTEM SOFTWARE SAM SECURITY DEFAULT) do (
    if exist "%BP%\WIN_BOOT\HIVES\%%H" (
      if exist "%WD%\Windows\System32\config\%%H" (
        copy /y "%WD%\Windows\System32\config\%%H" "%WD%\Windows\System32\config\%%H.bak" >nul 2>&1
      )
      copy /y "%BP%\WIN_BOOT\HIVES\%%H" "%WD%\Windows\System32\config\%%H" >nul 2>&1
    )
  )
) else (
  echo [WARN] Hive payload not present.
)

echo [INFO] Payload restore step finished.
exit /b 0
