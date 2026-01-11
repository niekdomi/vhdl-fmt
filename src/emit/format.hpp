#ifndef EMIT_FORMAT_HPP
#define EMIT_FORMAT_HPP

#include "common/config.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/renderer.hpp"
#include "node.hpp"

#include <string>

namespace emit {

/// @brief High-level facade to format an AST node into a string.
template<typename T>
    requires std::is_base_of_v<ast::NodeBase, T>
auto format(const T &root, const common::Config &config) -> std::string
{
    const auto doc = PrettyPrinter{}.visit(root);
    return Renderer{ config }.render(doc);
}

} // namespace emit

#endif // EMIT_FORMAT_HPP
