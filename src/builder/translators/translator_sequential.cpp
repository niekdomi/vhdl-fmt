#include "ast/nodes/expressions.hpp"
#include "ast/nodes/statements.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

#include <utility>
#include <vector>

namespace builder {

auto Translator::makeTarget(vhdlParser::TargetContext &ctx) -> ast::Expr
{
    if (auto *name = ctx.name()) {
        return makeName(*name);
    }

    if (auto *agg = ctx.aggregate()) {
        return makeAggregate(*agg);
    }

    // Fallback: return token with context text
    return makeToken(ctx);
}

auto Translator::makeSignalAssign(vhdlParser::Signal_assignment_statementContext &ctx)
  -> ast::SignalAssign
{
    return build<ast::SignalAssign>(ctx)
      .maybe(&ast::SignalAssign::target, ctx.target(), [&](auto &t) { return makeTarget(t); })
      .maybe(&ast::SignalAssign::waveform, ctx.waveform(), [&](auto &w) { return makeWaveform(w); })
      .build();
}

auto Translator::makeVariableAssign(vhdlParser::Variable_assignment_statementContext &ctx)
  -> ast::VariableAssign
{
    return build<ast::VariableAssign>(ctx)
      .maybe(&ast::VariableAssign::target, ctx.target(), [&](auto &t) { return makeTarget(t); })
      .maybe(
        &ast::VariableAssign::value, ctx.expression(), [&](auto &expr) { return makeExpr(expr); })
      .build();
}

auto Translator::makeSequentialStatement(vhdlParser::Sequential_statementContext &ctx)
  -> ast::SequentialStatement
{
    // Dispatch based on concrete statement type
    if (auto *signal_assign = ctx.signal_assignment_statement()) {
        return makeSignalAssign(*signal_assign);
    }

    if (auto *var_assign = ctx.variable_assignment_statement()) {
        return makeVariableAssign(*var_assign);
    }

    if (auto *if_stmt = ctx.if_statement()) {
        return makeIfStatement(*if_stmt);
    }

    if (auto *case_stmt = ctx.case_statement()) {
        return makeCaseStatement(*case_stmt);
    }

    if (auto *loop_stmt = ctx.loop_statement()) {
        if (auto *iter = loop_stmt->iteration_scheme()) {
            if (iter->parameter_specification() != nullptr) {
                return makeForLoop(*loop_stmt);
            }

            if (iter->condition() != nullptr) {
                return makeWhileLoop(*loop_stmt);
            }
        }
        return makeLoop(*loop_stmt);
    }

    if (ctx.NULL_() != nullptr) {
        return build<ast::NullStatement>(ctx).build();
    }

    // TODO(someone): Add support for wait_statement, assertion_statement,
    // report_statement, next_statement, exit_statement, return_statement, etc.

    return {};
}

auto Translator::makeSequenceOfStatements(vhdlParser::Sequence_of_statementsContext &ctx)
  -> std::vector<ast::SequentialStatement>
{
    std::vector<ast::SequentialStatement> statements{};

    for (auto *stmt : ctx.sequential_statement()) {
        statements.emplace_back(std::move(makeSequentialStatement(*stmt)));
    }

    return statements;
}

} // namespace builder
