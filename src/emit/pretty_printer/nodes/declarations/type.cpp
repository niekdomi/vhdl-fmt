#include "ast/nodes/declarations.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

namespace emit {

auto PrettyPrinter::operator()(const ast::TypeDecl &node) const -> Doc
{
    Doc result = Doc::keyword(("type")) & Doc::text(node.name);

    if (!node.type_def.has_value()) {
        // Incomplete type declaration: "type <name>;"
        return result + Doc::text(";");
    }

    // "is <definition>"
    result &= Doc::keyword(("is")) & visit(node.type_def.value());

    return result + Doc::text(";");
}

} // namespace emit
