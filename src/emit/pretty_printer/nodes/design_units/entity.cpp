#include "ast/nodes/design_units.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

#include <algorithm>
#include <optional>
#include <ranges>

namespace emit {

auto PrettyPrinter::operator()(const ast::Entity &node) const -> Doc
{
    // Emit entity declaration
    Doc result = Doc::keyword(("entity")) & Doc::text(node.name) & Doc::keyword(("is"));

    if (!std::ranges::empty(node.generic_clause.generics)) {
        result <<= visit(node.generic_clause);
    }

    if (!std::ranges::empty(node.port_clause.ports)) {
        result <<= visit(node.port_clause);
    }

    // Declarations
    result = std::ranges::fold_left(
      node.decls, result, [this](auto acc, const auto &decl) { return acc <<= visit(decl); });

    // Begin section (concurrent statements)
    if (!std::ranges::empty(node.stmts)) {
        result /= Doc::keyword(("begin"));
        result = std::ranges::fold_left(
          node.stmts, result, [this](auto acc, const auto &stmt) { return acc <<= visit(stmt); });
    }

    Doc end_line = Doc::keyword(("end"));
    if (node.has_end_entity_keyword) {
        end_line &= Doc::keyword(("entity"));
    }
    if (node.end_label.has_value()) {
        end_line &= Doc::text(*node.end_label);
    }
    end_line += Doc::text(";");

    return result / end_line;
}

} // namespace emit
