#include "ast/nodes/expressions.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

#include <ranges>
#include <utility>

namespace builder {

auto Translator::makeExpr(vhdlParser::ExpressionContext& ctx) -> ast::Expr
{
    const auto& relations = ctx.relation();
    if (relations.size() == 1) {
        return makeRelation(*relations.at(0));
    }

    return foldBinaryLeft(
      ctx, relations, ctx.logical_operator(), [&](auto& r) { return makeRelation(r); });
}

auto Translator::makeRelation(vhdlParser::RelationContext& ctx) -> ast::Expr
{
    if (ctx.relational_operator() == nullptr) {
        return makeShiftExpr(*ctx.shift_expression(0));
    }

    return makeBinary(ctx,
                      ctx.relational_operator()->getText(),
                      makeShiftExpr(*ctx.shift_expression(0)),
                      makeShiftExpr(*ctx.shift_expression(1)));
}

auto Translator::makeShiftExpr(vhdlParser::Shift_expressionContext& ctx) -> ast::Expr
{
    if (ctx.shift_operator() == nullptr) {
        return makeSimpleExpr(*ctx.simple_expression(0));
    }

    return makeBinary(ctx,
                      ctx.shift_operator()->getText(),
                      makeSimpleExpr(*ctx.simple_expression(0)),
                      makeSimpleExpr(*ctx.simple_expression(1)));
}

auto Translator::makeSimpleExpr(vhdlParser::Simple_expressionContext& ctx) -> ast::Expr
{
    const auto& terms = ctx.term();
    const auto& operators = ctx.adding_operator();

    if (terms.empty()) {
        return makeToken(ctx);
    }

    ast::Expr init = makeTerm(*terms.at(0));

    // Handle optional leading sign
    if (ctx.PLUS() != nullptr) {
        init = makeUnary(ctx, "+", std::move(init));
    } else if (ctx.MINUS() != nullptr) {
        init = makeUnary(ctx, "-", std::move(init));
    }

    for (const auto [term, op] : std::views::zip(terms | std::views::drop(1), operators)) {
        init = makeBinary(ctx, op->getText(), std::move(init), makeTerm(*term));
    }

    return init;
}

auto Translator::makeTerm(vhdlParser::TermContext& ctx) -> ast::Expr
{
    const auto& factors = ctx.factor();
    if (factors.empty()) {
        return makeToken(ctx);
    }

    if (factors.size() == 1) {
        return makeFactor(*factors.at(0));
    }

    return foldBinaryLeft(
      ctx, factors, ctx.multiplying_operator(), [&](auto& f) { return makeFactor(f); });
}

} // namespace builder
