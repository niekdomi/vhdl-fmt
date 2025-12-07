#include "ast/nodes/expressions.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

#include <ranges>
#include <utility>

namespace builder {

auto Translator::makeExpr(vhdlParser::ExpressionContext &ctx) -> ast::Expr
{
    const auto &relations = ctx.relation();
    if (relations.size() == 1) {
        return makeRelation(*relations[0]);
    }

    return foldBinaryLeft(
      ctx, relations, ctx.logical_operator(), [&](auto &r) { return makeRelation(r); });
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
    const auto &terms = ctx.term();
    const auto &operators = ctx.adding_operator();

    if (terms.empty()) {
        return makeToken(ctx);
    }

    ast::Expr init = makeTerm(*terms[0]);

    // Handle optional leading sign
    if (ctx.PLUS() != nullptr) {
        init = makeUnary(ctx, "+", std::move(init));
    } else if (ctx.MINUS() != nullptr) {
        init = makeUnary(ctx, "-", std::move(init));
    }

    for (const auto &[term, op] : std::views::zip(terms | std::views::drop(1), operators)) {
        init = makeBinary(ctx, op->getText(), std::move(init), makeTerm(*term));
    }

    return init;
}

auto Translator::makeTerm(vhdlParser::TermContext &ctx) -> ast::Expr
{
    const auto &factors = ctx.factor();
    if (factors.empty()) {
        return makeToken(ctx);
    }

    if (factors.size() == 1) {
        return makeFactor(*factors[0]);
    }

    return foldBinaryLeft(
      ctx, factors, ctx.multiplying_operator(), [&](auto &f) { return makeFactor(f); });
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
        return makeToken(ctx);
    }

    auto *phys = num->physical_literal();
    if (phys == nullptr) {
        return makeToken(ctx);
    }

    return build<ast::PhysicalLiteral>(ctx)
      .set(&ast::PhysicalLiteral::value, phys->abstract_literal()->getText())
      .set(&ast::PhysicalLiteral::unit, phys->identifier()->getText())
      .build();
}

auto Translator::makePrimary(vhdlParser::PrimaryContext &ctx) -> ast::Expr
{
    if (ctx.expression() != nullptr) {
        return build<ast::ParenExpr>(ctx)
          .setBox(&ast::ParenExpr::inner, makeExpr(*ctx.expression()))
          .build();
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

    if (auto *qual = ctx.qualified_expression()) {
        return makeQualifiedExpr(*qual);
    }

    if (auto *alloc = ctx.allocator()) {
        return makeAllocator(*alloc);
    }

    return makeToken(ctx);
}

auto Translator::makeQualifiedExpr(vhdlParser::Qualified_expressionContext &ctx) -> ast::Expr
{
    // Build the operand (Aggregate or Parenthesized Expression)
    ast::Expr operand{};

    if (auto *agg = ctx.aggregate()) {
        operand = makeAggregate(*agg);
    } else if (auto *expr = ctx.expression()) {
        operand
          = build<ast::ParenExpr>(*expr).setBox(&ast::ParenExpr::inner, makeExpr(*expr)).build();
    } else {
        // Fallback for invalid parsing
        operand = makeToken(ctx);
    }

    // If missing, return the unwrapped operand.
    auto *subtype = ctx.subtype_indication();
    if (subtype == nullptr) {
        return operand;
    }

    return build<ast::QualifiedExpr>(ctx)
      .set(&ast::QualifiedExpr::type_mark, subtype->getText())
      .setBox(&ast::QualifiedExpr::operand, std::move(operand))
      .build();
}

auto Translator::makeAllocator(vhdlParser::AllocatorContext &ctx) -> ast::Expr
{
    ast::Expr operand{};

    // Determine the operand type (Qualified Expression vs Subtype)
    if (auto *qual = ctx.qualified_expression()) {
        operand = makeQualifiedExpr(*qual);
    } else if (auto *subtype = ctx.subtype_indication()) {
        // "new integer" or "new std_logic_vector(0 to 3)"
        operand = makeToken(*subtype);
    } else {
        // Fallback for safety
        operand = makeToken(ctx);
    }

    return makeUnary(ctx, "new", std::move(operand));
}

} // namespace builder
