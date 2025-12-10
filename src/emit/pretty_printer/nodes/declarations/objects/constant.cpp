#include "ast/nodes/declarations/objects.hpp"
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

auto PrettyPrinter::operator()(const ast::ConstantDecl &node) const -> Doc
{
    const std::string names = node.names
                            | std::views::join_with(std::string_view{ ", " })
                            | std::ranges::to<std::string>();

    Doc result
      = Doc::keyword(("constant")) & Doc::text(names, AlignmentLevel::NAME) & Doc::text(":");

    result &= visit(node.subtype);

    if (node.init_expr) {
        result &= Doc::text(":=") & visit(node.init_expr.value());
    }

    return result + Doc::text(";");
}

} // namespace emit
