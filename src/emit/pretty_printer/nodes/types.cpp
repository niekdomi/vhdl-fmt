#include "ast/nodes/types.hpp"

#include "common/overload.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"
#include "emit/pretty_printer/doc_utils.hpp"

#include <ranges>
#include <string>
#include <string_view>

namespace emit {

namespace {

/// @brief Local constants for record element alignment (matches declarations.cpp).
struct AlignmentLevel
{
    static constexpr int NAME = 0; ///< Column 0: Field names
};

} // namespace

auto PrettyPrinter::operator()(const ast::EnumerationTypeDef &node) const -> Doc
{
    if (node.literals.empty()) {
        return Doc::text("()");
    }

    const std::string literals = node.literals
                               | std::views::join_with(std::string_view{ ", " })
                               | std::ranges::to<std::string>();

    // Result: (A, B, C)
    // The wrapping group is handled by Doc::group in TypeDecl if necessary,
    // but usually enums fit on one line.
    return Doc::text("(") + Doc::text(literals) + Doc::text(")");
}

auto PrettyPrinter::operator()(const ast::RecordElement &node) const -> Doc
{
    // field1, field2 : type_name;
    const std::string names = node.names
                            | std::views::join_with(std::string_view{ ", " })
                            | std::ranges::to<std::string>();

    Doc result
      = Doc::alignText(names, AlignmentLevel::NAME) & Doc::text(":") & Doc::text(node.type_name);

    if (node.constraint) {
        result += visit(node.constraint.value());
    }

    return result + Doc::text(";");
}

auto PrettyPrinter::operator()(const ast::RecordTypeDef &node) const -> Doc
{
    const Doc head = Doc::text("record");
    Doc end = Doc::text("end record");

    if (node.end_label) {
        end &= Doc::text(*node.end_label);
    }

    if (node.elements.empty()) {
        return head & end;
    }

    return Doc::align(
      Doc::bracket(head, joinMap(node.elements, Doc::line(), toDoc(*this), false), end));
}

auto PrettyPrinter::operator()(const ast::ArrayTypeDef &node) const -> Doc
{
    Doc result = Doc::text("array");

    if (!node.indices.empty()) {
        auto render_index = [&](const auto &idx) {
            return std::visit(
              common::Overload{
                [](const std::string &s) -> Doc { return Doc::text(s + " range <>"); },
                [&](const auto &expr) -> Doc { return visit(expr); } },
              idx);
        };

        result += Doc::text("(")
                + joinMap(node.indices, Doc::text(", "), render_index, false)
                + Doc::text(")");
    }

    result &= Doc::text("of") & Doc::text(node.element_type);

    if (node.element_constraint) {
        result += visit(node.element_constraint.value());
    }

    return result;
}

auto PrettyPrinter::operator()(const ast::AccessTypeDef &node) const -> Doc
{
    return Doc::text("access") & Doc::text(node.pointed_type);
}

auto PrettyPrinter::operator()(const ast::FileTypeDef &node) const -> Doc
{
    return Doc::text("file of") & Doc::text(node.content_type);
}

} // namespace emit
