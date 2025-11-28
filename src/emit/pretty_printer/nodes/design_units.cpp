#include "ast/nodes/design_units.hpp"

#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

#include <algorithm>
#include <ranges>

namespace emit {

auto PrettyPrinter::operator()(const ast::Entity &node) const -> Doc
{
    Doc result = Doc::text("entity") & Doc::text(node.name) & Doc::text("is");

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
        result /= Doc::text("begin");
        result = std::ranges::fold_left(
          node.stmts, result, [this](auto acc, const auto &stmt) { return acc <<= visit(stmt); });
    }

    Doc end_line = Doc::text("end");
    if (node.has_end_entity_keyword) {
        end_line &= Doc::text("entity");
    }
    if (node.end_label.has_value()) {
        end_line &= Doc::text(*node.end_label);
    }
    end_line += Doc::text(";");

    return result / end_line;
}

auto PrettyPrinter::operator()(const ast::Architecture &node) const -> Doc
{
    Doc result = Doc::text("architecture")
               & Doc::text(node.name)
               & Doc::text("of")
               & Doc::text(node.entity_name)
               & Doc::text("is");

    // Declarations
    result = std::ranges::fold_left(
      node.decls, result, [this](auto acc, const auto &decl) { return acc <<= visit(decl); });

    // begin
    result /= Doc::text("begin");

    // Concurrent statements
    result = std::ranges::fold_left(
      node.stmts, result, [this](auto acc, const auto &stmt) { return acc <<= visit(stmt); });

    // end [architecture] [<name>];
    Doc end_line = Doc::text("end");
    if (node.has_end_architecture_keyword) {
        end_line &= Doc::text("architecture");
    }
    if (node.end_label.has_value()) {
        end_line &= Doc::text(*node.end_label);
    }
    end_line += Doc::text(";");

    return result / end_line;
}

} // namespace emit
