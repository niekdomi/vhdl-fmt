add_library(
    builder
    STATIC
    ast_builder.cpp
    trivia/trivia_binder.cpp
    #
    # Declarations
    translators/declarations/interface/generic.cpp
    translators/declarations/interface/port.cpp
    translators/declarations/objects/constant.cpp
    translators/declarations/objects/signal.cpp
    translators/declarations/objects/variable.cpp
    translators/declarations/component.cpp
    translators/declarations/type.cpp
    #
    # Design Units
    translators/design_units/design_file.cpp
    translators/design_units/entity.cpp
    translators/design_units/architecture.cpp
    translators/design_units/context.cpp
    #
    # Types
    translators/types/enumeration.cpp
    translators/types/record.cpp
    translators/types/array.cpp
    translators/types/access.cpp
    translators/types/file.cpp
    #
    # Statements
    translators/statements/waveform.cpp
    translators/statements/concurrent/assignment.cpp
    translators/statements/concurrent/process.cpp
    translators/statements/sequential/assignment.cpp
    translators/statements/sequential/if.cpp
    translators/statements/sequential/case.cpp
    translators/statements/sequential/loop.cpp
    translators/statements/concurrent/dispatch.cpp
    translators/statements/sequential/dispatch.cpp
    #
    # Expressions
    translators/expressions/binary.cpp
    translators/expressions/unary.cpp
    translators/expressions/primary.cpp
    translators/expressions/name.cpp
    translators/expressions/call.cpp
    translators/expressions/slice.cpp
    translators/expressions/attribute.cpp
    translators/expressions/qualified.cpp
    translators/expressions/allocator.cpp
    translators/expressions/aggregate.cpp
    translators/expressions/subtype.cpp
)

target_include_directories(builder PUBLIC ${CMAKE_SOURCE_DIR}/src)

target_link_libraries(
    builder
    PUBLIC
        ast
        common
        vhdl_generated
)
