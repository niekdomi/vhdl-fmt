#include "ast/nodes/expressions.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

#include <algorithm>
#include <cctype>

namespace emit {

auto PrettyPrinter::operator()(const ast::UnaryExpr &node) const -> Doc
{
    // Check if the operator contains letters (is a keyword like 'not', 'abs', 'xor')
    const bool is_keyword
      = std::ranges::any_of(node.op, [](unsigned char c) -> int { return std::isalpha(c); });

    // If keyword, add space between operator and value
    if (is_keyword) {
        return Doc::keyword((node.op)) & visit(*node.value);
    }

    return Doc::text(node.op) + visit(*node.value);
}

} // namespace emit
