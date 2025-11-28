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

    // end [entity] [<name>];
    const auto end_label = node.end_label.value_or(node.name);
    const Doc end_line
      = Doc::text("end") & Doc::text("entity") & Doc::text(end_label) + Doc::text(";");

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
    const Doc end_line
      = Doc::text("end") & Doc::text("architecture") & Doc::text(node.name) + Doc::text(";");

    return result / end_line;
}

auto PrettyPrinter::operator()([[maybe_unused]] const ast::ContextDeclaration &node) const -> Doc
{
    // TODO(vedivad): Implement context declaration printing
    return Doc::text("-- context");
}

} // namespace emit
