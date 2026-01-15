#include "ast/nodes/design_units.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

namespace emit {

auto PrettyPrinter::operator()(const ast::DesignUnit& node) const -> Doc
{
    Doc context_doc = Doc::empty();
    for (const auto& ctx : node.context) {
        if (context_doc.isEmpty()) {
            context_doc = visit(ctx);
        } else {
            context_doc /= visit(ctx);
        }
    }

    Doc unit_doc = visit(node.unit);

    if (context_doc.isEmpty()) {
        return unit_doc;
    }

    return context_doc / unit_doc;
}

} // namespace emit
