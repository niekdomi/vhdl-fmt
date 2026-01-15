#include "ast/nodes/statements/sequential.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

namespace emit {

auto PrettyPrinter::operator()(const ast::CaseStatement& node) const -> Doc
{
    const Doc head = Doc::keyword("case") & visit(node.selector) & Doc::keyword("is");

    const Doc body = joinMap(node.when_clauses, Doc::line(), [this](const auto& clause) {
        // Join choices: "1 | 2 | 3"
        const Doc choices = join(clause.choices, Doc::text(" | "));
        const Doc when_head = Doc::keyword("when") & choices & Doc::text("=>");
        const Doc when_body = join(clause.body, Doc::line());

        return when_head << when_body;
    });

    const Doc end = Doc::keyword("end") & Doc::keyword("case") + Doc::text(";");

    return Doc::bracket(head, body, end);
}

} // namespace emit
