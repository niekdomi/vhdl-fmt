#include "ast/nodes/statements.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

namespace emit {

auto PrettyPrinter::operator()(const ast::SequentialStatement &node) const -> Doc
{
    Doc body = visit(node.kind);

    if (node.label) {
        return (Doc::text(*node.label) + Doc::text(":")) & body;
    }

    return body;
}

} // namespace emit
