#include "ast/nodes/statements.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"
#include "emit/pretty_printer/doc_utils.hpp"

namespace emit {

auto PrettyPrinter::operator()(const ast::Waveform &node) const -> Doc
{
    if (node.is_unaffected) {
        return Doc::text("unaffected");
    }

    // Helper to format "value [after time]"
    const auto format_elem = [&](const ast::Waveform::Element &elem) -> Doc {
        Doc d = visit(elem.value);
        if (elem.after) {
            d += Doc::text(" after ") + visit(*elem.after);
        }
        return d;
    };

    // Join elements with ", "
    // Using Doc::line() allows wrapping: "1 after 5 ns," / "0 after 10 ns"
    return joinMap(node.elements, Doc::text(",") + Doc::line(), format_elem, false);
}

// Layout:
// target <= val1 when cond1 else
//           val2 when cond2 else
//           val3;
auto PrettyPrinter::operator()(const ast::ConditionalConcurrentAssign &node) const -> Doc
{
    const Doc target = visit(node.target) & Doc::text("<=");

    const auto make_cond_wave = [&](const auto &item) {
        Doc d = visit(item.waveform);
        if (item.condition) {
            d &= Doc::text("when") & visit(*item.condition);
        }
        return d;
    };

    // Join with "else" + SoftLine
    // If it breaks, the next line starts at the hung indent level.
    const Doc waveforms
      = joinMap(node.waveforms, Doc::text(" else") + Doc::line(), make_cond_wave, false);

    return Doc::group(target & Doc::hang(waveforms)) + Doc::text(";");
}

// Layout:
// with selector select
//   target <= val1 when choice1,
//             val2 when choice2;
auto PrettyPrinter::operator()(const ast::SelectedConcurrentAssign &node) const -> Doc
{
    const Doc header = Doc::text("with") & visit(node.selector) & Doc::text("select");
    const Doc target = visit(node.target) & Doc::text("<=");

    const auto make_sel = [&](const auto &sel) {
        const Doc val = visit(sel.waveform);
        const Doc choices = joinMap(sel.choices, Doc::text(" | "), toDoc(*this), false);
        return val & Doc::text("when") & choices;
    };

    // Join selections with comma + SoftLine
    const Doc selections = joinMap(node.selections, Doc::text(",") + Doc::line(), make_sel, false);

    // For selected assignment, the target itself is nested under the header,
    // and the selections hang off the target.
    return Doc::group(header / (target & Doc::hang(selections)) + Doc::text(";"));
}

// Layout:
// target <= val1,
//           val2;
auto PrettyPrinter::operator()(const ast::SignalAssign &node) const -> Doc
{
    const Doc wave = visit(node.waveform);

    return Doc::group(visit(node.target) & Doc::text("<=") & Doc::hang(wave)) + Doc::text(";");
}

auto PrettyPrinter::operator()(const ast::VariableAssign &node) const -> Doc
{
    const Doc val = visit(node.value);

    return Doc::group(visit(node.target) & Doc::text(":=") & Doc::hang(val)) + Doc::text(";");
}

} // namespace emit
