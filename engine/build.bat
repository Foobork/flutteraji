@echo off
REM Build script for Chaturaji engine (MSVC x86)
call "C:\Program Files (x86)\Microsoft Visual Studio\2017\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" x86 >nul 2>&1

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
