#include "ast/nodes/statements/sequential.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

namespace builder {

auto Translator::makeCaseStatement(vhdlParser::Case_statementContext& ctx) -> ast::CaseStatement
{
    return build<ast::CaseStatement>(ctx)
      .maybe(&ast::CaseStatement::selector,
             ctx.expression(),
             [this](auto& expr) { return makeExpr(expr); })
      .collect(&ast::CaseStatement::when_clauses,
               ctx.case_statement_alternative(),
               [this](auto* alt) { return makeWhenClause(*alt); })
      .build();
}

auto Translator::makeWhenClause(vhdlParser::Case_statement_alternativeContext& ctx)
  -> ast::CaseStatement::WhenClause
{
    return build<ast::CaseStatement::WhenClause>(ctx)
      .collectFrom(
        &ast::CaseStatement::WhenClause::choices,
        ctx.choices(),
        [](auto& ch) { return ch.choice(); },
        [this](auto* c) { return makeChoice(*c); })
      .collectFrom(
        &ast::CaseStatement::WhenClause::body,
        ctx.sequence_of_statements(),
        [](auto& sp) { return sp.sequential_statement(); },
        [this](auto* stmt) { return makeSequentialStatement(*stmt); })
      .build();
}

} // namespace builder
