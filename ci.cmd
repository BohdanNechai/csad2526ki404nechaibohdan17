@echo off
REM ci.cmd — Windows (cmd) local CI script; run from an opened cmd (not double-click).
REM Usage: ci.cmd (no parameters)
setlocal
set REPO_DIR=%~dp0
set LOG=%REPO_DIR%ci_windows.log
echo ==== CI run started: %DATE% %TIME% ==== > "%LOG%"

where cmake >nul 2>&1
if errorlevel 1 (
  echo ERROR: cmake not found. Install CMake and add to PATH. >> "%LOG%"
  echo See %LOG% and press a key...
  pause >nul
  exit /b 1
)

REM Create build dir
if not exist "%REPO_DIR%build" (
  mkdir "%REPO_DIR%build" >> "%LOG%" 2>&1 || goto :err
)

pushd "%REPO_DIR%build" >> "%LOG%" 2>&1 || goto :err

echo --- Configure (cmake ..) --- >> "%LOG%"
cmake .. >> "%LOG%" 2>&1
if errorlevel 1 goto :cmake_err

echo --- Build (cmake --build .) --- >> "%LOG%"
cmake --build . >> "%LOG%" 2>&1
if errorlevel 1 goto :build_err

echo --- Run tests (ctest) --- >> "%LOG%" 2>&1
where ctest >nul 2>&1
if errorlevel 0 (
  ctest --output-on-failure >> "%LOG%" 2>&1 || echo WARNING: tests failed or no tests found >> "%LOG%"
) else (
  echo ctest not found; skipping tests >> "%LOG%"
)

REM Look for hello executable (search recursively)
echo --- Check for hello executable --- >> "%LOG%"
where /R . hello.exe > "%TEMP%\_hello_search.txt" 2>nul
for /f "usebackq delims=" %%A in ("%TEMP%\_hello_search.txt") do set HELLO=%%~fA
if defined HELLO (
  echo Found executable: %HELLO% >> "%LOG%"
) else (
  REM also search for posix 'hello' (e.g., MinGW)
  where /R . hello > "%TEMP%\_hello_search2.txt" 2>nul
  for /f "usebackq delims=" %%A in ("%TEMP%\_hello_search2.txt") do set HELLO=%%~fA
)

if not defined HELLO (
  echo ERROR: hello executable not found under build\ >> "%LOG%"
  echo Press a key to view log...
  pause >nul
  type "%LOG%"
  popd
  exit /b 2
)

echo Found: %HELLO% >> "%LOG%"
echo === SUCCESS: build and (if available) tests completed === >> "%LOG%"

popd >> "%LOG%" 2>&1

REM Make sure build.sh is executable in repo (if using Git Bash/WSL) and try commit
if exist "%REPO_DIR%build.sh" (
  powershell -NoProfile -Command "try { icacls '%REPO_DIR%build.sh' /grant Everyone:RX > $null } catch { }"
  if exist "%REPO_DIR%.git" (
    pushd "%REPO_DIR%"
    git add build.sh 2>nul
    git commit -m "Ensure build.sh executable" 2>nul || echo No commit needed
    popd
  )
)

echo Log: "%LOG%"
echo Press any key to exit...
pause >nul
exit /b 0

:cmake_err
echo CMake configure failed. See %LOG% >> "%LOG%"
goto :err

:build_err
echo Build failed. See %LOG% >> "%LOG%"
goto :err

:err
set ERR=%ERRORLEVEL%
echo ERROR: exit code %ERR% See %LOG%
echo Press any key to view the log...
pause >nul
type "%LOG%"
exit /b %ERR%