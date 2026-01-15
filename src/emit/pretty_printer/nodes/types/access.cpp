#include "ast/nodes/types.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

namespace emit {

auto PrettyPrinter::operator()(const ast::AccessTypeDef& node) const -> Doc
{
    return Doc::keyword("access") & visit(node.subtype);
}

} // namespace emit
