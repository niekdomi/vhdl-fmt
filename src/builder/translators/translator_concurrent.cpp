#include "ast/nodes/statements.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

#include <ranges>

namespace builder {

auto Translator::makeConcurrentAssign(
  vhdlParser::Concurrent_signal_assignment_statementContext *ctx) -> ast::ConcurrentAssign
{
    // Dispatch based on concrete assignment type
    if (auto *cond = ctx->conditional_signal_assignment()) {
        return makeConditionalAssign(cond);
    }
    if (auto *sel = ctx->selected_signal_assignment()) {
        return makeSelectedAssign(sel);
    }

    // Fallback for unhandled cases
    return make<ast::ConcurrentAssign>(ctx);
}

auto Translator::makeConditionalAssign(vhdlParser::Conditional_signal_assignmentContext *ctx)
  -> ast::ConcurrentAssign
{
    auto assign = make<ast::ConcurrentAssign>(ctx);

    if (auto *target_ctx = ctx->target()) {
        assign.target = makeTarget(target_ctx);
    }

    // Get the waveform - for now we'll take the first waveform element's expression
    if (auto *cond_wave = ctx->conditional_waveforms()) {
        if (auto *wave = cond_wave->waveform()) {
            auto wave_elems = wave->waveform_element();
            if (!wave_elems.empty() && !wave_elems[0]->expression().empty()) {
                assign.value = makeExpr(wave_elems[0]->expression(0));
            }
        }
    }

    return assign;
}

auto Translator::makeSelectedAssign(vhdlParser::Selected_signal_assignmentContext *ctx)
  -> ast::ConcurrentAssign
{
    auto assign = make<ast::ConcurrentAssign>(ctx);

    if (auto *target_ctx = ctx->target()) {
        assign.target = makeTarget(target_ctx);
    }

    // For selected assignments (with...select), we'll take the first waveform
    // TODO(someone): Handle full selected waveforms structure
    if (auto *sel_waves = ctx->selected_waveforms()) {
        auto waves = sel_waves->waveform();
        if (!waves.empty()) {
            auto wave_elems = waves[0]->waveform_element();
            if (!wave_elems.empty() && !wave_elems[0]->expression().empty()) {
                assign.value = makeExpr(wave_elems[0]->expression(0));
            }
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
