#include "ast/nodes/design_units.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

#include <ranges>

namespace emit {

auto PrettyPrinter::operator()(const ast::LibraryClause &node) const -> Doc
{
    Doc result = Doc::keyword(("library"));

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
    Doc result = Doc::keyword(("use"));

    for (const auto &[idx, name] : std::views::enumerate(node.selected_names)) {
        if (idx > 0) {
            result += Doc::text(",");
        }
        result &= Doc::text(name);
    }
    result += Doc::text(";");

    return result;
}

} // namespace emit
