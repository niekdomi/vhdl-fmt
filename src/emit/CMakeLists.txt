add_library(
    emit
    STATIC
    pretty_printer/doc.cpp
    pretty_printer/doc_impl.cpp
    pretty_printer/renderer.cpp
    pretty_printer/trivia.cpp
    pretty_printer/nodes/assignments.cpp
    pretty_printer/nodes/clauses.cpp
    pretty_printer/nodes/control_flow.cpp
    pretty_printer/nodes/constraints.cpp
    pretty_printer/nodes/declarations.cpp
    pretty_printer/nodes/design_file.cpp
    pretty_printer/nodes/design_units.cpp
    pretty_printer/nodes/expressions.cpp
    pretty_printer/nodes/process.cpp
    pretty_printer/nodes/types.cpp
)

target_include_directories(emit PUBLIC ${CMAKE_SOURCE_DIR}/src)

target_link_libraries(emit PUBLIC ast)
