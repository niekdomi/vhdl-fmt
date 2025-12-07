# Submodules
add_subdirectory(ast)
add_subdirectory(cli)
add_subdirectory(builder)
add_subdirectory(common)
add_subdirectory(emit)

# Main executable
add_executable(vhdl_formatter main.cpp)
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

# Static linking for distribution builds
if(ENABLE_STATIC_LINKING AND CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_link_options(
        vhdl_formatter
        PRIVATE
            -static-libgcc
            -static-libstdc++
    )
endif()

target_compile_options(
    vhdl_formatter
    PRIVATE
        $<$<CONFIG:Release>:-O3>
        # -O3 -ffast-math # lossy floating-point optimizations
        # -flto=full # Apparently, this could improve performance by around 10%
        -Wall
        -Wcast-align
        -Wconversion
        -Wcovered-switch-default
        -Wdeprecated
        -Wdouble-promotion
        -Werror
        -Wexperimental-lifetime-safety
        -Wextra
        -Wfloat-conversion
        -Wfloat-equal
        -Wfor-loop-analysis
        -Wformat=2
        -Winvalid-utf8
        -Wmisleading-indentation
        -Wnon-virtual-dtor
        -Wold-style-cast
        -Woverloaded-virtual
        -Wpedantic
        -Wpoison-system-directories
        -Wshadow-all
        -Wsign-conversion
        -Wsuggest-destructor-override
        -Wsuggest-override
        -Wsuper-class-method-mismatch
        -Wthread-safety
        -Wunreachable-code-aggressive
        -Wunused
        -Wzero-as-null-pointer-constant
)
