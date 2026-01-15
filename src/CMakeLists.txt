# Submodules
add_subdirectory(ast)
add_subdirectory(cli)
add_subdirectory(builder)
add_subdirectory(common)
add_subdirectory(emit)

# Main executable
add_executable(vhdl_formatter main.cpp)

# Uncomment to set custom binary name
# set_target_properties(
#     vhdl_formatter
#     PROPERTIES
#         OUTPUT_NAME
#             "vhdl-fmt"
# )

target_link_libraries(
    vhdl_formatter
    PRIVATE
        ast
        cli
        common
        builder
        emit
)

# Optional optimization flags (uncomment to enable)
# target_compile_options(
#     vhdl_formatter
#     PRIVATE
#         -ffast-math  # Lossy floating-point optimizations
#         -flto=full   # Link-time optimization (~10% performance improvement)
# )
