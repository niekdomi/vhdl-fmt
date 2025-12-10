add_library(
    emit
    STATIC
    pretty_printer/doc.cpp
    pretty_printer/doc_impl.cpp
    pretty_printer/renderer.cpp
    pretty_printer/trivia.cpp
    #
    # Design Units
    pretty_printer/nodes/design_file.cpp
    pretty_printer/nodes/design_units/entity.cpp
    pretty_printer/nodes/design_units/architecture.cpp
    pretty_printer/nodes/design_units/context.cpp
    #
    # Declarations
    pretty_printer/nodes/declarations/component.cpp
    pretty_printer/nodes/declarations/type.cpp
    pretty_printer/nodes/declarations/interface/generic.cpp
    pretty_printer/nodes/declarations/interface/port.cpp
    pretty_printer/nodes/declarations/objects/constant.cpp
    pretty_printer/nodes/declarations/objects/signal.cpp
    pretty_printer/nodes/declarations/objects/variable.cpp
    #
    # Types
    pretty_printer/nodes/types/enumeration.cpp
    pretty_printer/nodes/types/record.cpp
    pretty_printer/nodes/types/array.cpp
    pretty_printer/nodes/types/access.cpp
    pretty_printer/nodes/types/file.cpp
    #
    # Expressions
    pretty_printer/nodes/expressions/token.cpp
    pretty_printer/nodes/expressions/physical.cpp
    pretty_printer/nodes/expressions/group.cpp
    pretty_printer/nodes/expressions/unary.cpp
    pretty_printer/nodes/expressions/binary.cpp
    pretty_printer/nodes/expressions/attribute.cpp
    pretty_printer/nodes/expressions/qualified.cpp
    pretty_printer/nodes/expressions/paren.cpp
    pretty_printer/nodes/expressions/call.cpp
    pretty_printer/nodes/expressions/slice.cpp
    pretty_printer/nodes/expressions/subtype_indication.cpp
    pretty_printer/nodes/expressions/constraints.cpp
    #
    # Statements
    pretty_printer/nodes/statements/waveform.cpp
    pretty_printer/nodes/statements/concurrent/dispatch.cpp
    pretty_printer/nodes/statements/concurrent/assignment.cpp
    pretty_printer/nodes/statements/concurrent/process.cpp
    pretty_printer/nodes/statements/sequential/assignment.cpp
    pretty_printer/nodes/statements/sequential/case.cpp
    pretty_printer/nodes/statements/sequential/dispatch.cpp
    pretty_printer/nodes/statements/sequential/if.cpp
    pretty_printer/nodes/statements/sequential/loop.cpp
    pretty_printer/nodes/statements/sequential/null.cpp
)

target_include_directories(emit PUBLIC ${CMAKE_SOURCE_DIR}/src)

target_link_libraries(emit PUBLIC ast)
