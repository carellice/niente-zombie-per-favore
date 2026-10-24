@echo off
setlocal
cd /d "%~dp0"
if exist "%~dp0builds\Niente Zombie Per Favore.exe" (
    start "" "%~dp0builds\Niente Zombie Per Favore.exe"
    exit /b 0
)
if exist "%~dp0tools\godot\Godot_v4.5.1-stable_win64.exe" (
    start "" "%~dp0tools\godot\Godot_v4.5.1-stable_win64.exe" --path "%~dp0."
    exit /b 0
)
echo Eseguibile non trovato. Apri project.godot con Godot 4.5 o successivo.
pause
