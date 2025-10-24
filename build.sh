#!/usr/bin/env bash
# build.sh — simple Unix build helper (Linux/macOS)
# Usage: ./build.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG="$REPO_DIR/build_unix.log"
echo "==== BUILD started: $(date) ====" > "$LOG"

command -v cmake >/dev/null 2>&1 || { echo "ERROR: cmake not found" | tee -a "$LOG"; exit 1; }

mkdir -p "$REPO_DIR/build"
cd "$REPO_DIR/build"

echo "--- cmake .. ---" | tee -a "$LOG"
cmake .. >> "$LOG" 2>&1 || { echo "cmake configure failed, see $LOG" | tee -a "$LOG"; exit 1; }

echo "--- cmake --build . ---" | tee -a "$LOG"
cmake --build . >> "$LOG" 2>&1 || { echo "build failed, see $LOG" | tee -a "$LOG"; exit 1; }

echo "--- check hello executable ---" | tee -a "$LOG"
HELLO_PATH=$(find . -type f \( -name 'hello' -o -name 'hello.exe' \) -print -quit || true)
if [ -z "$HELLO_PATH" ]; then
  echo "ERROR: hello executable not found under build/ (see $LOG)" | tee -a "$LOG"
  exit 2
fi

echo "Found executable: $HELLO_PATH" | tee -a "$LOG"
echo "=== SUCCESS: build produced hello ===" | tee -a "$LOG"

# Ensure build.sh is executable and commit the change if desired
chmod +x "$REPO_DIR/build.sh" 2>/dev/null || true
if command -v git >/dev/null 2>&1; then
  git -C "$REPO_DIR" add build.sh >/dev/null 2>&1 || true
  git -C "$REPO_DIR" commit -m "Make build.sh executable" >/dev/null 2>&1 || true
fi

echo "Log: $LOG"