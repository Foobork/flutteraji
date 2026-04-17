@echo off
REM Build script for Chaturaji engine (MSVC x64)
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat" x64 >nul 2>&1

echo Building CLI binary...
cl /EHsc /O2 /std:c++17 /nologo ^
   /Fe:engine\chaturaji.exe ^
   engine\board.cpp engine\main.cpp ^
   && echo   done: engine\chaturaji.exe
del *.obj >nul 2>&1

echo Building DLL...
cl /EHsc /O2 /std:c++17 /nologo /LD ^
   /DCHATURAJI_BUILD_DLL ^
   /Fe:engine\chaturaji.dll ^
   engine\board.cpp engine\api.cpp ^
   && echo   done: engine\chaturaji.dll
del *.obj *.exp *.lib >nul 2>&1

echo Build complete.
