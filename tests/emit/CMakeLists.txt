add_executable(
    emit_tests
    pretty_printer/test_doc.cpp
    pretty_printer/test_trivia.cpp
    
    # Declarations
    pretty_printer/nodes/declarations/test_component.cpp
    pretty_printer/nodes/declarations/interface/test_generic.cpp
    pretty_printer/nodes/declarations/interface/test_port.cpp
    
    # Design Units
    pretty_printer/nodes/test_design_file.cpp
    pretty_printer/nodes/design_units/test_entity.cpp
    pretty_printer/nodes/design_units/test_architecture.cpp
    pretty_printer/nodes/design_units/test_context.cpp
    
    # Statements
    pretty_printer/nodes/statements/test_waveform.cpp
    pretty_printer/nodes/statements/concurrent/test_assignment.cpp
    pretty_printer/nodes/statements/concurrent/test_process.cpp
    pretty_printer/nodes/statements/sequential/test_assignment.cpp
    pretty_printer/nodes/statements/sequential/test_if.cpp
    pretty_printer/nodes/statements/sequential/test_case.cpp
    pretty_printer/nodes/statements/sequential/test_loop.cpp
    pretty_printer/nodes/statements/sequential/test_null.cpp

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
    
    # Types
    pretty_printer/nodes/types/test_access.cpp
    pretty_printer/nodes/types/test_array.cpp
    pretty_printer/nodes/types/test_enumeration.cpp
    pretty_printer/nodes/types/test_file.cpp
    pretty_printer/nodes/types/test_incomplete.cpp
    pretty_printer/nodes/types/test_record.cpp
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
