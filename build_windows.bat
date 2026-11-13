@echo off
chcp 65001 > nul
echo ====================================================
echo  Building Rhythm Dungeon Crawler (Windows)
echo ====================================================

if not exist "builds\windows" mkdir "builds\windows"

echo [1/2] Exporting release build via Godot 4.5.1...
"D:\godot\Godot_v4.5.1-stable_win64_console.exe" --headless --export-release "Windows Desktop" "builds\windows\RhythmDungeonCrawler.exe"

if %ERRORLEVEL% equ 0 (
    echo.
    echo ====================================================
    echo  [SUCCESS] Build finished!
    echo  Executable: builds\windows\RhythmDungeonCrawler.exe
    echo ====================================================
) else (
    echo.
    echo [ERROR] Export failed.
)
pause
