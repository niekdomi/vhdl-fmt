#include "ast/nodes/statements/concurrent.hpp"
#include "ast/nodes/statements/sequential.hpp"
#include "ast/nodes/statements/waveform.hpp"
#include "emit/pretty_printer.hpp"
#include "emit/pretty_printer/doc.hpp"

namespace emit {

auto PrettyPrinter::operator()(const ast::Waveform::Element &node, const bool is_last) const -> Doc
{
    Doc doc = visit(node.value);
    if (node.after) {
        doc &= Doc::text(keyword("after")) & visit(*node.after);
    }
    return is_last ? doc : doc + Doc::text(",");
}

auto PrettyPrinter::operator()(const ast::Waveform &node) const -> Doc
{
    if (node.is_unaffected) {
        return Doc::text(keyword("unaffected"));
    }

    return joinMap(node.elements, Doc::line(), [&](const auto &elem) {
        const bool is_last = (&elem == &node.elements.back());
        return visit(elem, is_last);
    });
}

auto PrettyPrinter::operator()(
  const ast::ConditionalConcurrentAssign::ConditionalWaveform &node) const -> Doc
{
    Doc d = visit(node.waveform);
    if (node.condition) {
        d &= Doc::text(keyword("when")) & visit(*node.condition);
    }
    return d;
}

// Layout:
// label: target <= val1 when cond1 else
//                  val2 when cond2 else
//                  val3;
auto PrettyPrinter::operator()(const ast::ConditionalConcurrentAssign &node) const -> Doc
{
    Doc result = Doc::empty();

    // Label: label:
    if (node.label) {
        result = Doc::text(*node.label + ":");
    }

    const Doc target = visit(node.target) & Doc::text("<=");

    // Join with "else" + SoftLine
    // If it breaks, the next line starts at the hung indent level.
    const Doc waveforms = join(node.waveforms, Doc::text(keyword(" else")) + Doc::line());

    const Doc assignment = Doc::group(target & Doc::hang(waveforms)) + Doc::text(";");

    return result.isEmpty() ? assignment : result & assignment;
}

auto PrettyPrinter::operator()(const ast::SelectedConcurrentAssign::Selection &node) const -> Doc
{
    const Doc val = visit(node.waveform);
    const Doc choices = join(node.choices, Doc::text(" | "));
    return val & Doc::text(keyword("when")) & choices;
}

// Layout:
// label: with selector select
//          target <= val1 when choice1,
//                    val2 when choice2;
auto PrettyPrinter::operator()(const ast::SelectedConcurrentAssign &node) const -> Doc
{
    Doc result = Doc::empty();

    // Label: label:
    if (node.label) {
        result = Doc::text(*node.label + ":");
    }

    const Doc header
      = Doc::text(keyword("with")) & visit(node.selector) & Doc::text(keyword("select"));
    const Doc target = visit(node.target) & Doc::text("<=");

    // Join selections with comma + SoftLine
    const Doc selections = join(node.selections, Doc::text(",") + Doc::line());

    // For selected assignment, the target itself is nested under the header,
    // and the selections hang off the target.
    const Doc assignment = Doc::group(header / (target & Doc::hang(selections)) + Doc::text(";"));

    return result.isEmpty() ? assignment : result & assignment;
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

auto PrettyPrinter::operator()(const ast::NullStatement & /*node*/) const -> Doc
{
    return Doc::text(keyword("null")) + Doc::text(";");
}

} // namespace emit
