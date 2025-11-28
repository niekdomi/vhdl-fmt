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
    Doc result = visit(node.target) & Doc::text("<=");

    const auto make_wave = [&](const auto &wave) {
        Doc d = visit(wave.value);
        if (wave.condition) {
            d &= Doc::text("when") & visit(*wave.condition);
        }
        return d;
    };

    // Join with "else" and a newline
    Doc waveforms = joinMap(node.waveforms, Doc::text(" else") + Doc::line(), make_wave, false);

    // Indent the waveforms relative to the target
    return (result << waveforms) + Doc::text(";");
}

// TODO(vedivad): This needs a hang combinator for better readability
// with selector select
//     target <= val1 when choice1,
//               val2 when choice2;
auto PrettyPrinter::operator()(const ast::SelectedConcurrentAssign &node) const -> Doc
{
    Doc header = Doc::text("with") & visit(node.selector) & Doc::text("select");
    Doc target = visit(node.target) & Doc::text("<=");

    const auto make_sel = [&](const auto &sel) {
        Doc val = visit(sel.value);
        Doc choices = joinMap(sel.choices, Doc::text(" | "), toDoc(*this), false);
        return val & Doc::text("when") & choices;
    };

    // Join selections with comma
    Doc selections = joinMap(node.selections, Doc::text(",") + Doc::line(), make_sel, false);

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

auto PrettyPrinter::operator()(const ast::IfStatement &node) const -> Doc
{
    // 1. IF Header & Body
    Doc result = (Doc::text("if") & visit(node.if_branch.condition) & Doc::text("then"))
              << joinMap(node.if_branch.body, Doc::line(), toDoc(*this), false);

    // 2. ELSIF (Optional)
    if (!node.elsif_branches.empty()) {
        const auto make_elsif = [&](const auto &branch) {
            return (Doc::text("elsif") & visit(branch.condition) & Doc::text("then"))
                << joinMap(branch.body, Doc::line(), toDoc(*this), false);
        };

        result /= joinMap(node.elsif_branches, Doc::line(), make_elsif, false);
    }

    // 3. ELSE (Optional)
    if (node.else_branch) {
        result /= (Doc::text("else")
                   << joinMap(node.else_branch->body, Doc::line(), toDoc(*this), false));
    }

    // 4. END IF
    return result / Doc::text("end if;");
}

auto PrettyPrinter::operator()(const ast::CaseStatement &node) const -> Doc
{
    const Doc head = Doc::text("case") & visit(node.selector) & Doc::text("is");

    const Doc body = joinMap(
      node.when_clauses,
      Doc::line(),
      [this](const auto &clause) {
          // Join choices: "1 | 2 | 3"
          const Doc choices = joinMap(clause.choices, Doc::text(" | "), toDoc(*this), false);
          const Doc when_head = Doc::text("when") & choices & Doc::text("=>");
          const Doc when_body = joinMap(clause.body, Doc::line(), toDoc(*this), false);

          return when_head << when_body;
      },
      false);

    const Doc end = Doc::text("end case;");

    return Doc::bracket(head, body, end);
}

auto PrettyPrinter::operator()(const ast::Process &node) const -> Doc
{
    Doc head = Doc::text("process");

    // Sensitivity list: process(clk, rst)
    if (!node.sensitivity_list.empty()) {
        const Doc list = joinMap(
          node.sensitivity_list,
          Doc::text(", "),
          [](const auto &s) { return Doc::text(s); },
          false);

        head += Doc::text("(") + list + Doc::text(")");
    }

    // Declarations
    if (!node.decls.empty()) {
        head <<= joinMap(node.decls, Doc::line(), toDoc(*this), false);
    }

    head /= Doc::text("begin");

    // Body
    Doc body = Doc::empty();
    if (!node.body.empty()) {
        body += joinMap(node.body, Doc::line(), toDoc(*this), false);
    }

    const Doc end = Doc::text("end process;");

    return Doc::bracket(head, body, end);
}

auto PrettyPrinter::operator()(const ast::ForLoop &node) const -> Doc
{
    const Doc head = Doc::text("for")
                   & Doc::text(node.iterator)
                   & Doc::text("in")
                   & visit(node.range)
                   & Doc::text("loop");

    const Doc body = joinMap(node.body, Doc::line(), toDoc(*this), false);
    const Doc end = Doc::text("end loop;");

    return Doc::bracket(head, body, end);
}

auto PrettyPrinter::operator()(const ast::WhileLoop &node) const -> Doc
{
    const Doc head = Doc::text("while") & visit(node.condition) & Doc::text("loop");
    const Doc body = joinMap(node.body, Doc::line(), toDoc(*this), false);
    const Doc end = Doc::text("end loop;");

    return Doc::bracket(head, body, end);
}

} // namespace emit
