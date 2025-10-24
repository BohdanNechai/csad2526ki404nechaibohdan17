#!/usr/bin/env bash
set -euo pipefail

# Build and test helper for Unix-like systems (Linux, macOS)
# Usage: ./build.sh

mkdir -p build
cd build

# Configure
cmake ..

# Build
cmake --build .

# Run tests (CTest)
ctest --output-on-failure

cd ..