# tests/benchmarks/CMakeLists.txt

add_executable(vhdl_benchmarks benchmarks.cpp)

# 1. Link Dependencies
target_link_libraries(
    vhdl_benchmarks
    PRIVATE
        Catch2::Catch2WithMain
        builder
        emit
        ast
        cli
        vhdl_generated
        antlr4_static
)

# 2. Include Directories
target_include_directories(
    vhdl_benchmarks
    PRIVATE
        ${CMAKE_SOURCE_DIR}/src
        ${GENERATED_DIR}
)

# 3. Compile Options
# Ensure we match the Release optimizations of the main app for accurate timing
target_compile_options(
    vhdl_benchmarks
    PRIVATE
        $<$<CONFIG:Release>:-O3>
        -Wall
        -Wextra
)

# 4. Register with CTest
catch_discover_tests(vhdl_benchmarks
    PROPERTIES
        LABELS "benchmark"
)
