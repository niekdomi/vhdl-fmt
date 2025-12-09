#include "ast/nodes/types.hpp"

#include "common/overload.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

#include <ranges>
#include <string>
#include <string_view>

namespace emit {

namespace {

/// @brief Local constants for record element alignment.
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

    return Doc::text("(") + Doc::text(literals) + Doc::text(")");
}

auto PrettyPrinter::operator()(const ast::RecordElement &node) const -> Doc
{
    const std::string names = node.names
                            | std::views::join_with(std::string_view{ ", " })
                            | std::ranges::to<std::string>();

    const Doc result
      = Doc::alignText(names, AlignmentLevel::NAME) & Doc::text(":") & visit(node.subtype);

    return result + Doc::text(";");
}

auto PrettyPrinter::operator()(const ast::RecordTypeDef &node) const -> Doc
{
    const Doc head = Doc::text(keyword("record"));
    Doc end = Doc::text(keyword("end")) & Doc::text(keyword("record"));

    if (node.end_label) {
        end &= Doc::text(*node.end_label);
    }

    if (node.elements.empty()) {
        return head & end;
    }

    return Doc::align(Doc::bracket(head, join(node.elements, Doc::line()), end));
}

auto PrettyPrinter::operator()(const ast::ArrayTypeDef &node) const -> Doc
{
    Doc result = Doc::text(keyword("array"));

    if (!node.indices.empty()) {
        auto render_index = [&](const auto &idx) {
            return std::visit(
              common::Overload{ [&](const std::string &s) -> Doc {
                                   return Doc::text(s)
                                        & Doc::text(keyword("range"))
                                        & Doc::text("<>");
                               },
                                [&](const auto &expr) -> Doc { return visit(expr); } },
              idx);
        };

        result
          += Doc::text("(") + joinMap(node.indices, Doc::text(", "), render_index) + Doc::text(")");
    }

    result &= Doc::text(keyword("of")) & visit(node.subtype);

    return result;
}

auto PrettyPrinter::operator()(const ast::AccessTypeDef &node) const -> Doc
{
    return Doc::text(keyword("access")) & visit(node.subtype);
}

auto PrettyPrinter::operator()(const ast::FileTypeDef &node) const -> Doc
{
    return Doc::text(keyword("file")) & Doc::text(keyword("of")) & visit(node.subtype);
}

} // namespace emit
