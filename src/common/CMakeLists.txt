add_library(common INTERFACE)

target_include_directories(
    common
    INTERFACE
        ${CMAKE_SOURCE_DIR}/src
        ${CMAKE_BINARY_DIR}/generated
)

target_sources(
    common
    INTERFACE
        FILE_SET HEADERS
            FILES config.hpp logger.hpp
)

target_link_libraries(
    common
    INTERFACE
        spdlog::spdlog
        fmt::fmt
)
