#include "ast/nodes/statements.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

#include <ranges>

namespace builder {

auto Translator::makeConcurrentAssign(
  vhdlParser::Concurrent_signal_assignment_statementContext *ctx) -> ast::ConcurrentAssign
{
    if (ctx == nullptr) {
        return {};
    }

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
    if (ctx == nullptr) {
        return {};
    }

    auto assign = make<ast::ConcurrentAssign>(ctx);

    if (auto *target_ctx = ctx->target()) {
        assign.target = makeTarget(target_ctx);
    }

    auto *cond_wave = ctx->conditional_waveforms();
    if (cond_wave == nullptr) {
        assign.value = makeToken(ctx, ctx->getText());
        return assign;
    }

    bool value_set = false;

    for (auto *current = cond_wave; current != nullptr;
         current = current->conditional_waveforms()) {
        auto *wave = current->waveform();
        if (wave == nullptr) {
            continue;
        }

        const auto elems = wave->waveform_element();
        if (elems.empty() || elems[0]->expression().empty()) {
            continue;
        }

        ast::ConditionalWaveform waveform{};
        waveform.value = makeExpr(elems[0]->expression(0));

        if (!value_set) {
            assign.value = makeExpr(elems[0]->expression(0));
            value_set = true;
        }

        if (auto *cond_ctx = current->condition()) {
            if (auto *expr_ctx = cond_ctx->expression()) {
                waveform.condition = makeExpr(expr_ctx);
            }
        }

        assign.conditional_waveforms.push_back(std::move(waveform));
    }

    if (!value_set) {
        assign.value = makeToken(ctx, ctx->getText());
    }

    return assign;
}

auto Translator::makeSelectedAssign(vhdlParser::Selected_signal_assignmentContext *ctx)
  -> ast::ConcurrentAssign
{
    if (ctx == nullptr) {
        return {};
    }

    auto assign = make<ast::ConcurrentAssign>(ctx);

    if (auto *target_ctx = ctx->target()) {
        assign.target = makeTarget(target_ctx);
    }

    if (auto *selector = ctx->expression()) {
        assign.select = makeExpr(selector);
    }

    auto *sel_waves = ctx->selected_waveforms();
    if (sel_waves == nullptr) {
        assign.value = makeToken(ctx, ctx->getText());
        return assign;
    }

    const auto waves = sel_waves->waveform();
    const auto choices = sel_waves->choices();
    const auto count = std::min(waves.size(), choices.size());

    bool value_set = false;

    for (std::size_t i = 0; i < count; ++i) {
        if (waves[i] == nullptr) {
            continue;
        }
        const auto elems = waves[i]->waveform_element();
        if (elems.empty() || elems[0]->expression().empty()) {
            continue;
        }

        ast::SelectedWaveform waveform{};
        waveform.value = makeExpr(elems[0]->expression(0));

        if (!value_set) {
            assign.value = makeExpr(elems[0]->expression(0));
            value_set = true;
        }

        waveform.choices = choices[i]->choice()
                         | std::views::transform([this](auto *ch) { return makeChoice(ch); })
                         | std::ranges::to<std::vector>();

        assign.selected_waveforms.push_back(std::move(waveform));
    }

    if (!value_set) {
        assign.value = makeToken(ctx, ctx->getText());
    }

    return assign;
}

auto Translator::makeProcess(vhdlParser::Process_statementContext *ctx) -> ast::Process
{
    if (ctx == nullptr) {
        return {};
    }

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
        proc.body
          = stmt_part->sequential_statement()
          | std::views::transform([this](auto *stmt) { return makeSequentialStatement(stmt); })
          | std::ranges::to<std::vector>();
    }

    return proc;
}

} // namespace builder
