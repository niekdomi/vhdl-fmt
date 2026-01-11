#include "ast/nodes/statements/sequential.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

namespace emit {

auto PrettyPrinter::operator()(const ast::NullStatement & /*node*/) const -> Doc
{
    return Doc::keyword(("null")) + Doc::text(";");
}

} // namespace emit
