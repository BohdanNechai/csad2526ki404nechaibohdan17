cmake_minimum_required(VERSION 3.16)
project(hello VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Optional: avoid FetchContent CMP0135 warning if used later
if(POLICY CMP0135)
  cmake_policy(SET CMP0135 NEW)
endif()

# Sources — minimal single executable called "hello"
file(GLOB_RECURSE PROJECT_SOURCES CONFIGURE_DEPENDS
  "${CMAKE_SOURCE_DIR}/src/*.cpp"
  "${CMAKE_SOURCE_DIR}/src/*.c"
)

if(NOT PROJECT_SOURCES)
  message(WARNING "No sources found in src/. Please add source files (e.g. src/main.cpp).")
endif()

add_executable(hello ${PROJECT_SOURCES})

# Provide include dir if you have headers in include/
target_include_directories(hello PUBLIC "${CMAKE_SOURCE_DIR}/include")

# Enable testing if tests exist
include(CTest)
if(EXISTS "${CMAKE_SOURCE_DIR}/tests/CMakeLists.txt")
  enable_testing()
  add_subdirectory(tests)
else()
  message(STATUS "No tests directory with CMakeLists.txt found; skipping tests.")
endif()