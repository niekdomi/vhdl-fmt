#include "ast/nodes/design_file.hpp"

#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

#include <ranges>

namespace emit {

auto PrettyPrinter::operator()(const ast::DesignFile &node) const -> Doc
{
    if (std::ranges::empty(node.units)) {
        return Doc::empty();
    }

    const auto result = join(node.units, Doc::line());

    return result + Doc::line(); // Trailing newline
}

} // namespace emit
