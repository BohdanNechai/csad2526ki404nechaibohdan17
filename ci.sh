#!/usr/bin/env bash
# ci.sh — wrapper for Unix-like local CI: creates build dir, runs cmake, builds, runs ctest.
# Usage: ./ci.sh   (no parameters)
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG="$REPO_DIR/ci_unix.log"
echo "==== CI run started: $(date) ====" > "$LOG"

command -v cmake >/dev/null 2>&1 || { echo "ERROR: cmake not found" | tee -a "$LOG"; exit 1; }
command -v ctest >/dev/null 2>&1 || echo "Warning: ctest not found; tests will be skipped" | tee -a "$LOG"

mkdir -p "$REPO_DIR/build"
cd "$REPO_DIR/build"

echo "--- Configure (cmake ..) ---" | tee -a "$LOG"
if ! cmake .. >> "$LOG" 2>&1; then
  echo "ERROR: cmake configure failed; see $LOG" | tee -a "$LOG"
  exit 1
fi

echo "--- Build (cmake --build .) ---" | tee -a "$LOG"
if ! cmake --build . >> "$LOG" 2>&1; then
  echo "ERROR: build failed; see $LOG" | tee -a "$LOG"
  exit 1
fi

echo "--- Run tests (ctest) if available ---" | tee -a "$LOG"
if command -v ctest >/dev/null 2>&1; then
  if ! ctest --output-on-failure >> "$LOG" 2>&1; then
    echo "ERROR: some tests failed or no tests were found; see $LOG" | tee -a "$LOG"
    exit 1
  fi
else
  echo "ctest not found; skipping tests" | tee -a "$LOG"
fi

# Check for hello executable (search recursively under build)
echo "--- Verify hello exists ---" | tee -a "$LOG"
HELLO_PATH=$(find . -type f \( -name 'hello' -o -name 'hello.exe' \) -print -quit || true)
if [ -z "$HELLO_PATH" ]; then
  echo "ERROR: hello executable not found" | tee -a "$LOG"
  exit 2
fi

echo "Found executable: $HELLO_PATH" | tee -a "$LOG"
echo "=== SUCCESS: build and tests OK ===" | tee -a "$LOG"

# Ensure build.sh is executable and commit
chmod +x "$REPO_DIR/build.sh" 2>/dev/null || true
if command -v git >/dev/null 2>&1; then
  git -C "$REPO_DIR" add build.sh >/dev/null 2>&1 || true
  git -C "$REPO_DIR" commit -m "Ensure build.sh executable" >/dev/null 2>&1 || true
fi

echo "Log: $LOG"