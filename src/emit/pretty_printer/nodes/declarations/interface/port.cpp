#include "ast/nodes/declarations/interface.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

#include <ranges>
#include <string>

namespace emit {

/// @brief Named constants for common alignment columns used in declarations.
struct AlignmentLevel
{
    static constexpr int NAME = 0; ///< Column 0: Used for names (port, generic, signal, etc.)
    static constexpr int MODE = 1; ///< Column 1: Used for mode (port modes like "in", "out", etc.)
};

auto PrettyPrinter::operator()(const ast::PortClause &node) const -> Doc
{
    if (std::ranges::empty(node.ports)) {
        return Doc::empty();
    }

    const Doc opener = Doc::keyword(("port")) & Doc::text("(");
    const Doc closer = Doc::text(");");

    const Doc ports = joinMap(node.ports, Doc::line(), [&](const auto &port) {
        const bool is_last = (&port == &node.ports.back());
        return visit(port, is_last);
    });

    const Doc result = Doc::align(ports);

    return Doc::group(Doc::bracket(opener, result, closer));
}

auto PrettyPrinter::operator()(const ast::Port &node, const bool is_last) const -> Doc
{
    const std::string names = node.names
                            | std::views::join_with(std::string_view{ ", " })
                            | std::ranges::to<std::string>();

    Doc result = Doc::text(names, AlignmentLevel::NAME)
               & Doc::text(":")
               & Doc::keyword(node.mode, AlignmentLevel::MODE)
               & visit(node.subtype);

    if (node.default_expr) {
        result &= Doc::text(":=") & visit(node.default_expr.value());
    }

    return is_last ? result : result + Doc::text(";");
}

} // namespace emit
