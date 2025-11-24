#include "ast/nodes/design_file.hpp"

#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"
#include "emit/pretty_printer/doc_utils.hpp"

#include <ranges>

namespace emit {

auto PrettyPrinter::operator()(const ast::DesignFile &node) const -> Doc
{
    if (std::ranges::empty(node.units)) {
        return Doc::empty();
    }

    const auto result
      = joinMap(node.units, Doc::line(), [this](const auto &u) { return visit(u); }, false);

    return result + Doc::line(); // Trailing newline
}

} // namespace emit
