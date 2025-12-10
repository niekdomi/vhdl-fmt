#include "ast/nodes/expressions.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

namespace emit {

auto PrettyPrinter::operator()(const ast::CallExpr &node) const -> Doc
{
    // GroupExpr already provides parentheses, so just visit directly
    return visit(*node.callee) + visit(*node.args);
}

} // namespace emit
