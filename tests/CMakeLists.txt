# Copy test data to build directory for all test executables
file(COPY data DESTINATION ${CMAKE_CURRENT_BINARY_DIR})

include(CTest)
include(Catch)

add_compile_options(-Wno-missing-designated-field-initializers)

add_subdirectory(ast)
add_subdirectory(cli)
add_subdirectory(emit)

add_subdirectory(benchmarks)
