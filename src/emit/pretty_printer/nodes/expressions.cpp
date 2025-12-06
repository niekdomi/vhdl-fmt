#include "ast/nodes/expressions.hpp"

#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"
#include "emit/pretty_printer/doc_utils.hpp"

#include <algorithm>
#include <cctype>

namespace emit {

auto PrettyPrinter::operator()(const ast::TokenExpr &node) const -> Doc
{
    return Doc::text(node.text);
}

auto PrettyPrinter::operator()(const ast::PhysicalLiteral &node) const -> Doc
{
    return Doc::text(node.value) & Doc::text(node.unit);
}

auto PrettyPrinter::operator()(const ast::GroupExpr &node) const -> Doc
{
    const Doc result
      = joinMap(node.children, Doc::text(", "), [this](const auto &c) { return visit(c); }, false);

    return Doc::text("(") + result + Doc::text(")");
}

auto PrettyPrinter::operator()(const ast::UnaryExpr &node) const -> Doc
{
    // Check if the operator contains letters (is a keyword like 'not', 'abs', 'xor')
    const bool is_keyword
      = std::ranges::any_of(node.op, [](unsigned char c) -> int { return std::isalpha(c); });

    // If keyword, add space between operator and value
    if (is_keyword) {
        return Doc::text(node.op) & visit(*node.value);
    }

    return Doc::text(node.op) + visit(*node.value);
}

auto PrettyPrinter::operator()(const ast::BinaryExpr &node) const -> Doc
{
    return visit(*node.left) & Doc::text(node.op) & visit(*node.right);
}

auto PrettyPrinter::operator()(const ast::AttributeExpr &node) const -> Doc
{
    Doc result = visit(*node.prefix) + Doc::text("'") + Doc::text(node.attribute);

    if (node.arg.has_value()) {
        result += Doc::text("(") + visit(**node.arg) + Doc::text(")");
    }

    return result;
}

auto PrettyPrinter::operator()(const ast::QualifiedExpr &node) const -> Doc
{
    return Doc::text(node.type_mark) + Doc::text("'") + visit(*node.operand);
}

auto PrettyPrinter::operator()(const ast::ParenExpr &node) const -> Doc
{
    return Doc::text("(") + visit(*node.inner) + Doc::text(")");
}

auto PrettyPrinter::operator()(const ast::CallExpr &node) const -> Doc
{
    return visit(*node.callee) + Doc::text("(") + visit(*node.args) + Doc::text(")");
}

} // namespace emit
