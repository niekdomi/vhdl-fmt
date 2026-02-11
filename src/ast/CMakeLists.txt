add_library(ast INTERFACE)

target_include_directories(ast INTERFACE ${CMAKE_SOURCE_DIR}/src)

target_sources(
    ast
    INTERFACE
        FILE_SET HEADERS
            FILES
                node.hpp
                visitor.hpp
                nodes/declarations.hpp
                nodes/design_file.hpp
                nodes/design_units.hpp
                nodes/expressions.hpp
                nodes/statements.hpp
)
