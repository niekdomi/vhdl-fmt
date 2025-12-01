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

    const Doc doc = joinMap(
      node.generics,
      Doc::text(";") + Doc::line(),
      [this](const auto &g) { return visit(g); },
      false);

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

    const Doc doc = joinMap(
      node.ports, Doc::text(";") + Doc::line(), [this](const auto &p) { return visit(p); }, false);

    const Doc result = Doc::align(doc);

    return Doc::group(Doc::bracket(opener, result, closer));
}

} // namespace emit
