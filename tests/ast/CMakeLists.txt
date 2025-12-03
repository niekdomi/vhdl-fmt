add_executable(
    ast_tests
    #
    # Design Units
    nodes/test_trivia.cpp
    nodes/design_units/test_architecture.cpp
    nodes/design_units/test_entity.cpp
    #
    # Declarations
    nodes/declarations/test_constant.cpp
    nodes/declarations/test_constraints.cpp
    nodes/declarations/test_generic_param.cpp
    nodes/declarations/test_port.cpp
    nodes/declarations/test_signal.cpp
    #
    # Expressions
    nodes/expressions/test_binary.cpp
    nodes/expressions/test_token.cpp
    nodes/expressions/test_unary.cpp
    #
    # Statements
    nodes/statements/test_case.cpp
    nodes/statements/test_concurrent_assign.cpp
    nodes/statements/test_control_flow.cpp
    nodes/statements/test_for_loop.cpp
    nodes/statements/test_process.cpp
    nodes/statements/test_selected_assign.cpp
    nodes/statements/test_sequential_assign.cpp
    nodes/statements/test_waveforms.cpp
    nodes/statements/test_while_loop.cpp
)

target_link_libraries(
    ast_tests
    PRIVATE
        Catch2::Catch2WithMain
        ast
        builder
)

target_include_directories(
    ast_tests
    PRIVATE
        ${CMAKE_SOURCE_DIR}/src
        ${CMAKE_SOURCE_DIR}/tests
        ${GENERATED_DIR}
)

# Macro for test data directory
target_compile_definitions(
    ast_tests
    PRIVATE
        TEST_DATA_DIR="${CMAKE_BINARY_DIR}/tests/data"
)

catch_discover_tests(ast_tests)
