#include "ast/nodes/design_units.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"
#include "emit/pretty_printer/doc_utils.hpp"

#include <ranges>

namespace emit {

auto PrettyPrinter::operator()(const ast::GenericClause &node) const -> Doc
{
    if (std::ranges::empty(node.generics)) {
        return Doc::empty();
    }

    const Doc opener = Doc::text("generic") & Doc::text("(");
    const Doc closer = Doc::text(");");

    // Build generic list with semicolon delimiters
    Doc doc = Doc::empty();
    for (size_t i = 0; i < node.generics.size(); ++i) {
        if (i > 0) {
            doc += Doc::line();
        }

        // Pass ";" delimiter for all generics except the last one
        const bool is_last = (i == node.generics.size() - 1);
        doc += visit(node.generics[i], is_last ? "" : ";");
    }

    const Doc result = Doc::align(doc);

    return Doc::group(Doc::bracket(opener, result, closer));
}

auto PrettyPrinter::operator()(const ast::PortClause &node) const -> Doc
{
    if (std::ranges::empty(node.ports)) {
        return Doc::empty();
    }

    const Doc opener = Doc::text("port") & Doc::text("(");
    const Doc closer = Doc::text(");");

    // Build port list with semicolon delimiters
    Doc doc = Doc::empty();
    for (size_t i = 0; i < node.ports.size(); ++i) {
        if (i > 0) {
            doc += Doc::line();
        }

        // Pass ";" delimiter for all ports except the last one
        const bool is_last = (i == node.ports.size() - 1);
        doc += visit(node.ports[i], is_last ? "" : ";");
    }

    const Doc result = Doc::align(doc);

    return Doc::group(Doc::bracket(opener, result, closer));
}

} // namespace emit
