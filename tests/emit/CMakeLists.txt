add_executable(
    emit_tests
    pretty_printer/test_doc.cpp
    pretty_printer/test_trivia.cpp
    pretty_printer/test_optimizer.cpp
    pretty_printer/nodes/test_declarations.cpp
    pretty_printer/nodes/test_clauses.cpp
    pretty_printer/nodes/test_component.cpp
    pretty_printer/nodes/test_context_clauses.cpp
    pretty_printer/nodes/test_control_flow.cpp
    pretty_printer/nodes/test_design_units.cpp
    pretty_printer/nodes/test_design_file.cpp
    pretty_printer/nodes/test_waveforms.cpp
    pretty_printer/nodes/test_process.cpp
    pretty_printer/nodes/test_assignments.cpp
)

target_link_libraries(
    emit_tests
    PRIVATE
        Catch2::Catch2WithMain
        emit
)

target_include_directories(
    emit_tests
    PRIVATE
        ${CMAKE_SOURCE_DIR}/src
        ${CMAKE_SOURCE_DIR}/tests
        ${GENERATED_DIR}
)

# Macro for test data directory
target_compile_definitions(
    emit_tests
    PRIVATE
        TEST_DATA_DIR="${CMAKE_BINARY_DIR}/tests/data"
)

catch_discover_tests(emit_tests)
