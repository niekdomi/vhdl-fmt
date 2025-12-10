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

} // namespace emit
