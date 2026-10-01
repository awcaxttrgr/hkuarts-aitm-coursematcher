@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0append_course_data.ps1"
if errorlevel 1 (
    echo.
    echo Import failed. The JSON file was not updated.
) else (
    echo.
    echo Import complete.
)
pause