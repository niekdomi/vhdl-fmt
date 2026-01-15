#include "ast/nodes/expressions.hpp"
#include "common/overload.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

#include <variant>

namespace emit {

auto PrettyPrinter::operator()(const ast::SubtypeIndication& node) const -> Doc
{
    Doc result = Doc::empty();

    // Resolution Function (e.g., "resolved")
    if (node.resolution_func) {
        result += Doc::text(*node.resolution_func) + Doc::text(" ");
    }

    // Type Mark (e.g., "std_logic")
    result += Doc::text(node.type_mark);

    // Constraint (e.g., "(7 downto 0)")
    if (node.constraint) {
        result += std::visit(
          common::Overload{
            [this](const ast::IndexConstraint& idx) -> Doc { return visit(idx); },
            [this](const ast::RangeConstraint& rc) -> Doc { return Doc::text(" ") + visit(rc); },
          },
          node.constraint.value());
    }

    return result;
}

} // namespace emit
