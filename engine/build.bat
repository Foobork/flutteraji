@echo off
set CMAKE_PATH="C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"

if not exist "engine\build" (
    echo Creating build directory...
    %CMAKE_PATH% -S engine -B engine/build -A x64
)

echo Building engine...
%CMAKE_PATH% --build engine/build --config Release

if %ERRORLEVEL% EQU 0 (
    echo Build complete.
) else (
    echo Build failed.
    exit /b %ERRORLEVEL%
)
