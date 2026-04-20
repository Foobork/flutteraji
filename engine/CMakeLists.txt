cmake_minimum_required(VERSION 3.10)
project(ChaturajiEngine CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Enable AVX2 and FMA for NNUE
if(MSVC)
    add_compile_options(/arch:AVX2 /O2)
    add_definitions(-D_CRT_SECURE_NO_WARNINGS)
else()
    add_compile_options(-mavx2 -mfma -O3)
endif()

# Shared library for Dart FFI
add_library(chaturaji_engine SHARED api.cpp board.cpp nnue.cpp)

# CLI for testing
add_executable(chaturaji_cli main.cpp board.cpp nnue.cpp)
