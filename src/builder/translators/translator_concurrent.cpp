#include "ast/nodes/statements.hpp"
#include "builder/translator.hpp"
#include "nodes/declarations.hpp"
#include "vhdlParser.h"

#include <cstddef>
#include <ranges>
#include <utility>
#include <vector>

namespace builder {

auto Translator::makeWaveform(vhdlParser::WaveformContext &ctx) -> ast::Waveform
{
    auto waveform = make<ast::Waveform>(ctx);

    // Handle 'UNAFFECTED' keyword
    if (ctx.UNAFFECTED() != nullptr) {
        waveform.is_unaffected = true;
        return waveform;
    }

    // Handle list: waveform_element (COMMA waveform_element)*
    if (!ctx.waveform_element().empty()) {
        for (auto *el_ctx : ctx.waveform_element()) {
            ast::Waveform::Element elem;

            // 1. The Value
            // Note: expression(0) is the value, expression(1) is the time (if AFTER exists)
            elem.value = makeExpr(*el_ctx->expression(0));

            // 2. The Optional Delay (AFTER expression)
            if (el_ctx->AFTER() != nullptr) {
                elem.after = makeExpr(*el_ctx->expression(1));
            }

            waveform.elements.emplace_back(std::move(elem));
        }
    }

    return waveform;
}

auto Translator::makeConcurrentAssign(
  vhdlParser::Concurrent_signal_assignment_statementContext &ctx) -> ast::ConcurrentStatement
{
    // Dispatch based on concrete assignment type
    if (auto *cond = ctx.conditional_signal_assignment()) {
        return makeConditionalAssign(*cond);
    }

    // Can only be Selected assignment here
    auto *sel = ctx.selected_signal_assignment();
    return makeSelectedAssign(*sel);
}

auto Translator::makeConditionalAssign(vhdlParser::Conditional_signal_assignmentContext &ctx)
  -> ast::ConditionalConcurrentAssign
{
    auto assign = make<ast::ConditionalConcurrentAssign>(ctx);

    if (auto *target_ctx = ctx.target()) {
        assign.target = makeTarget(*target_ctx);
    }

    // Flatten the recursive conditional waveforms:
    // val1 when cond1 else val2 when cond2 else val3
    auto *current_wave = ctx.conditional_waveforms();
    while (current_wave != nullptr) {
        ast::ConditionalConcurrentAssign::ConditionalWaveform wave_item;

        // 1. Waveform (Value + Delay or UNAFFECTED)
        if (auto *w = current_wave->waveform()) {
            wave_item.waveform = makeWaveform(*w);
        }

        // 2. Condition (WHEN ...)
        if (auto *cond = current_wave->condition()) {
            wave_item.condition = makeExpr(*cond->expression());
        }

        assign.waveforms.emplace_back(std::move(wave_item));

        // 3. Recurse (ELSE ...)
        current_wave = current_wave->conditional_waveforms();
    }

    return assign;
}

auto Translator::makeSelectedAssign(vhdlParser::Selected_signal_assignmentContext &ctx)
  -> ast::SelectedConcurrentAssign
{
    auto assign = make<ast::SelectedConcurrentAssign>(ctx);

    // WITH expression ...
    if (auto *expr = ctx.expression()) {
        assign.selector = makeExpr(*expr);
    }

    if (auto *target_ctx = ctx.target()) {
        assign.target = makeTarget(*target_ctx);
    }

    // ... SELECT target <= opts waveforms
    if (auto *sel_waves = ctx.selected_waveforms()) {
        const auto waves = sel_waves->waveform();
        const auto choices = sel_waves->choices();

        for (const auto i : std::views::iota(std::size_t{ 0 }, waves.size())) {
            ast::SelectedConcurrentAssign::Selection selection{};

            // Value
            if (waves[i] != nullptr) {
                selection.waveform = makeWaveform(*waves[i]);
            }

            // Choices (1 | 2 | others)
            if (i < choices.size()) {
                if (auto *ch_ctx = choices[i]) {
                    for (auto *c : ch_ctx->choice()) {
                        selection.choices.emplace_back(makeChoice(*c));
                    }
                }
            }

            assign.selections.emplace_back(std::move(selection));
        }
    }

    return assign;
}

auto Translator::makeProcessDeclarativePart(vhdlParser::Process_declarative_partContext &ctx)
  -> std::vector<ast::Declaration>
{
    std::vector<ast::Declaration> decls{};

    for (auto *item : ctx.process_declarative_item()) {
        if (auto *var_ctx = item->variable_declaration()) {
            decls.emplace_back(makeVariableDecl(*var_ctx));
        } else if (auto *const_ctx = item->constant_declaration()) {
            decls.emplace_back(makeConstantDecl(*const_ctx));
        }
        // TODO(vedivad): Add Types, Files, Aliases here
    }

    return decls;
}

auto Translator::makeProcessStatementPart(vhdlParser::Process_statement_partContext &ctx)
  -> std::vector<ast::SequentialStatement>
{
    std::vector<ast::SequentialStatement> stmts{};
    const auto &source_stmts = ctx.sequential_statement();
    stmts.reserve(source_stmts.size());

    for (auto *stmt_ctx : source_stmts) {
        if (auto stmt = makeSequentialStatement(*stmt_ctx)) {
            stmts.emplace_back(std::move(*stmt));
        }
    }

    return stmts;
}

auto Translator::makeProcess(vhdlParser::Process_statementContext &ctx) -> ast::Process
{
    auto proc = make<ast::Process>(ctx);

    // Extract label if present
    if (auto *label = ctx.label_colon(); label != nullptr && label->identifier() != nullptr) {
        proc.label = label->identifier()->getText();
    }

    // Extract sensitivity list
    if (auto *sens_list = ctx.sensitivity_list()) {
        proc.sensitivity_list = sens_list->name()
                              | std::views::transform([](auto *name) { return name->getText(); })
                              | std::ranges::to<std::vector>();
    }

    if (auto *decl_part = ctx.process_declarative_part()) {
        proc.decls = makeProcessDeclarativePart(*decl_part);
    }

    if (auto *stmt_part = ctx.process_statement_part()) {
        proc.body = makeProcessStatementPart(*stmt_part);
    }

    return proc;
}

} // namespace builder
