#include "ast/nodes/statements.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

#include <cstddef>
#include <ranges>
#include <utility>

namespace builder {

auto Translator::makeConcurrentAssign(
  vhdlParser::Concurrent_signal_assignment_statementContext *ctx) -> ast::ConcurrentStatement
{
    // Dispatch based on concrete assignment type
    if (auto *cond = ctx->conditional_signal_assignment()) {
        return makeConditionalAssign(cond);
    }

    // Can only be Selected assignment here
    auto *sel = ctx->selected_signal_assignment();
    return makeSelectedAssign(sel);
}

auto Translator::makeConditionalAssign(vhdlParser::Conditional_signal_assignmentContext *ctx)
  -> ast::ConditionalConcurrentAssign
{
    auto assign = make<ast::ConditionalConcurrentAssign>(ctx);

    if (auto *target_ctx = ctx->target()) {
        assign.target = makeTarget(target_ctx);
    }

    // Flatten the recursive conditional waveforms:
    // val1 when cond1 else val2 when cond2 else val3
    auto *current_wave = ctx->conditional_waveforms();
    while (current_wave != nullptr) {
        ast::ConditionalConcurrentAssign::Waveform wave_item;

        // 1. Value (Waveform)
        // TODO(vedivad): Simplified to first element for now
        if (auto *w = current_wave->waveform()) {
            if (!w->waveform_element().empty()) {
                wave_item.value = makeExpr(w->waveform_element(0)->expression(0));
            }
        }

        // 2. Condition (WHEN ...)
        if (auto *cond = current_wave->condition()) {
            wave_item.condition = makeExpr(cond->expression());
        }

        assign.waveforms.push_back(std::move(wave_item));

        // 3. Recurse (ELSE ...)
        // The grammar defines recursive structure for 'else'
        current_wave = current_wave->conditional_waveforms();
    }

    return assign;
}

auto Translator::makeSelectedAssign(vhdlParser::Selected_signal_assignmentContext *ctx)
  -> ast::SelectedConcurrentAssign
{
    auto assign = make<ast::SelectedConcurrentAssign>(ctx);

    // WITH expression ...
    if (auto *expr = ctx->expression()) {
        assign.selector = makeExpr(expr);
    }

    if (auto *target_ctx = ctx->target()) {
        assign.target = makeTarget(target_ctx);
    }

    // ... SELECT target <= opts waveforms
    if (auto *sel_waves = ctx->selected_waveforms()) {
        const auto waves = sel_waves->waveform();
        const auto choices = sel_waves->choices();

        for (size_t i = 0; i < waves.size(); ++i) {
            ast::SelectedConcurrentAssign::Selection selection{};

            // Value
            if (!waves[i]->waveform_element().empty()) {
                selection.value = makeExpr(waves[i]->waveform_element(0)->expression(0));
            }

            // Choices (1 | 2 | others)
            if (i < choices.size()) {
                if (auto *ch_ctx = choices[i]) {
                    for (auto *c : ch_ctx->choice()) {
                        selection.choices.push_back(makeChoice(c));
                    }
                }
            }

            assign.selections.push_back(std::move(selection));
        }
    }

    return assign;
}

auto Translator::makeProcess(vhdlParser::Process_statementContext *ctx) -> ast::Process
{
    auto proc = make<ast::Process>(ctx);

    // Extract label if present
    if (auto *label = ctx->label_colon()) {
        if (auto *id = label->identifier()) {
            proc.label = id->getText();
        }
    }

    // Extract sensitivity list
    if (auto *sens_list = ctx->sensitivity_list()) {
        proc.sensitivity_list = sens_list->name()
                              | std::views::transform([](auto *name) { return name->getText(); })
                              | std::ranges::to<std::vector>();
    }

    // 3. Declarations
    if (auto *decl_part = ctx->process_declarative_part()) {
        for (auto *item : decl_part->process_declarative_item()) {
            // Check for Variable
            if (auto *var_ctx = item->variable_declaration()) {
                proc.decls.emplace_back(makeVariableDecl(var_ctx));
            }
            // Check for Constant
            else if (auto *const_ctx = item->constant_declaration()) {
                proc.decls.emplace_back(makeConstantDecl(const_ctx));
            }
            // TODO(vedivad): Add Types, Files, Aliases here as you support them
        }
    }

    // Extract sequential statements
    if (auto *stmt_part = ctx->process_statement_part()) {
        const auto &source_stmts = stmt_part->sequential_statement();

        proc.body.reserve(source_stmts.size());

        for (auto *stmt_ctx : source_stmts) {
            if (auto stmt = makeSequentialStatement(stmt_ctx)) {
                proc.body.emplace_back(std::move(*stmt));
            }
        }
    }

    return proc;
}

} // namespace builder
