#include "ast/nodes/expressions.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

namespace emit {

auto PrettyPrinter::operator()(const ast::SliceExpr &node) const -> Doc
{
    return visit(*node.prefix) + Doc::text("(") + visit(*node.range) + Doc::text(")");
}

} // namespace emit
