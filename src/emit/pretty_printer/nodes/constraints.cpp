#include "ast/nodes/expressions.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

namespace emit {

auto PrettyPrinter::operator()(const ast::IndexConstraint &node) const -> Doc
{
    // Index constraints are parenthesized ranges: (7 downto 0) or (0 to 15, 0 to 7)
    return visit(node.ranges);
}

auto PrettyPrinter::operator()(const ast::RangeConstraint &node) const -> Doc
{
    // Range constraints have the RANGE keyword: range 0 to 255
    return Doc::text("range") & visit(node.range);
}

} // namespace emit
