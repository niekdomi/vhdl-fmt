#include "ast/nodes/declarations.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

#include <ranges>

namespace emit {

auto PrettyPrinter::operator()(const ast::ComponentDecl &node) const -> Doc
{
    Doc result = Doc::keyword(("component")) & Doc::text(node.name);

    if (node.has_is_keyword) {
        result &= Doc::keyword(("is"));
    }

    if (!std::ranges::empty(node.generic_clause.generics)) {
        result <<= visit(node.generic_clause);
    }

    if (!std::ranges::empty(node.port_clause.ports)) {
        result <<= visit(node.port_clause);
    }

    Doc end_line = Doc::keyword(("end")) & Doc::keyword(("component"));
    if (node.end_label.has_value()) {
        end_line &= Doc::text(*node.end_label);
    }
    end_line += Doc::text(";");

    return result / end_line;
}

} // namespace emit
