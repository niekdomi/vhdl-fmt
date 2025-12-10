#include "ast/nodes/expressions.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

namespace emit {

auto PrettyPrinter::operator()(const ast::AttributeExpr &node) const -> Doc
{
    Doc result = visit(*node.prefix) + Doc::text("'") + Doc::text(node.attribute);

    if (node.arg.has_value()) {
        result += Doc::text("(") + visit(**node.arg) + Doc::text(")");
    }

    return result;
}

} // namespace emit
