#include "ast/nodes/expressions.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

namespace emit {

auto PrettyPrinter::operator()(const ast::TokenExpr &node) const -> Doc
{
    return Doc::text(node.text);
}

} // namespace emit
