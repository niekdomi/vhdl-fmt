#include "ast/nodes/expressions.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

namespace emit {

auto PrettyPrinter::operator()(const ast::GroupExpr &node) const -> Doc
{
    const Doc result = join(node.children, Doc::text(", "));
    return Doc::text("(") + result + Doc::text(")");
}

} // namespace emit
