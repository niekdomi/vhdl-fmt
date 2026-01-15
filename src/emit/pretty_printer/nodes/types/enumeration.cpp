#include "ast/nodes/types.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

#include <ranges>
#include <string>

namespace emit {

auto PrettyPrinter::operator()(const ast::EnumerationTypeDef& node) const -> Doc
{
    if (node.literals.empty()) {
        return Doc::text("()");
    }

    const std::string literals = node.literals
                               | std::views::join_with(std::string_view{", "})
                               | std::ranges::to<std::string>();

    return Doc::text("(") + Doc::text(literals) + Doc::text(")");
}

} // namespace emit
