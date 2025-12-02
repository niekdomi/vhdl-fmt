#include "ast/nodes/expressions.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

#include <memory>
#include <optional>
#include <ranges>
#include <utility>
#include <variant>
#include <vector>

namespace builder {

// ---------------------- Aggregates ----------------------

auto Translator::makeAggregate(vhdlParser::AggregateContext &ctx) -> ast::Expr
{
    return build<ast::GroupExpr>(ctx)
      .collect(&ast::GroupExpr::children,
               ctx.element_association(),
               [&](auto *elem) -> ast::Expr {
                   return build<ast::BinaryExpr>(*elem)
                     .set(&ast::BinaryExpr::op, "=>")
                     .maybeBox(&ast::BinaryExpr::left,
                               elem->choices(),
                               [&](auto &ch) { return makeChoices(ch); })
                     .maybeBox(&ast::BinaryExpr::right,
                               elem->expression(),
                               [&](auto &expr) { return makeExpr(expr); })
                     .build();
               })
      .build();
}

auto Translator::makeChoices(vhdlParser::ChoicesContext &ctx) -> ast::Expr
{
    if (ctx.choice().size() == 1) {
        return makeChoice(*ctx.choice(0));
    }

    return build<ast::GroupExpr>(ctx)
      .collect(
        &ast::GroupExpr::children, ctx.choice(), [this](auto *ch) { return makeChoice(*ch); })
      .build();
}

auto Translator::makeChoice(vhdlParser::ChoiceContext &ctx) -> ast::Expr
{
    if (ctx.OTHERS() != nullptr) {
        return makeToken(ctx, "others");
    }
    if (ctx.identifier() != nullptr) {
        return makeToken(ctx, ctx.identifier()->getText());
    }
    if (ctx.simple_expression() != nullptr) {
        return makeSimpleExpr(*ctx.simple_expression());
    }
    if (auto *dr = ctx.discrete_range()) {
        if (auto *rd = dr->range_decl()) {
            if (auto *er = rd->explicit_range()) {
                return makeRange(*er);
            }
        }
    }
    return makeToken(ctx);
}

// ---------------------- Constraints/Ranges ----------------------

auto Translator::makeConstraint(vhdlParser::ConstraintContext &ctx)
  -> std::optional<ast::Constraint>
{
    // Dispatch based on concrete constraint type
    if (auto *index = ctx.index_constraint()) {
        return makeIndexConstraint(*index);
    }
    if (auto *range = ctx.range_constraint()) {
        return makeRangeConstraint(*range);
    }

    // Fallback: return empty optional
    return std::nullopt;
}

auto Translator::makeIndexConstraint(vhdlParser::Index_constraintContext &ctx)
  -> ast::IndexConstraint
{
    return build<ast::IndexConstraint>(ctx)
      .set(&ast::IndexConstraint::ranges,
           build<ast::GroupExpr>(ctx)
             .collectFiltered(&ast::GroupExpr::children,
                              ctx.discrete_range(),
                              [&](auto &discrete_r) -> std::optional<ast::Expr> {
                                  auto *range_decl = discrete_r.range_decl();
                                  if (range_decl == nullptr) {
                                      return std::nullopt;
                                  }
                                  auto *explicit_r = range_decl->explicit_range();
                                  if (explicit_r == nullptr) {
                                      return std::nullopt;
                                  }
                                  return makeRange(*explicit_r);
                              })
             .build())
      .build();
}

auto Translator::makeRangeConstraint(vhdlParser::Range_constraintContext &ctx)
  -> std::optional<ast::RangeConstraint>
{
    auto *range_decl = ctx.range_decl();
    if (range_decl == nullptr) {
        return std::nullopt;
    }
    auto *explicit_r = range_decl->explicit_range();
    if (explicit_r == nullptr) {
        return std::nullopt;
    }
    auto range_expr = makeRange(*explicit_r);
    auto *bin = std::get_if<ast::BinaryExpr>(&range_expr);
    if (bin == nullptr) {
        return std::nullopt;
    }
    return build<ast::RangeConstraint>(ctx)
      .set(&ast::RangeConstraint::range, std::move(*bin))
      .build();
}

auto Translator::makeRange(vhdlParser::Explicit_rangeContext &ctx) -> ast::Expr
{
    // If there's no direction, it's just a simple expression (single value, not a range)
    if (ctx.direction() == nullptr || ctx.simple_expression().size() < 2) {
        return makeSimpleExpr(*ctx.simple_expression(0));
    }

    return makeBinary(ctx,
                      ctx.direction()->getText(),
                      makeSimpleExpr(*ctx.simple_expression(0)),
                      makeSimpleExpr(*ctx.simple_expression(1)));
}

} // namespace builder
