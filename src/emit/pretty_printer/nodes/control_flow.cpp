#include "ast/nodes/statements/sequential.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

namespace emit {

auto PrettyPrinter::operator()(const ast::IfStatement &node) const -> Doc
{
    // 1. IF Header & Body
    Doc result = (Doc::keyword(("if")) & visit(node.if_branch.condition) & Doc::keyword(("then")))
              << join(node.if_branch.body, Doc::line());

    // 2. ELSIF (Optional)
    if (!node.elsif_branches.empty()) {
        const auto make_elsif = [&](const auto &branch) {
            return (Doc::keyword(("elsif")) & visit(branch.condition) & Doc::keyword(("then")))
                << join(branch.body, Doc::line());
        };

        result /= joinMap(node.elsif_branches, Doc::line(), make_elsif);
    }

    // 3. ELSE (Optional)
    if (node.else_branch) {
        result /= (Doc::keyword(("else")) << join(node.else_branch->body, Doc::line()));
    }

    // 4. END IF
    return result / (Doc::keyword(("end")) & Doc::keyword(("if")) + Doc::text(";"));
}

auto PrettyPrinter::operator()(const ast::CaseStatement &node) const -> Doc
{
    const Doc head = Doc::keyword(("case")) & visit(node.selector) & Doc::keyword(("is"));

    const Doc body = joinMap(node.when_clauses, Doc::line(), [this](const auto &clause) {
        // Join choices: "1 | 2 | 3"
        const Doc choices = join(clause.choices, Doc::text(" | "));
        const Doc when_head = Doc::keyword(("when")) & choices & Doc::text("=>");
        const Doc when_body = join(clause.body, Doc::line());

        return when_head << when_body;
    });

    const Doc end = Doc::keyword(("end")) & Doc::keyword(("case")) + Doc::text(";");

    return Doc::bracket(head, body, end);
}

auto PrettyPrinter::operator()(const ast::ForLoop &node) const -> Doc
{
    const Doc head = Doc::keyword(("for"))
                   & Doc::text(node.iterator)
                   & Doc::keyword(("in"))
                   & visit(node.range)
                   & Doc::keyword(("loop"));

    const Doc body = join(node.body, Doc::line());
    const Doc end = Doc::keyword(("end")) & Doc::keyword(("loop")) + Doc::text(";");

    return Doc::bracket(head, body, end);
}

auto PrettyPrinter::operator()(const ast::WhileLoop &node) const -> Doc
{
    const Doc head = Doc::keyword(("while")) & visit(node.condition) & Doc::keyword(("loop"));
    const Doc body = join(node.body, Doc::line());
    const Doc end = Doc::keyword(("end")) & Doc::keyword(("loop")) + Doc::text(";");

    return Doc::bracket(head, body, end);
}

auto PrettyPrinter::operator()(const ast::Loop &node) const -> Doc
{
    Doc head = Doc::keyword(("loop"));
    if (node.label) {
        head = Doc::text(*node.label + ":") & head;
    }

    const Doc body = join(node.body, Doc::line());
    const Doc end = Doc::keyword(("end")) & Doc::keyword(("loop")) + Doc::text(";");

    return Doc::bracket(head, body, end);
}

} // namespace emit
