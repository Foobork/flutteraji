#!/bin/bash
set -e

# Detect CMake
if ! command -v cmake &> /dev/null; then
    echo "[ERROR] CMake not found in PATH. Please install CMake."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

echo "Configuring engine..."
mkdir -p "$SCRIPT_DIR/build"
cmake -S "$SCRIPT_DIR" -B "$SCRIPT_DIR/build" -DCMAKE_BUILD_TYPE=Release

echo "Building engine (Release)..."
cmake --build "$SCRIPT_DIR/build" --config Release

# Copy outputs to engine/ directory
if [ -f "$SCRIPT_DIR/build/libchaturaji.so" ]; then
    cp -f "$SCRIPT_DIR/build/libchaturaji.so" "$SCRIPT_DIR/libchaturaji.so"
fi
if [ -f "$SCRIPT_DIR/build/libchaturaji.dylib" ]; then
    cp -f "$SCRIPT_DIR/build/libchaturaji.dylib" "$SCRIPT_DIR/libchaturaji.dylib"
fi
if [ -f "$SCRIPT_DIR/build/chaturaji" ]; then
    cp -f "$SCRIPT_DIR/build/chaturaji" "$SCRIPT_DIR/chaturaji"
fi

echo "[SUCCESS] Engine build complete."
