#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements/sequential.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

namespace builder {

auto Translator::makeSignalAssign(vhdlParser::Signal_assignment_statementContext& ctx)
  -> ast::SignalAssign
{
    return build<ast::SignalAssign>(ctx)
      .maybe(&ast::SignalAssign::target, ctx.target(), [&](auto& t) { return makeTarget(t); })
      .maybe(&ast::SignalAssign::waveform, ctx.waveform(), [&](auto& w) { return makeWaveform(w); })
      .build();
}

auto Translator::makeVariableAssign(vhdlParser::Variable_assignment_statementContext& ctx)
  -> ast::VariableAssign
{
    return build<ast::VariableAssign>(ctx)
      .maybe(&ast::VariableAssign::target, ctx.target(), [&](auto& t) { return makeTarget(t); })
      .maybe(
        &ast::VariableAssign::value, ctx.expression(), [&](auto& expr) { return makeExpr(expr); })
      .build();
}

auto Translator::makeTarget(vhdlParser::TargetContext& ctx) -> ast::Expr
{
    if (auto* name = ctx.name()) {
        return makeName(*name);
    }

    if (auto* agg = ctx.aggregate()) {
        return makeAggregate(*agg);
    }

    // Fallback: return token with context text
    return makeToken(ctx);
}

} // namespace builder
