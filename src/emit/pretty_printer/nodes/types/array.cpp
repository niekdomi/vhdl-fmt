#include "ast/nodes/types.hpp"
#include "common/overload.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

#include <string>
#include <variant>

namespace emit {

auto PrettyPrinter::operator()(const ast::ArrayTypeDef& node) const -> Doc
{
    Doc result = Doc::keyword("array");

    if (!node.indices.empty()) {
        auto render_index = [&](const auto& idx) {
            return std::visit(
              common::Overload{[&](const std::string& s) -> Doc {
                                   return Doc::text(s) & Doc::keyword("range") & Doc::text("<>");
                               },
                               [&](const auto& expr) -> Doc { return visit(expr); }},
              idx);
        };

        result +=
          Doc::text("(") + joinMap(node.indices, Doc::text(", "), render_index) + Doc::text(")");
    }

    result &= Doc::keyword("of") & visit(node.subtype);

    return result;
}

} // namespace emit
