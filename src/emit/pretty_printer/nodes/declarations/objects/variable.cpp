#include "ast/nodes/declarations/objects.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"
#include "emit/pretty_printer/nodes/alignment.hpp"

#include <ranges>
#include <string>

namespace emit {

auto PrettyPrinter::operator()(const ast::VariableDecl& node) const -> Doc
{
    const std::string names =
      node.names | std::views::join_with(std::string_view{", "}) | std::ranges::to<std::string>();

    // "variable x, y : integer"
    Doc result =
      (node.shared ? (Doc::keyword("shared") & Doc::keyword("variable")) : Doc::keyword("variable"))
      & Doc::text(names, AlignmentLevel::NAME)
      & Doc::text(":")
      & visit(node.subtype);

    if (node.init_expr) {
        result &= Doc::text(":=") & visit(node.init_expr.value());
    }

    return result + Doc::text(";");
}

} // namespace emit
