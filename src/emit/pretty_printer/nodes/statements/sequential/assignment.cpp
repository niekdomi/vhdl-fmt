#include "ast/nodes/statements/sequential.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

namespace emit {

// Layout:
// target <= val1,
//           val2;
auto PrettyPrinter::operator()(const ast::SignalAssign& node) const -> Doc
{
    const Doc wave = visit(node.waveform);

    return Doc::group(visit(node.target) & Doc::text("<=") & Doc::hang(wave)) + Doc::text(";");
}

auto PrettyPrinter::operator()(const ast::VariableAssign& node) const -> Doc
{
    const Doc val = visit(node.value);

    return Doc::group(visit(node.target) & Doc::text(":=") & Doc::hang(val)) + Doc::text(";");
}

} // namespace emit
