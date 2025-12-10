add_executable(
    emit_tests
    pretty_printer/test_doc.cpp
    pretty_printer/test_trivia.cpp
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
    #
    # Expressions
    pretty_printer/nodes/expressions/test_attribute.cpp
    pretty_printer/nodes/expressions/test_binary.cpp
    pretty_printer/nodes/expressions/test_call.cpp
    pretty_printer/nodes/expressions/test_group.cpp
    pretty_printer/nodes/expressions/test_paren.cpp
    pretty_printer/nodes/expressions/test_physical.cpp
    pretty_printer/nodes/expressions/test_qualified.cpp
    pretty_printer/nodes/expressions/test_slice.cpp
    pretty_printer/nodes/expressions/test_token.cpp
    pretty_printer/nodes/expressions/test_unary.cpp
    #
    # Types
    pretty_printer/nodes/type/test_access.cpp
    pretty_printer/nodes/type/test_array.cpp
    pretty_printer/nodes/type/test_enumeration.cpp
    pretty_printer/nodes/type/test_file.cpp
    pretty_printer/nodes/type/test_incomplete.cpp
    pretty_printer/nodes/type/test_record.cpp
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
