#include "ast/nodes/statements/concurrent.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

namespace emit {

auto PrettyPrinter::operator()(const ast::ComponentInstantiation& node) const -> Doc
{
    // Entity/component name
    Doc head = Doc::text(node.entity_name);

    // Generic map (if present)
    if (!node.generic_map.empty()) {
        const Doc opener = Doc::keyword("generic") & Doc::keyword("map") & Doc::text("(");
        const Doc closer = Doc::text(")");

        const Doc mappings = joinMap(node.generic_map,
                                     Doc::text(",") + Doc::line(),
                                     [&](const auto& expr) { return visit(expr); });

        head <<= Doc::bracket(opener, mappings, closer);
    }

    // Port map (if present)
    if (!node.port_map.empty()) {
        const Doc opener = Doc::keyword("port") & Doc::keyword("map") & Doc::text("(");
        const Doc closer = Doc::text(");");

        const Doc mappings = joinMap(node.port_map,
                                     Doc::text(",") + Doc::line(),
                                     [&](const auto& expr) { return visit(expr); });

        head <<= Doc::bracket(opener, mappings, closer);
    } else {
        // No port map, just add semicolon
        head += Doc::text(";");
    }

    return head;
}

} // namespace emit
