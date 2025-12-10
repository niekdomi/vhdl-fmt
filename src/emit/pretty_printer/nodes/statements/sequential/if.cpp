#include "ast/nodes/statements/sequential.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

#include <ranges>

namespace emit {

auto PrettyPrinter::operator()(const ast::IfStatement &node) const -> Doc
{
    Doc result = Doc::empty();

    // 1. IF / ELSIF
    for (const auto &[index, branch] : std::views::enumerate(node.branches)) {
        const Doc keyword = (index == 0) ? Doc::keyword("if") : Doc::keyword("elsif");

        // Separator: Newline if not the first branch
        if (index > 0) {
            result += Doc::line(); // soft line break
        }

        result += (keyword & visit(branch.condition) & Doc::keyword("then"))
               << join(branch.body, Doc::line());
    }

    // 2. ELSE Branch
    if (node.else_branch) {
        result /= (Doc::keyword("else") << join(node.else_branch->body, Doc::line()));
    }

    // 3. END IF
    return result / (Doc::keyword("end") & Doc::keyword("if") + Doc::text(";"));
}

} // namespace emit
