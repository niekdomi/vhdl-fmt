#include "ast/nodes/statements.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"
#include "emit/pretty_printer/doc_utils.hpp"

namespace emit {

auto PrettyPrinter::operator()(const ast::Process &node) const -> Doc
{
    Doc head = Doc::text("process");

    // Sensitivity list: process(clk, rst)
    if (!node.sensitivity_list.empty()) {
        const Doc list = joinMap(
          node.sensitivity_list,
          Doc::text(", "),
          [](const auto &s) { return Doc::text(s); },
          false);

        head += Doc::text("(") + list + Doc::text(")");
    }

    // Declarations (Variables, Constants, etc. defined before 'begin')
    if (!node.decls.empty()) {
        head <<= joinMap(node.decls, Doc::line(), toDoc(*this), false);
    }

    head /= Doc::text("begin");

    // Body
    Doc body = Doc::empty();
    if (!node.body.empty()) {
        body += joinMap(node.body, Doc::line(), toDoc(*this), false);
    }

    const Doc end = Doc::text("end process;");

    return Doc::bracket(head, body, end);
}

} // namespace emit
