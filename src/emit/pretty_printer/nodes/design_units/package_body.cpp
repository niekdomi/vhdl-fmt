#include "ast/nodes/design_units.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

#include <algorithm>
#include <optional>

namespace emit {

auto PrettyPrinter::operator()(const ast::PackageBody& node) const -> Doc
{
    // Emit package body declaration
    Doc result =
      Doc::keyword("package") & Doc::keyword("body") & Doc::text(node.name) & Doc::keyword("is");

    // Declarations
    result = std::ranges::fold_left(
      node.decls, result, [this](auto acc, const auto& decl) { return acc <<= visit(decl); });

    Doc end_line = Doc::keyword("end");
    if (node.has_end_package_body_keyword) {
        end_line &= Doc::keyword("package") & Doc::keyword("body");
    }
    if (node.end_label.has_value()) {
        end_line &= Doc::text(*node.end_label);
    }
    end_line += Doc::text(";");

    return result / end_line;
}

} // namespace emit
