#include "ast/nodes/expressions.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

#include <algorithm>
#include <cctype>

namespace emit {

auto PrettyPrinter::operator()(const ast::BinaryExpr &node) const -> Doc
{
    // Only wrap in keyword() if it is a word like "and", "xor", "mod"
    const bool is_word_op
      = std::ranges::any_of(node.op, [](unsigned char c) -> int { return std::isalpha(c); });

    const Doc op_doc = is_word_op ? Doc::keyword((node.op)) : Doc::text(node.op);

    return visit(*node.left) & op_doc & visit(*node.right);
}

} // namespace emit
