#include "ast/nodes/design_units.hpp"

#include "ast/nodes/declarations.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

#include <algorithm>
#include <optional>
#include <ranges>

namespace emit {

auto PrettyPrinter::operator()(const ast::Entity &node) const -> Doc
{
    std::optional<Doc> result;

    // Emit context clauses (library and use) first
    for (const auto &ctx : node.context) {
        if (!result.has_value()) {
            result = visit(ctx);
        } else {
            *result /= visit(ctx);
        }
    }

    // Emit entity declaration
    const Doc entity_line
      = Doc::text(keyword("entity")) & Doc::text(node.name) & Doc::text(keyword("is"));
    if (!result.has_value()) {
        result = entity_line;
    } else {
        *result /= entity_line;
    }

    if (!std::ranges::empty(node.generic_clause.generics)) {
        *result <<= visit(node.generic_clause);
    }

    if (!std::ranges::empty(node.port_clause.ports)) {
        *result <<= visit(node.port_clause);
    }

    // Declarations
    *result = std::ranges::fold_left(
      node.decls, *result, [this](auto acc, const auto &decl) { return acc <<= visit(decl); });

    // Begin section (concurrent statements)
    if (!std::ranges::empty(node.stmts)) {
        *result /= Doc::text(keyword("begin"));
        *result = std::ranges::fold_left(
          node.stmts, *result, [this](auto acc, const auto &stmt) { return acc <<= visit(stmt); });
    }

    Doc end_line = Doc::text(keyword("end"));
    if (node.has_end_entity_keyword) {
        end_line &= Doc::text(keyword("entity"));
    }
    if (node.end_label.has_value()) {
        end_line &= Doc::text(*node.end_label);
    }
    end_line += Doc::text(";");

    return *result / end_line;
}

auto PrettyPrinter::operator()(const ast::Architecture &node) const -> Doc
{
    std::optional<Doc> result;

    // Emit context clauses (library and use) first
    for (const auto &ctx : node.context) {
        if (!result.has_value()) {
            result = visit(ctx);
        } else {
            *result /= visit(ctx);
        }
    }

    // Emit architecture declaration
    const Doc arch_line = Doc::text(keyword("architecture"))
                        & Doc::text(node.name)
                        & Doc::text(keyword("of"))
                        & Doc::text(node.entity_name)
                        & Doc::text(keyword("is"));

    if (!result.has_value()) {
        result = arch_line;
    } else {
        *result /= arch_line;
    }

    // Declarative items (components, constants, signals, etc. - in order)
    *result = std::ranges::fold_left(
      node.decls, *result, [this](auto acc, const auto &item) { return acc <<= visit(item); });

    // begin
    *result /= Doc::text(keyword("begin"));

    // Concurrent statements
    *result = std::ranges::fold_left(
      node.stmts, *result, [this](auto acc, const auto &stmt) { return acc <<= visit(stmt); });

    // end [architecture] [<name>];
    Doc end_line = Doc::text(keyword("end"));
    if (node.has_end_architecture_keyword) {
        end_line &= Doc::text(keyword("architecture"));
    }
    if (node.end_label.has_value()) {
        end_line &= Doc::text(*node.end_label);
    }
    end_line += Doc::text(";");

    return *result / end_line;
}

auto PrettyPrinter::operator()(const ast::LibraryClause &node) const -> Doc
{
    Doc result = Doc::text(keyword("library"));

    for (const auto &[idx, name] : std::views::enumerate(node.logical_names)) {
        if (idx > 0) {
            result += Doc::text(",");
        }
        result &= Doc::text(name);
    }
    result += Doc::text(";");

    return result;
}

auto PrettyPrinter::operator()(const ast::UseClause &node) const -> Doc
{
    Doc result = Doc::text(keyword("use"));

    for (const auto &[idx, name] : std::views::enumerate(node.selected_names)) {
        if (idx > 0) {
            result += Doc::text(",");
        }
        result &= Doc::text(name);
    }
    result += Doc::text(";");

    return result;
}

auto PrettyPrinter::operator()(const ast::ComponentDecl &node) const -> Doc
{
    Doc result = Doc::text(keyword("component")) & Doc::text(node.name);

    if (node.has_is_keyword) {
        result &= Doc::text(keyword("is"));
    }

    if (!std::ranges::empty(node.generic_clause.generics)) {
        result <<= visit(node.generic_clause);
    }

    if (!std::ranges::empty(node.port_clause.ports)) {
        result <<= visit(node.port_clause);
    }

    Doc end_line = Doc::text(keyword("end")) & Doc::text(keyword("component"));
    if (node.end_label.has_value()) {
        end_line &= Doc::text(*node.end_label);
    }
    end_line += Doc::text(";");

    return result / end_line;
}

} // namespace emit
