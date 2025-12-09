#include "ast/nodes/declarations/interface.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

#include <ranges>

namespace emit {

auto PrettyPrinter::operator()(const ast::GenericClause &node) const -> Doc
{
    if (std::ranges::empty(node.generics)) {
        return Doc::empty();
    }

    const Doc opener = Doc::keyword(("generic")) & Doc::text("(");
    const Doc closer = Doc::text(");");

    const Doc generics = joinMap(node.generics, Doc::line(), [&](const auto &param) {
        const bool is_last = &param == &node.generics.back();
        return visit(param, is_last);
    });

    const Doc result = Doc::align(generics);

    return Doc::group(Doc::bracket(opener, result, closer));
}

auto PrettyPrinter::operator()(const ast::PortClause &node) const -> Doc
{
    if (std::ranges::empty(node.ports)) {
        return Doc::empty();
    }

    const Doc opener = Doc::keyword(("port")) & Doc::text("(");
    const Doc closer = Doc::text(");");

    const Doc ports = joinMap(node.ports, Doc::line(), [&](const auto &port) {
        const bool is_last = (&port == &node.ports.back());
        return visit(port, is_last);
    });

    const Doc result = Doc::align(ports);

    return Doc::group(Doc::bracket(opener, result, closer));
}

} // namespace emit
