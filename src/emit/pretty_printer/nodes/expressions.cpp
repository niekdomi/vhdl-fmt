#include "ast/nodes/expressions.hpp"

#include "common/overload.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

#include <algorithm>
#include <cctype>
#include <variant>

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
    const Doc result = join(node.children, Doc::text(", "));
    return Doc::text("(") + result + Doc::text(")");
}

auto PrettyPrinter::operator()(const ast::UnaryExpr &node) const -> Doc
{
    // Check if the operator contains letters (is a keyword like 'not', 'abs', 'xor')
    const bool is_keyword
      = std::ranges::any_of(node.op, [](unsigned char c) -> int { return std::isalpha(c); });

    // If keyword, add space between operator and value
    if (is_keyword) {
        return Doc::text(keyword(node.op)) & visit(*node.value);
    }

    return Doc::text(node.op) + visit(*node.value);
}

auto PrettyPrinter::operator()(const ast::BinaryExpr &node) const -> Doc
{
    return visit(*node.left) & Doc::text(keyword(node.op)) & visit(*node.right);
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
    return visit(node.type_mark) + Doc::text("'") + visit(*node.operand);
}

auto PrettyPrinter::operator()(const ast::ParenExpr &node) const -> Doc
{
    return Doc::text("(") + visit(*node.inner) + Doc::text(")");
}

auto PrettyPrinter::operator()(const ast::CallExpr &node) const -> Doc
{
    // GroupExpr already provides parentheses, so just visit directly
    return visit(*node.callee) + visit(*node.args);
}

auto PrettyPrinter::operator()(const ast::SliceExpr &node) const -> Doc
{
    return visit(*node.prefix) + Doc::text("(") + visit(*node.range) + Doc::text(")");
}

auto PrettyPrinter::operator()(const ast::SubtypeIndication &node) const -> Doc
{
    Doc result = Doc::empty();

    // Resolution Function (e.g., "resolved")
    if (node.resolution_func) {
        result += Doc::text(*node.resolution_func) + Doc::text(" ");
    }

    // Type Mark (e.g., "std_logic")
    result += Doc::text(node.type_mark);

    // Constraint (e.g., "(7 downto 0)")
    if (node.constraint) {
        result += std::visit(
          common::Overload{
            [this](const ast::IndexConstraint &idx) -> Doc { return visit(idx); },
            [this](const ast::RangeConstraint &rc) -> Doc { return Doc::text(" ") + visit(rc); },
          },
          node.constraint.value());
    }

    return result;
}

} // namespace emit
