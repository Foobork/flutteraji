cmake_minimum_required(VERSION 3.10)
project(ChaturajiEngine LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Optimization flags for MSVC
if(MSVC)
    add_compile_options(/W3 /O2 /nologo /EHsc)
    # Optional: AVX2 for NNUE performance boost
    # add_compile_options(/arch:AVX2)
endif()

# CLI Executable
# main.cpp includes api.cpp directly, so we only need to list board.cpp and main.cpp
add_executable(chaturaji_cli 
    board.cpp 
    main.cpp
)
set_target_properties(chaturaji_cli PROPERTIES OUTPUT_NAME "chaturaji")

# Shared Library for Flutter FFI
add_library(chaturaji_lib SHARED 
    board.cpp 
    api.cpp
)
target_compile_definitions(chaturaji_lib PRIVATE CHATURAJI_BUILD_DLL)
set_target_properties(chaturaji_lib PROPERTIES OUTPUT_NAME "chaturaji")

# Ensure artifacts are placed directly in the engine/ folder (matches previous build behavior)
# We set per-configuration properties to avoid MSVC's default subfolder behavior
foreach(OUTPUTCONFIG ${CMAKE_CONFIGURATION_TYPES})
    string(TOUPPER ${OUTPUTCONFIG} OUTPUTCONFIG_UPPER)
    set_target_properties(chaturaji_cli chaturaji_lib PROPERTIES 
        RUNTIME_OUTPUT_DIRECTORY_${OUTPUTCONFIG_UPPER} "${CMAKE_CURRENT_SOURCE_DIR}"
        LIBRARY_OUTPUT_DIRECTORY_${OUTPUTCONFIG_UPPER} "${CMAKE_CURRENT_SOURCE_DIR}"
        ARCHIVE_OUTPUT_DIRECTORY_${OUTPUTCONFIG_UPPER} "${CMAKE_CURRENT_SOURCE_DIR}"
    )
endforeach()
