@echo off
setlocal enabledelayedexpansion

pushd "%~dp0"
if errorlevel 1 (
    echo [ERROR] Could not access the script directory.
    exit /b 1
)

:: ----------------------------------------------------------------------
:: Configuration
:: ----------------------------------------------------------------------
set "MAX_SIZE=2048"

:: Verify ImageMagick installation
where.exe magick >nul 2>&1
if errorlevel 1 (
    echo [ERROR] ImageMagick command magick was not found in your system PATH.
    echo Please install ImageMagick 7+ and ensure "Add to PATH" is checked.
    popd
    pause
    exit /b 1
)

echo ======================================================================
echo  Resizing ^& Maximum Compression for PNGs (Max: %MAX_SIZE%px)
echo  Current directory only (subdirectories excluded)
echo ======================================================================
echo.

set /a COUNT=0
set /a FAILED=0

for %%F in (*.png) do (
    set /a COUNT+=1
    echo Compressing: "%%~nxF"

    magick "%%~nxF" ^
        -resize "%MAX_SIZE%x%MAX_SIZE%>" ^
        -strip ^
        -depth 8 ^
        -define png:exclude-chunks=all ^
        -define png:compression-filter=5 ^
        -define png:compression-level=9 ^
        -define png:compression-strategy=1 ^
        -quality 95 ^
        "%%~nxF"
    if errorlevel 1 (
        echo [ERROR] Failed to process "%%~nxF".
        set /a FAILED+=1
    )
)

echo.
if !COUNT! equ 0 (
    echo No PNG files found in the current directory.
) else (
    if !FAILED! neq 0 (
        echo Completed with !FAILED! failures out of !COUNT! images.
    ) else (
        echo Done. Processed and compressed !COUNT! images.
    )
)

popd
pause