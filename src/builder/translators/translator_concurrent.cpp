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
    return build<ast::Waveform>(ctx)
      .set(&ast::Waveform::is_unaffected, ctx.UNAFFECTED() != nullptr)
      .with(&ctx,
            [&](auto &node, auto &wave_ctx) {
                if (node.is_unaffected) {
                    return;
                }
                for (auto *el_ctx : wave_ctx.waveform_element()) {
                    ast::Waveform::Element elem;
                    elem.value = makeExpr(*el_ctx->expression(0));
                    if (el_ctx->AFTER() != nullptr) {
                        elem.after = makeExpr(*el_ctx->expression(1));
                    }
                    node.elements.emplace_back(std::move(elem));
                }
            })
      .build();
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
    return build<ast::ConditionalConcurrentAssign>(ctx)
      .maybe(&ast::ConditionalConcurrentAssign::target,
             ctx.target(),
             [&](auto &t) { return makeTarget(t); })
      .with(&ctx,
            [&](auto &node, auto &assign_ctx) {
                // Flatten the recursive conditional waveforms
                auto *current_wave = assign_ctx.conditional_waveforms();
                while (current_wave != nullptr) {
                    ast::ConditionalConcurrentAssign::ConditionalWaveform wave_item;
                    if (auto *w = current_wave->waveform()) {
                        wave_item.waveform = makeWaveform(*w);
                    }
                    if (auto *cond = current_wave->condition()) {
                        wave_item.condition = makeExpr(*cond->expression());
                    }
                    node.waveforms.emplace_back(std::move(wave_item));
                    current_wave = current_wave->conditional_waveforms();
                }
            })
      .build();
}

auto Translator::makeSelectedAssign(vhdlParser::Selected_signal_assignmentContext &ctx)
  -> ast::SelectedConcurrentAssign
{
    return build<ast::SelectedConcurrentAssign>(ctx)
      .maybe(&ast::SelectedConcurrentAssign::selector,
             ctx.expression(),
             [&](auto &expr) { return makeExpr(expr); })
      .maybe(&ast::SelectedConcurrentAssign::target,
             ctx.target(),
             [&](auto &t) { return makeTarget(t); })
      .with(ctx.selected_waveforms(),
            [&](auto &node, auto &sel_waves) {
                const auto waves = sel_waves.waveform();
                const auto choices = sel_waves.choices();

                for (const auto i : std::views::iota(std::size_t{ 0 }, waves.size())) {
                    ast::SelectedConcurrentAssign::Selection selection{};
                    if (waves[i] != nullptr) {
                        selection.waveform = makeWaveform(*waves[i]);
                    }
                    if (i < choices.size()) {
                        if (auto *ch_ctx = choices[i]) {
                            for (auto *c : ch_ctx->choice()) {
                                selection.choices.emplace_back(makeChoice(*c));
                            }
                        }
                    }
                    node.selections.emplace_back(std::move(selection));
                }
            })
      .build();
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
    return build<ast::Process>(ctx)
      .with(ctx.label_colon(),
            [](auto &node, auto &label) {
                if (auto *id = label.identifier()) {
                    node.label = id->getText();
                }
            })
      .collectFrom(
        &ast::Process::sensitivity_list,
        ctx.sensitivity_list(),
        [](auto &sl) { return sl.name(); },
        [](auto *name) { return name->getText(); })
      .maybe(&ast::Process::decls,
             ctx.process_declarative_part(),
             [&](auto &dp) { return makeProcessDeclarativePart(dp); })
      .maybe(&ast::Process::body,
             ctx.process_statement_part(),
             [&](auto &sp) { return makeProcessStatementPart(sp); })
      .build();
}

} // namespace builder
