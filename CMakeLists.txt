cmake_minimum_required(VERSION 3.30)
project(vhdl_fmt VERSION 0.1.0 DESCRIPTION "A VHDL formatter" LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_CXX_SCAN_FOR_MODULES OFF)
set(CMAKE_VERIFY_INTERFACE_HEADER_SETS ON)
set(CMAKE_COLOR_DIAGNOSTICS ON)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)

# --------------------------------------------------------------------
# Coverage Option
# --------------------------------------------------------------------
option(ENABLE_COVERAGE "Enable code coverage" OFF)

if(ENABLE_COVERAGE)
    if(NOT CMAKE_CXX_COMPILER_ID MATCHES "Clang")
        message(FATAL_ERROR "Coverage is only supported with Clang compiler")
    endif()

    message(STATUS "  Coverage: ENABLED")
    add_compile_options(
        -fprofile-instr-generate
        -fcoverage-mapping
    )
    add_link_options(
        -fprofile-instr-generate
        -fcoverage-mapping
    )
endif()

message(STATUS "Project: ${PROJECT_NAME}")
message(STATUS "  Version:  ${PROJECT_VERSION}")
message(STATUS "  Build:    ${CMAKE_BUILD_TYPE}")
message(
    STATUS
    "  Compiler: ${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION}"
)
message(STATUS "  Standard: C++${CMAKE_CXX_STANDARD}")

# Enable ccache for faster rebuilds if available
find_program(CCACHE_PROGRAM ccache)
if(CCACHE_PROGRAM)
    # Keep ccache inside the build tree to avoid permission issues in locked-down environments
    set(CCACHE_DIR ${CMAKE_BINARY_DIR}/.ccache)
    set(CCACHE_TEMPDIR ${CCACHE_DIR}/tmp)
    file(MAKE_DIRECTORY ${CCACHE_DIR})
    file(MAKE_DIRECTORY ${CCACHE_TEMPDIR})
    message(STATUS "  ccache:   ${CCACHE_PROGRAM}")
    message(STATUS "  ccache dir: ${CCACHE_DIR}")
    set(CMAKE_CXX_COMPILER_LAUNCHER
        "${CMAKE_COMMAND};-E;env;CCACHE_DIR=${CCACHE_DIR};CCACHE_TEMPDIR=${CCACHE_TEMPDIR};${CCACHE_PROGRAM}"
    )
endif()

find_package(antlr4-runtime CONFIG REQUIRED)
find_package(argparse REQUIRED)
find_package(yaml-cpp REQUIRED)
find_package(fmt CONFIG REQUIRED)
find_package(spdlog CONFIG REQUIRED)
find_package(Catch2 CONFIG REQUIRED)

# --------------------------------------------------------------------
# ANTLR Generation
# --------------------------------------------------------------------
set(GRAMMAR_DIR ${CMAKE_SOURCE_DIR}/grammars)
set(GENERATED_DIR ${CMAKE_BINARY_DIR}/generated)
set(GRAMMAR_FILES
    ${GRAMMAR_DIR}/vhdlLexer.g4
    ${GRAMMAR_DIR}/vhdlParser.g4
)

find_program(ANTLR4_EXECUTABLE antlr4 REQUIRED)

add_custom_command(
    OUTPUT
        ${GENERATED_DIR}/vhdlLexer.cpp
        ${GENERATED_DIR}/vhdlLexer.h
        ${GENERATED_DIR}/vhdlParser.cpp
        ${GENERATED_DIR}/vhdlParser.h
        ${GENERATED_DIR}/vhdlLexer.tokens
        ${GENERATED_DIR}/vhdlParser.tokens
    COMMAND
        ${CMAKE_COMMAND} -E make_directory ${GENERATED_DIR}
    COMMAND
        ${ANTLR4_EXECUTABLE} -Dlanguage=Cpp ${GRAMMAR_FILES} -lib ${GRAMMAR_DIR}
        -o ${GENERATED_DIR} -no-listener
    DEPENDS
        ${GRAMMAR_FILES}
    COMMENT "Generating VHDL lexer and parser using ANTLR4"
    VERBATIM
)

add_library(
    vhdl_generated
    STATIC
    ${GENERATED_DIR}/vhdlLexer.cpp
    ${GENERATED_DIR}/vhdlParser.cpp
)

set_source_files_properties(
    ${GENERATED_DIR}/vhdlLexer.cpp
    ${GENERATED_DIR}/vhdlParser.cpp
    PROPERTIES
        GENERATED
            TRUE
)

target_include_directories(vhdl_generated SYSTEM PUBLIC ${GENERATED_DIR})
target_link_libraries(vhdl_generated PUBLIC antlr4_static)

# --------------------------------------------------------------------
# Version Header Generation
# --------------------------------------------------------------------
set(VERSION_IN_FILE "${CMAKE_SOURCE_DIR}/src/common/version.hpp.in")
set(VERSION_OUT_FILE "${CMAKE_BINARY_DIR}/generated/version.hpp")

file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/generated")
configure_file(${VERSION_IN_FILE} ${VERSION_OUT_FILE} @ONLY)

# --------------------------------------------------------------------
# Project subdirs
# --------------------------------------------------------------------
add_subdirectory(src)

enable_testing()
add_subdirectory(tests)

# --------------------------------------------------------------------
# Coverage Targets
# --------------------------------------------------------------------
if(ENABLE_COVERAGE)
    find_program(LLVM_PROFDATA llvm-profdata REQUIRED)
    find_program(LLVM_COV llvm-cov REQUIRED)

    message(STATUS "  llvm-profdata: ${LLVM_PROFDATA}")
    message(STATUS "  llvm-cov: ${LLVM_COV}")

    set(COVERAGE_DIR ${CMAKE_BINARY_DIR}/coverage)
    set(PROFRAW_PATTERN ${COVERAGE_DIR}/vhdl_fmt-%p.profraw)
    set(PROFDATA_FILE ${COVERAGE_DIR}/vhdl_fmt.profdata)
    set(TARGET_BINARY ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/vhdl_formatter)
    set(COVERAGE_SOURCES ${CMAKE_SOURCE_DIR}/src/)
    set(IGNORE_REGEX "'(${CMAKE_BINARY_DIR}|/tests/)'")

    # Collect coverage data by running tests
    add_custom_target(
        coverage-data
        COMMAND
            ${CMAKE_COMMAND} -E rm -rf ${COVERAGE_DIR}
        COMMAND
            ${CMAKE_COMMAND} -E make_directory ${COVERAGE_DIR}
        COMMAND
            ${CMAKE_COMMAND} -E echo "Running tests with coverage..."
        COMMAND
            ${CMAKE_COMMAND} -E env LLVM_PROFILE_FILE=${PROFRAW_PATTERN}
            ${CMAKE_CTEST_COMMAND} --test-dir ${CMAKE_BINARY_DIR}
            --output-on-failure
        COMMAND
            ${CMAKE_COMMAND} -E echo "Merging coverage data..."
        COMMAND
            sh -c
            "${LLVM_PROFDATA} merge -sparse ${COVERAGE_DIR}/*.profraw -o ${PROFDATA_FILE}"
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        COMMENT "Collecting coverage data from tests"
    )

    # HTML report (for local development)
    add_custom_target(
        coverage
        COMMAND
            ${CMAKE_COMMAND} -E echo "Generating HTML coverage report..."
        COMMAND
            ${LLVM_COV} show ${TARGET_BINARY} -instr-profile=${PROFDATA_FILE}
            -ignore-filename-regex=${IGNORE_REGEX} -format=html
            -output-dir=${COVERAGE_DIR}/html ${COVERAGE_SOURCES}
        COMMAND
            ${CMAKE_COMMAND} -E echo "Coverage: ${COVERAGE_DIR}/html/index.html"
        DEPENDS
            coverage-data
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        COMMENT "Generating HTML coverage report"
    )

    # Text summary (for CI)
    add_custom_target(
        coverage-report
        COMMAND
            ${CMAKE_COMMAND} -E echo "Generating coverage summary..."
        COMMAND
            ${LLVM_COV} report ${TARGET_BINARY} -instr-profile=${PROFDATA_FILE}
            -ignore-filename-regex=${IGNORE_REGEX} -show-region-summary=false
            ${COVERAGE_SOURCES} | tee ${COVERAGE_DIR}/coverage.txt
        DEPENDS
            coverage-data
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        COMMENT "Generating text coverage summary"
    )

    # Clean coverage data
    add_custom_target(
        coverage-clean
        COMMAND
            ${CMAKE_COMMAND} -E rm -rf ${COVERAGE_DIR}
        COMMAND
            ${CMAKE_COMMAND} -E echo "Coverage data cleaned"
        COMMENT "Cleaning coverage data"
    )
endif()
