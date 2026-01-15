#ifndef EMIT_TEST_UTILS_HPP
#define EMIT_TEST_UTILS_HPP

#include "ast/node.hpp"
#include "common/config.hpp"
#include "emit/format.hpp"
#include "emit/pretty_printer/renderer.hpp"

#include <concepts>
#include <string>

namespace emit::test {

template<typename T>
concept ASTNode = std::derived_from<T, ast::NodeBase>;

// Default config for tests - uses indent_size of 2 to match existing test expectations
constexpr auto defaultConfig() -> common::Config
{
    constexpr int TEST_INDENT_SIZE = 2;
    constexpr int TEST_LINE_LENGTH = 80;

    return common::Config{
      .line_config = {.line_length = TEST_LINE_LENGTH, .indent_size = TEST_INDENT_SIZE}
    };
}

// Helper to render an AST node with default config
auto render(const ASTNode auto& node) -> std::string
{
    return emit::format(node, defaultConfig());
}

// Helper to render an AST node with custom config
auto render(const ASTNode auto& node, const common::Config& config) -> std::string
{
    return emit::format(node, config);
}

} // namespace emit::test

#endif // EMIT_TEST_UTILS_HPP
