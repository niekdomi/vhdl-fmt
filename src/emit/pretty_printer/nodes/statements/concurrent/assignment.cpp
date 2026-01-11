#include "ast/nodes/statements/concurrent.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

namespace emit {

auto PrettyPrinter::operator()(
  const ast::ConditionalConcurrentAssign::ConditionalWaveform &node) const -> Doc
{
    Doc d = visit(node.waveform);
    if (node.condition) {
        d &= Doc::keyword(("when")) & visit(*node.condition);
    }
    return d;
}

// Layout:
// label: target <= val1 when cond1 else
//                  val2 when cond2 else
//                  val3;
auto PrettyPrinter::operator()(const ast::ConditionalConcurrentAssign &node) const -> Doc
{
    const Doc result = Doc::empty();

    const Doc target = visit(node.target) & Doc::text("<=");

    // Join with "else" + SoftLine
    // If it breaks, the next line starts at the hung indent level.
    const Doc waveforms
      = join(node.waveforms, Doc::text(" ") + Doc::keyword(("else")) + Doc::line());

    const Doc assignment = Doc::group(target & Doc::hang(waveforms)) + Doc::text(";");

    return result.isEmpty() ? assignment : result & assignment;
}

auto PrettyPrinter::operator()(const ast::SelectedConcurrentAssign::Selection &node) const -> Doc
{
    const Doc val = visit(node.waveform);
    const Doc choices = join(node.choices, Doc::text(" | "));
    return val & Doc::keyword(("when")) & choices;
}

// Layout:
// label: with selector select
//          target <= val1 when choice1,
//                    val2 when choice2;
auto PrettyPrinter::operator()(const ast::SelectedConcurrentAssign &node) const -> Doc
{
    const Doc result = Doc::empty();

    const Doc header = Doc::keyword(("with")) & visit(node.selector) & Doc::keyword(("select"));
    const Doc target = visit(node.target) & Doc::text("<=");

    // Join selections with comma + SoftLine
    const Doc selections = join(node.selections, Doc::text(",") + Doc::line());

    // For selected assignment, the target itself is nested under the header,
    // and the selections hang off the target.
    const Doc assignment = Doc::group(header / (target & Doc::hang(selections)) + Doc::text(";"));

    return result.isEmpty() ? assignment : result & assignment;
}

} // namespace emit
