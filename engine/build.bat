@echo off
setlocal enabledelayedexpansion

:: 1. Check if cmake is in PATH
where cmake >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    set "CMAKE_EXE=cmake"
    goto :FoundCMake
)

:: 2. Check common Visual Studio and CMake installation locations
set "CANDIDATES[0]=%ProgramFiles%\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
set "CANDIDATES[1]=%ProgramFiles%\Microsoft Visual Studio\2022\Professional\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
set "CANDIDATES[2]=%ProgramFiles%\Microsoft Visual Studio\2022\Enterprise\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
set "CANDIDATES[3]=%ProgramFiles%\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
set "CANDIDATES[4]=%ProgramFiles(x86)%\Microsoft Visual Studio\2019\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
set "CANDIDATES[5]=%ProgramFiles(x86)%\Microsoft Visual Studio\2019\Professional\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
set "CANDIDATES[6]=%ProgramFiles(x86)%\Microsoft Visual Studio\2019\Enterprise\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
set "CANDIDATES[7]=%ProgramFiles(x86)%\Microsoft Visual Studio\2019\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
set "CANDIDATES[8]=%ProgramFiles%\CMake\bin\cmake.exe"

for /L %%i in (0,1,8) do (
    if exist "!CANDIDATES[%%i]!" (
        set "CMAKE_EXE=!CANDIDATES[%%i]!"
        goto :FoundCMake
    )
)

echo [ERROR] CMake not found. Please install CMake or Visual Studio with C++ CMake tools, or add cmake to your PATH.
exit /b 1

:FoundCMake
echo Found CMake: "!CMAKE_EXE!"

if not exist "engine\build" (
    echo Creating build configuration...
    "!CMAKE_EXE!" -S engine -B engine/build -A x64
    if !ERRORLEVEL! NEQ 0 (
        echo [ERROR] CMake configure failed.
        exit /b !ERRORLEVEL!
    )
)

echo Building engine (Release)...
"!CMAKE_EXE!" --build engine/build --config Release
if !ERRORLEVEL! NEQ 0 (
    echo [ERROR] Build failed.
    exit /b !ERRORLEVEL!
)

:: Copy artifacts to engine/ directory for easy runtime access
if exist "engine\build\Release\chaturaji.dll" copy /Y "engine\build\Release\chaturaji.dll" "engine\chaturaji.dll" >nul
if exist "engine\build\Release\chaturaji_engine.dll" copy /Y "engine\build\Release\chaturaji_engine.dll" "engine\chaturaji.dll" >nul
if exist "engine\build\Release\chaturaji.exe" copy /Y "engine\build\Release\chaturaji.exe" "engine\chaturaji.exe" >nul
if exist "engine\build\Release\chaturaji_cli.exe" copy /Y "engine\build\Release\chaturaji_cli.exe" "engine\chaturaji.exe" >nul

echo [SUCCESS] Engine build complete:
echo   - Shared library: engine\chaturaji.dll
echo   - CLI binary:     engine\chaturaji.exe
