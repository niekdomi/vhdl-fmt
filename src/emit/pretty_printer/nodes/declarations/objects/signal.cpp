#include "ast/nodes/declarations/objects.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"
#include "emit/pretty_printer/nodes/alignment.hpp"

#include <ranges>
#include <string>

namespace emit {

auto PrettyPrinter::operator()(const ast::SignalDecl &node) const -> Doc
{
    const std::string names = node.names
                            | std::views::join_with(std::string_view{ ", " })
                            | std::ranges::to<std::string>();

    Doc result = Doc::keyword(("signal")) & Doc::text(names, AlignmentLevel::NAME) & Doc::text(":");

    // Type definition
    result &= visit(node.subtype);

    if (node.has_bus_kw) {
        result &= Doc::keyword(("bus"));
    }

    // Initialization
    if (node.init_expr) {
        result &= Doc::text(":=") & visit(node.init_expr.value());
    }

    return result + Doc::text(";");
}

} // namespace emit
