#include "ast/nodes/statements/sequential.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

namespace builder {

auto Translator::makeLoop(vhdlParser::Loop_statementContext &ctx) -> ast::Loop
{
    return build<ast::Loop>(ctx)
      .maybe(&ast::Loop::body,
             ctx.sequence_of_statements(),
             [this](auto &seq) { return makeSequenceOfStatements(seq); })
      .build();
}

auto Translator::makeForLoop(vhdlParser::Loop_statementContext &ctx) -> ast::ForLoop
{
    auto *iter = ctx.iteration_scheme();
    auto *param = (iter != nullptr) ? iter->parameter_specification() : nullptr;

    return build<ast::ForLoop>(ctx)
      .maybe(&ast::ForLoop::iterator,
             (param != nullptr) ? param->identifier() : nullptr,
             [](auto &id) { return id.getText(); })
      .maybe(&ast::ForLoop::range,
             (param != nullptr) ? param->discrete_range() : nullptr,
             [this](auto &dr) { return makeDiscreteRange(dr); })
      .maybe(&ast::ForLoop::body,
             ctx.sequence_of_statements(),
             [this](auto &seq) { return makeSequenceOfStatements(seq); })
      .build();
}

auto Translator::makeWhileLoop(vhdlParser::Loop_statementContext &ctx) -> ast::WhileLoop
{
    auto *iter = ctx.iteration_scheme();
    auto *cond = (iter != nullptr) ? iter->condition() : nullptr;

    return build<ast::WhileLoop>(ctx)
      .maybe(&ast::WhileLoop::condition,
             (cond != nullptr) ? cond->expression() : nullptr,
             [this](auto &expr) { return makeExpr(expr); })
      .maybe(&ast::WhileLoop::body,
             ctx.sequence_of_statements(),
             [this](auto &seq) { return makeSequenceOfStatements(seq); })
      .build();
}

} // namespace builder
