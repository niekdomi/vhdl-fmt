#include "ast/nodes/expressions.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

#include <algorithm>
#include <memory>
#include <ranges>
#include <utility>

namespace builder {

auto Translator::makeExpr(vhdlParser::ExpressionContext &ctx) -> ast::Expr
{
    const auto relations = ctx.relation();
    const auto operators = ctx.logical_operator();

    if (relations.size() == 1) {
        return makeRelation(*relations[0]);
    }

    return std::ranges::fold_left(std::views::iota(size_t{ 0 }, operators.size()),
                                  makeRelation(*relations[0]),
                                  [&](ast::Expr acc, size_t i) -> ast::Expr {
                                      return makeBinary(ctx,
                                                        operators[i]->getText(),
                                                        std::move(acc),
                                                        makeRelation(*relations[i + 1]));
                                  });
}

auto Translator::makeRelation(vhdlParser::RelationContext &ctx) -> ast::Expr
{
    if (ctx.relational_operator() == nullptr) {
        return makeShiftExpr(*ctx.shift_expression(0));
    }
    return makeBinary(ctx,
                      ctx.relational_operator()->getText(),
                      makeShiftExpr(*ctx.shift_expression(0)),
                      makeShiftExpr(*ctx.shift_expression(1)));
}

auto Translator::makeShiftExpr(vhdlParser::Shift_expressionContext &ctx) -> ast::Expr
{
    if (ctx.shift_operator() == nullptr) {
        return makeSimpleExpr(*ctx.simple_expression(0));
    }
    return makeBinary(ctx,
                      ctx.shift_operator()->getText(),
                      makeSimpleExpr(*ctx.simple_expression(0)),
                      makeSimpleExpr(*ctx.simple_expression(1)));
}

auto Translator::makeSimpleExpr(vhdlParser::Simple_expressionContext &ctx) -> ast::Expr
{
    const auto terms = ctx.term();
    const auto operators = ctx.adding_operator();

    if (terms.empty()) {
        return makeToken(ctx, ctx.getText());
    }

    ast::Expr init = makeTerm(*terms[0]);

    // Handle optional leading sign
    if (ctx.PLUS() != nullptr) {
        init = makeUnary(ctx, "+", std::move(init));
    } else if (ctx.MINUS() != nullptr) {
        init = makeUnary(ctx, "-", std::move(init));
    }

    return std::ranges::fold_left(
      std::views::iota(size_t{ 0 }, operators.size()),
      std::move(init),
      [&](ast::Expr acc, size_t i) -> ast::Expr {
          return makeBinary(ctx, operators[i]->getText(), std::move(acc), makeTerm(*terms[i + 1]));
      });
}

auto Translator::makeTerm(vhdlParser::TermContext &ctx) -> ast::Expr
{
    const auto factors = ctx.factor();
    const auto operators = ctx.multiplying_operator();

    if (factors.empty()) {
        return makeToken(ctx, ctx.getText());
    }

    return std::ranges::fold_left(std::views::iota(size_t{ 0 }, operators.size()),
                                  makeFactor(*factors[0]),
                                  [&](ast::Expr acc, size_t i) -> ast::Expr {
                                      return makeBinary(ctx,
                                                        operators[i]->getText(),
                                                        std::move(acc),
                                                        makeFactor(*factors[i + 1]));
                                  });
}

auto Translator::makeFactor(vhdlParser::FactorContext &ctx) -> ast::Expr
{
    if (ctx.DOUBLESTAR() != nullptr) {
        return makeBinary(ctx, "**", makePrimary(*ctx.primary(0)), makePrimary(*ctx.primary(1)));
    }
    if (ctx.ABS() != nullptr) {
        return makeUnary(ctx, "abs", makePrimary(*ctx.primary(0)));
    }
    if (ctx.NOT() != nullptr) {
        return makeUnary(ctx, "not", makePrimary(*ctx.primary(0)));
    }
    return makePrimary(*ctx.primary(0));
}

auto Translator::makeLiteral(vhdlParser::LiteralContext &ctx) -> ast::Expr
{
    auto *num = ctx.numeric_literal();
    if (num == nullptr) {
        return makeToken(ctx, ctx.getText());
    }

    auto *phys = num->physical_literal();
    if (phys == nullptr) {
        return makeToken(ctx, ctx.getText());
    }

    auto phys_node = make<ast::PhysicalLiteral>(ctx);
    phys_node.value = phys->abstract_literal()->getText();
    phys_node.unit = phys->identifier()->getText();
    return phys_node;
}

auto Translator::makePrimary(vhdlParser::PrimaryContext &ctx) -> ast::Expr
{
    if (ctx.expression() != nullptr) {
        auto paren = make<ast::ParenExpr>(ctx);
        paren.inner = std::make_unique<ast::Expr>(makeExpr(*ctx.expression()));
        return paren;
    }
    if (ctx.aggregate() != nullptr) {
        return makeAggregate(*ctx.aggregate());
    }
    if (auto *name_ctx = ctx.name()) {
        return makeName(*name_ctx);
    }
    if (auto *lit = ctx.literal()) {
        return makeLiteral(*lit);
    }
    return makeToken(ctx, ctx.getText());
}

} // namespace builder
