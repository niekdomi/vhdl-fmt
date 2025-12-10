#include "ast/nodes/statements.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

#include <ranges>

namespace builder {

auto Translator::makeConcurrentAssignBody(
  vhdlParser::Concurrent_signal_assignment_statementContext &ctx) -> ast::ConcurrentStmtKind
{
    if (auto *cond = ctx.conditional_signal_assignment()) {
        return makeConditionalAssign(*cond);
    }
    if (auto *sel = ctx.selected_signal_assignment()) {
        return makeSelectedAssign(*sel);
    }
    // Should be unreachable
    return ast::ConditionalConcurrentAssign{};
}

auto Translator::makeConditionalAssign(vhdlParser::Conditional_signal_assignmentContext &ctx)
  -> ast::ConditionalConcurrentAssign
{
    return build<ast::ConditionalConcurrentAssign>(ctx)
      .maybe(&ast::ConditionalConcurrentAssign::target,
             ctx.target(),
             [&](auto &t) { return makeTarget(t); })
      .apply([&](auto &node) {
          // Flatten the recursive conditional waveforms
          for (auto *w = ctx.conditional_waveforms(); w != nullptr;
               w = w->conditional_waveforms()) {
              node.waveforms.emplace_back(makeConditionalWaveform(*w));
          }
      })
      .build();
}

auto Translator::makeConditionalWaveform(vhdlParser::Conditional_waveformsContext &ctx)
  -> ast::ConditionalConcurrentAssign::ConditionalWaveform
{
    auto *cond = ctx.condition();

    return build<ast::ConditionalConcurrentAssign::ConditionalWaveform>(ctx)
      .maybe(&ast::ConditionalConcurrentAssign::ConditionalWaveform::waveform,
             ctx.waveform(),
             [this](auto &w) { return makeWaveform(w); })
      .maybe(&ast::ConditionalConcurrentAssign::ConditionalWaveform::condition,
             (cond != nullptr) ? cond->expression() : nullptr,
             [this](auto &expr) { return makeExpr(expr); })
      .build();
}

auto Translator::makeSelectedAssign(vhdlParser::Selected_signal_assignmentContext &ctx)
  -> ast::SelectedConcurrentAssign
{
    return build<ast::SelectedConcurrentAssign>(ctx)
      .maybe(&ast::SelectedConcurrentAssign::selector,
             ctx.expression(),
             [this](auto &expr) { return makeExpr(expr); })
      .maybe(&ast::SelectedConcurrentAssign::target,
             ctx.target(),
             [this](auto &t) { return makeTarget(t); })
      .with(ctx.selected_waveforms(),
            [&](auto &node, auto &sel_waves) {
                for (auto [wave, choice] :
                     std::views::zip(sel_waves.waveform(), sel_waves.choices())) {
                    node.selections.emplace_back(makeSelection(*wave, *choice));
                }
            })
      .build();
}

auto Translator::makeSelection(vhdlParser::WaveformContext &wave,
                               vhdlParser::ChoicesContext &choices)
  -> ast::SelectedConcurrentAssign::Selection
{
    return build<ast::SelectedConcurrentAssign::Selection>(wave)
      .set(&ast::SelectedConcurrentAssign::Selection::waveform, makeWaveform(wave))
      .collect(&ast::SelectedConcurrentAssign::Selection::choices,
               choices.choice(),
               [this](auto *c) { return makeChoice(*c); })
      .build();
}

} // namespace builder
