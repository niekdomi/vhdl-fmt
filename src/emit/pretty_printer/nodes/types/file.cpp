#include "ast/nodes/types.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

namespace emit {

auto PrettyPrinter::operator()(const ast::FileTypeDef &node) const -> Doc
{
    return Doc::keyword(("file")) & Doc::keyword(("of")) & visit(node.subtype);
}

} // namespace emit
