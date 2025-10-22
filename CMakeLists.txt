cmake_minimum_required(VERSION 3.15)

project(csad2526ki404nechaibohdan17
    VERSION 0.1.0
    DESCRIPTION "Simple C++ project"
    LANGUAGES CXX
)

# Параметри компілятора
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Додаємо підтримку Google Test
include(FetchContent)
FetchContent_Declare(
    googletest
    URL https://github.com/google/googletest/archive/refs/tags/v1.14.0.zip
)
FetchContent_MakeAvailable(googletest)

# Опціональні прапори для підвищення строгості
if(MSVC)
    target_compile_options(${PROJECT_NAME} PRIVATE /W4 /permissive-)
else()
    add_compile_options(-Wall -Wextra -Wpedantic)
endif()

# Збір джерел
file(GLOB_RECURSE PROJECT_SOURCES CONFIGURE_DEPENDS
    "${CMAKE_SOURCE_DIR}/src/*.cpp"
    "${CMAKE_SOURCE_DIR}/src/*.c"
)

# Якщо немає .cpp файлів — створимо порожню бібліотеку, щоб CMake не впав
if(PROJECT_SOURCES)
    add_library(${PROJECT_NAME} STATIC ${PROJECT_SOURCES})
else()
    add_library(${PROJECT_NAME} INTERFACE)
endif()

target_include_directories(${PROJECT_NAME}
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:include>
)

# Додатковий виконуваний файл, якщо є src/main.cpp
if(EXISTS "${CMAKE_SOURCE_DIR}/src/main.cpp")
    add_executable(${PROJECT_NAME}_app "${CMAKE_SOURCE_DIR}/src/main.cpp")
    target_link_libraries(${PROJECT_NAME}_app PRIVATE ${PROJECT_NAME})
endif()

# Тестування
include(CTest)
option(BUILD_TESTING "Build tests" ON)
if(BUILD_TESTING)
    enable_testing()
    add_subdirectory(tests)
endif()

# Інсталяція (базова)
install(TARGETS ${PROJECT_NAME}
    EXPORT ${PROJECT_NAME}Targets
    ARCHIVE DESTINATION lib
    LIBRARY DESTINATION lib
    RUNTIME DESTINATION bin
)
install(DIRECTORY include/ DESTINATION include)

# Налаштування версії та експорту для find_package()
include(CMakePackageConfigHelpers)
write_basic_package_version_file(
    "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}ConfigVersion.cmake"
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY AnyNewerVersion
)
export(EXPORT ${PROJECT_NAME}Targets FILE "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}Targets.cmake")