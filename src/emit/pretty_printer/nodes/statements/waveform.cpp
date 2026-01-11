#include "ast/nodes/statements/waveform.hpp"

#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

namespace emit {

auto PrettyPrinter::operator()(const ast::Waveform::Element &node, const bool is_last) const -> Doc
{
    Doc doc = visit(node.value);
    if (node.after) {
        doc &= Doc::keyword(("after")) & visit(*node.after);
    }
    return is_last ? doc : doc + Doc::text(",");
}

auto PrettyPrinter::operator()(const ast::Waveform &node) const -> Doc
{
    if (node.is_unaffected) {
        return Doc::keyword(("unaffected"));
    }

    return joinMap(node.elements, Doc::line(), [&](const auto &elem) {
        const bool is_last = (&elem == &node.elements.back());
        return visit(elem, is_last);
    });
}

} // namespace emit
