add_library(
    builder
    STATIC
    ast_builder.cpp
    translators/translator_concurrent.cpp
    translators/translator_control_flow.cpp
    translators/translator_declaration.cpp
    translators/translator_expr_composites.cpp
    translators/translator_expr_names.cpp
    translators/translator_expr_operators.cpp
    translators/translator_sequential.cpp
    translators/translator_unit.cpp
    trivia/trivia_binder.cpp
)

target_include_directories(builder PUBLIC ${CMAKE_SOURCE_DIR}/src)

target_link_libraries(
    builder
    PUBLIC
        ast
        common
        vhdl_generated
)
