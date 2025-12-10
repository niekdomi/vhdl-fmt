#include "ast/nodes/statements/concurrent.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

namespace emit {

auto PrettyPrinter::operator()(const ast::Process &node) const -> Doc
{
    Doc head = Doc::keyword(("process"));

    // Label: label:
    if (node.label) {
        head = Doc::text(*node.label + ":") & head;
    }

    // Sensitivity list: process(clk, rst)
    if (!node.sensitivity_list.empty()) {
        const Doc list = joinMap(
          node.sensitivity_list, Doc::text(", "), [](const auto &s) { return Doc::text(s); });

        head += Doc::text("(") + list + Doc::text(")");
    }

    // Declarations (Variables, Constants, etc. defined before 'begin')
    if (!node.decls.empty()) {
        head <<= join(node.decls, Doc::line());
    }

    head /= Doc::keyword(("begin"));

    const Doc end = Doc::keyword(("end")) & Doc::keyword(("process")) + Doc::text(";");

    if (node.body.empty()) {
        return head / end;
    }

    const Doc body = join(node.body, Doc::line());

    return Doc::bracket(head, body, end);
}

} // namespace emit
