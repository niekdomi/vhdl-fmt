#include "ast/nodes/expressions.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

namespace emit {

auto PrettyPrinter::operator()(const ast::QualifiedExpr& node) const -> Doc
{
    return visit(node.type_mark) + Doc::text("'") + visit(*node.operand);
}

} // namespace emit
