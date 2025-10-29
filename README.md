# C++ Project with Google Test

## Prerequisites
- CMake 3.15 or higher
- C++ compiler with C++17 support
- Git
- Visual Studio 2019 or higher (for Windows)

## Project Structure
```
csad2526ki404nechaibohdan17/
├── include/
├── src/
├── tests/
│   ├── CMakeLists.txt
│   └── unit_tests.cpp
├── CMakeLists.txt
└── README.md
```

## Building the Project

### Windows (Using Visual Studio Command Prompt)
```powershell
# Create build directory
mkdir build
cd build

# Configure CMake
cmake ..

# Build
cmake --build . --config Debug

# Run tests
ctest -C Debug --output-on-failure
```

### Running Tests Directly
```powershell
.\build\tests\Debug\unit_tests.exe
```

## VS Code Setup
1. Install required extensions:
   - C/C++
   - CMake Tools
   - C/C++ Test Mate

2. Configure test discovery in `.vscode/settings.json`:
```json
{
    "testMate.cpp.test.executables": "build/tests/**/*{test,Test}*"
}
```

## Development
- Main source files go in `src/`
- Header files go in `include/`
- Unit tests go in `tests/`
- Build system configuration is in `CMakeLists.txt`

## Testing
The project uses Google Test framework. Test files are in the `tests/` directory.
New tests can be added by creating new test cases in `unit_tests.cpp`.
