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

auto Translator::makeAggregate(vhdlParser::AggregateContext *ctx) -> ast::Expr
{
    auto group = make<ast::GroupExpr>(ctx);

    for (auto *elem : ctx->element_association()) {
        auto assoc = make<ast::BinaryExpr>(elem);
        assoc.op = "=>";

        if (elem->choices() != nullptr) {
            assoc.left = std::make_unique<ast::Expr>(makeChoices(elem->choices()));
        }
        if (elem->expression() != nullptr) {
            assoc.right = std::make_unique<ast::Expr>(makeExpr(elem->expression()));
        }

        group.children.emplace_back(std::move(assoc));
    }

    return group;
}

auto Translator::makeChoices(vhdlParser::ChoicesContext *ctx) -> ast::Expr
{
    if (ctx->choice().size() == 1) {
        return makeChoice(ctx->choice(0));
    }

    auto grp = make<ast::GroupExpr>(ctx);
    grp.children = ctx->choice()
                 | std::views::transform([this](auto *ch) { return makeChoice(ch); })
                 | std::ranges::to<std::vector>();
    return grp;
}

auto Translator::makeChoice(vhdlParser::ChoiceContext *ctx) -> ast::Expr
{
    if (ctx->OTHERS() != nullptr) {
        return makeToken(ctx, "others");
    }
    if (ctx->identifier() != nullptr) {
        return makeToken(ctx, ctx->identifier()->getText());
    }
    if (ctx->simple_expression() != nullptr) {
        return makeSimpleExpr(ctx->simple_expression());
    }
    if (auto *dr = ctx->discrete_range()) {
        if (auto *rd = dr->range_decl()) {
            if (auto *er = rd->explicit_range()) {
                return makeRange(er);
            }
        }
    }
    return makeToken(ctx, ctx->getText());
}

// ---------------------- Constraints/Ranges ----------------------

auto Translator::makeConstraint(vhdlParser::ConstraintContext *ctx)
  -> std::optional<ast::Constraint>
{
    // Dispatch based on concrete constraint type
    if (auto *index = ctx->index_constraint()) {
        return makeIndexConstraint(index);
    }
    if (auto *range = ctx->range_constraint()) {
        return makeRangeConstraint(range);
    }

    // Fallback: return empty optional
    return std::nullopt;
}

auto Translator::makeIndexConstraint(vhdlParser::Index_constraintContext *ctx)
  -> ast::IndexConstraint
{
    auto constraint = make<ast::IndexConstraint>(ctx);
    auto group = make<ast::GroupExpr>(ctx);

    // Collect all discrete ranges into the group
    for (auto *discrete_r : ctx->discrete_range()) {
        auto *range_decl = discrete_r->range_decl();
        if (range_decl == nullptr) {
            continue;
        }
        auto *explicit_r = range_decl->explicit_range();
        if (explicit_r == nullptr) {
            continue;
        }
        auto range_expr = makeRange(explicit_r);
        group.children.emplace_back(std::move(range_expr));
    }

    constraint.ranges = std::move(group);
    return constraint;
}

auto Translator::makeRangeConstraint(vhdlParser::Range_constraintContext *ctx)
  -> std::optional<ast::RangeConstraint>
{
    auto *range_decl = ctx->range_decl();
    if (range_decl == nullptr) {
        return std::nullopt;
    }
    auto *explicit_r = range_decl->explicit_range();
    if (explicit_r == nullptr) {
        return std::nullopt;
    }
    auto range_expr = makeRange(explicit_r);
    auto *bin = std::get_if<ast::BinaryExpr>(&range_expr);
    if (bin == nullptr) {
        return std::nullopt;
    }
    auto constraint = make<ast::RangeConstraint>(ctx);
    constraint.range = std::move(*bin);
    return constraint;
}

auto Translator::makeRange(vhdlParser::Explicit_rangeContext *ctx) -> ast::Expr
{
    // If there's no direction, it's just a simple expression (single value, not a range)
    if (ctx->direction() == nullptr || ctx->simple_expression().size() < 2) {
        return makeSimpleExpr(ctx->simple_expression(0));
    }

    return makeBinary(ctx,
                      ctx->direction()->getText(),
                      makeSimpleExpr(ctx->simple_expression(0)),
                      makeSimpleExpr(ctx->simple_expression(1)));
}

} // namespace builder
