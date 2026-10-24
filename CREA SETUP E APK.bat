@echo off
setlocal
title Niente Zombie Per Favore! - Crea setup Windows e APK Android
cd /d "%~dp0"
echo.
echo NIENTE ZOMBIE PER FAVORE! - BUILD WINDOWS + ANDROID
echo.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\build_release.ps1" %*
set "BUILD_RESULT=%ERRORLEVEL%"
echo.
if not "%BUILD_RESULT%"=="0" echo Build non completata. Controlla l'errore e i log indicati sopra.
if not defined NZPF_BUILD_NO_PAUSE pause
exit /b %BUILD_RESULT%
