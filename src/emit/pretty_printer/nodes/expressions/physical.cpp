#include "ast/nodes/expressions.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

namespace emit {

auto PrettyPrinter::operator()(const ast::PhysicalLiteral &node) const -> Doc
{
    return Doc::text(node.value) & Doc::text(node.unit);
}

} // namespace emit
