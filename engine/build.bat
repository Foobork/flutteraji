@echo off
REM Build script for Chaturaji engine (MSVC)
call "C:\Program Files (x86)\Microsoft Visual Studio\2017\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" x86 >nul 2>&1
cl /EHsc /O2 /std:c++17 /Fe:engine\chaturaji.exe engine\board.cpp engine\main.cpp /nologo
del *.obj >nul 2>&1
