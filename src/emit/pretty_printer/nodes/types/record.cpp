#include "ast/nodes/types.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

#include <ranges>
#include <string>

namespace emit {

namespace {

/// @brief Local constants for record element alignment.
struct AlignmentLevel
{
    static constexpr int NAME = 0; ///< Column 0: Field names
};

} // namespace

auto PrettyPrinter::operator()(const ast::RecordElement &node) const -> Doc
{
    const std::string names = node.names
                            | std::views::join_with(std::string_view{ ", " })
                            | std::ranges::to<std::string>();

    const Doc result
      = Doc::text(names, AlignmentLevel::NAME) & Doc::text(":") & visit(node.subtype);

    return result + Doc::text(";");
}

auto PrettyPrinter::operator()(const ast::RecordTypeDef &node) const -> Doc
{
    const Doc head = Doc::keyword(("record"));
    Doc end = Doc::keyword(("end")) & Doc::keyword(("record"));

    if (node.end_label) {
        end &= Doc::text(*node.end_label);
    }

    if (node.elements.empty()) {
        return head & end;
    }

    return Doc::align(Doc::bracket(head, join(node.elements, Doc::line()), end));
}

} // namespace emit
