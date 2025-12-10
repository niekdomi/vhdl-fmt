#include "ast/nodes/declarations.hpp"
#include "ast/nodes/design_units.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

#include <algorithm>
#include <optional>
#include <ranges>

namespace emit {

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
    const Doc arch_line = Doc::keyword(("architecture"))
                        & Doc::text(node.name)
                        & Doc::keyword(("of"))
                        & Doc::text(node.entity_name)
                        & Doc::keyword(("is"));

    if (!result.has_value()) {
        result = arch_line;
    } else {
        *result /= arch_line;
    }

    // Declarative items (components, constants, signals, etc. - in order)
    *result = std::ranges::fold_left(
      node.decls, *result, [this](auto acc, const auto &item) { return acc <<= visit(item); });

    // begin
    *result /= Doc::keyword(("begin"));

    // Concurrent statements
    *result = std::ranges::fold_left(
      node.stmts, *result, [this](auto acc, const auto &stmt) { return acc <<= visit(stmt); });

    // end [architecture] [<name>];
    Doc end_line = Doc::keyword(("end"));
    if (node.has_end_architecture_keyword) {
        end_line &= Doc::keyword(("architecture"));
    }
    if (node.end_label.has_value()) {
        end_line &= Doc::text(*node.end_label);
    }
    end_line += Doc::text(";");

    return *result / end_line;
}

} // namespace emit
