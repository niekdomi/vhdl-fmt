#include "ast/nodes/statements.hpp"
#include "builder/translator.hpp"
#include "nodes/declarations.hpp"
#include "vhdlParser.h"

#include <ranges>

namespace builder {

auto Translator::makeWaveformElement(vhdlParser::Waveform_elementContext &ctx)
  -> ast::Waveform::Element
{
    return build<ast::Waveform::Element>(ctx)
      .maybe(&ast::Waveform::Element::value,
             ctx.expression(0),
             [this](auto &expr) { return makeExpr(expr); })
      .maybe(&ast::Waveform::Element::after,
             ctx.expression(1),
             [this](auto &expr) { return makeExpr(expr); })
      .build();
}

auto Translator::makeWaveform(vhdlParser::WaveformContext &ctx) -> ast::Waveform
{
    return build<ast::Waveform>(ctx)
      .set(&ast::Waveform::is_unaffected, ctx.UNAFFECTED() != nullptr)
      .collect(&ast::Waveform::elements,
               ctx.waveform_element(),
               [this](auto *el) { return makeWaveformElement(*el); })
      .build();
}

auto Translator::makeConcurrentAssign(
  vhdlParser::Concurrent_signal_assignment_statementContext &ctx) -> ast::ConcurrentStatement
{
    if (auto *cond = ctx.conditional_signal_assignment()) {
        return makeConditionalAssign(*cond);
    }

    if (auto *sel = ctx.selected_signal_assignment()) {
        return makeSelectedAssign(*sel);
    }

    return {};
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

auto Translator::makeProcessDeclarativeItem(vhdlParser::Process_declarative_itemContext &ctx)
  -> ast::Declaration
{
    if (auto *var_ctx = ctx.variable_declaration()) {
        return makeVariableDecl(*var_ctx);
    }

    if (auto *const_ctx = ctx.constant_declaration()) {
        return makeConstantDecl(*const_ctx);
    }

    if (auto *type_ctx = ctx.type_declaration()) {
        // TODO(vedivad): Implement makeTypeDecl
        // return makeTypeDecl(*type_ctx);
    }

    if (auto *file_ctx = ctx.file_declaration()) {
        // TODO(vedivad): Implement makeFileDecl
        // return makeFileDecl(*file_ctx);
    }

    if (auto *alias_ctx = ctx.alias_declaration()) {
        // TODO(vedivad): Implement makeAliasDecl
        // return makeAliasDecl(*alias_ctx);
    }

    return {};
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
      .collectFrom(
        &ast::Process::decls,
        ctx.process_declarative_part(),
        [](auto &dp) { return dp.process_declarative_item(); },
        [this](auto *item) { return makeProcessDeclarativeItem(*item); })
      .collectFrom(
        &ast::Process::body,
        ctx.process_statement_part(),
        [](auto &part) { return part.sequential_statement(); },
        [this](auto *stmt) { return makeSequentialStatement(*stmt); })
      .build();
}

} // namespace builder
