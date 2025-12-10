#include "ast/nodes/expressions.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

namespace emit {

auto PrettyPrinter::operator()(const ast::ParenExpr &node) const -> Doc
{
    return Doc::text("(") + visit(*node.inner) + Doc::text(")");
}

} // namespace emit
