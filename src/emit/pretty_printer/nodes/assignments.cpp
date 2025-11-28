#include "ast/nodes/statements.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"
#include "emit/pretty_printer/doc_utils.hpp"

namespace emit {

// TODO(vedivad): This needs a hang combinator for better readability
// target <= val1 when cond1 else
//           val2 when cond2 else
//           val3;
auto PrettyPrinter::operator()(const ast::ConditionalConcurrentAssign &node) const -> Doc
{
    const Doc result = visit(node.target) & Doc::text("<=");

    const auto make_wave = [&](const auto &wave) {
        Doc d = visit(wave.value);
        if (wave.condition) {
            d &= Doc::text("when") & visit(*wave.condition);
        }
        return d;
    };

    // Join with "else" and a newline
    const Doc waveforms
      = joinMap(node.waveforms, Doc::text(" else") + Doc::line(), make_wave, false);

    // Indent the waveforms relative to the target
    return (result << waveforms) + Doc::text(";");
}

// TODO(vedivad): This needs a hang combinator for better readability
// with selector select
//     target <= val1 when choice1,
//               val2 when choice2;
auto PrettyPrinter::operator()(const ast::SelectedConcurrentAssign &node) const -> Doc
{
    const Doc header = Doc::text("with") & visit(node.selector) & Doc::text("select");
    const Doc target = visit(node.target) & Doc::text("<=");

    const auto make_sel = [&](const auto &sel) {
        const Doc val = visit(sel.value);
        const Doc choices = joinMap(sel.choices, Doc::text(" | "), toDoc(*this), false);
        return val & Doc::text("when") & choices;
    };

    // Join selections with comma
    const Doc selections = joinMap(node.selections, Doc::text(",") + Doc::line(), make_sel, false);

    // Layout:
    // Header
    //   Target <= Selections;
    return header / (target << selections) + Doc::text(";");
}

auto PrettyPrinter::operator()(const ast::SignalAssign &node) const -> Doc
{
    return visit(node.target) & Doc::text("<=") & visit(node.value) + Doc::text(";");
}

auto PrettyPrinter::operator()(const ast::VariableAssign &node) const -> Doc
{
    return visit(node.target) & Doc::text(":=") & visit(node.value) + Doc::text(";");
}

} // namespace emit
