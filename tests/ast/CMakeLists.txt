# AST Node Tests - Simplified with automatic test discovery

# Get all test files from subdirectories
file(
    GLOB_RECURSE TEST_FILES
    RELATIVE ${CMAKE_CURRENT_SOURCE_DIR}
    "nodes/*/*.cpp"
)

# Create one test executable per file
foreach(TEST_FILE ${TEST_FILES})
    # Extract test name from filename: nodes/design_units/test_entity.cpp -> test_entity
    get_filename_component(TEST_NAME ${TEST_FILE} NAME_WE)

    # Create executable
    add_executable(${TEST_NAME} ${TEST_FILE})

    # Link libraries
    target_link_libraries(
        ${TEST_NAME}
        PRIVATE
            ast
            builder
            Catch2::Catch2WithMain
    )

    # Register with CTest
    add_test(NAME ${TEST_NAME} COMMAND ${TEST_NAME})
endforeach()

# Optional: Print discovered tests during configuration
message(STATUS "Discovered ${CMAKE_MATCH_COUNT} AST test files")
