#include "ast/nodes/statements.hpp"
#include "builder/translator.hpp"
#include "nodes/declarations.hpp"
#include "vhdlParser.h"

#include <optional>
#include <utility>
#include <vector>

namespace builder {

auto Translator::makeWaveformElement(vhdlParser::Waveform_elementContext &ctx)
  -> ast::Waveform::Element
{
    return build<ast::Waveform::Element>(ctx)
      .set(&ast::Waveform::Element::value, makeExpr(*ctx.expression(0)))
      .maybe(&ast::Waveform::Element::after,
             ctx.AFTER(),
             [&](auto &) { return makeExpr(*ctx.expression(1)); })
      .build();
}

auto Translator::makeWaveform(vhdlParser::WaveformContext &ctx) -> ast::Waveform
{
    return build<ast::Waveform>(ctx)
      .set(&ast::Waveform::is_unaffected, ctx.UNAFFECTED() != nullptr)
      .collect(&ast::Waveform::elements,
               (ctx.UNAFFECTED() != nullptr) ? decltype(ctx.waveform_element()){}
                                             : ctx.waveform_element(),
               [&](auto *el) { return makeWaveformElement(*el); })
      .build();
}

auto Translator::makeConcurrentAssign(
  vhdlParser::Concurrent_signal_assignment_statementContext &ctx) -> ast::ConcurrentStatement
{
    if (auto *cond = ctx.conditional_signal_assignment()) {
        return makeConditionalAssign(*cond);
    }
    // Can only be selected assignment here
    return makeSelectedAssign(*ctx.selected_signal_assignment());
}

auto Translator::makeConditionalWaveform(vhdlParser::Conditional_waveformsContext &ctx)
  -> ast::ConditionalConcurrentAssign::ConditionalWaveform
{
    auto *cond = ctx.condition();
    ast::ConditionalConcurrentAssign::ConditionalWaveform result;
    if (auto *w = ctx.waveform()) {
        result.waveform = makeWaveform(*w);
    }
    if (cond != nullptr) {
        result.condition = makeExpr(*cond->expression());
    }
    return result;
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

auto Translator::makeSelection(vhdlParser::WaveformContext *wave,
                               vhdlParser::ChoicesContext *choices)
  -> ast::SelectedConcurrentAssign::Selection
{
    ast::SelectedConcurrentAssign::Selection selection;
    if (wave != nullptr) {
        selection.waveform = makeWaveform(*wave);
    }
    if (choices != nullptr) {
        for (auto *c : choices->choice()) {
            selection.choices.emplace_back(makeChoice(*c));
        }
    }
    return selection;
}

auto Translator::makeSelectedAssign(vhdlParser::Selected_signal_assignmentContext &ctx)
  -> ast::SelectedConcurrentAssign
{
    auto *sel_waves = ctx.selected_waveforms();

    return build<ast::SelectedConcurrentAssign>(ctx)
      .maybe(&ast::SelectedConcurrentAssign::selector,
             ctx.expression(),
             [&](auto &expr) { return makeExpr(expr); })
      .maybe(&ast::SelectedConcurrentAssign::target,
             ctx.target(),
             [&](auto &t) { return makeTarget(t); })
      .collectZipped(
        &ast::SelectedConcurrentAssign::selections,
        (sel_waves != nullptr) ? sel_waves->waveform() : decltype(sel_waves->waveform()){},
        (sel_waves != nullptr) ? sel_waves->choices() : decltype(sel_waves->choices()){},
        [&](auto *wave, auto *choices) { return makeSelection(wave, choices); })
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
    auto *label = ctx.label_colon();
    auto *label_id = (label != nullptr) ? label->identifier() : nullptr;

    return build<ast::Process>(ctx)
      .maybe(&ast::Process::label, label_id, [](auto &id) { return id.getText(); })
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
