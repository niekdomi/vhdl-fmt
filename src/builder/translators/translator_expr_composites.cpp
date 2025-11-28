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
    if (ctx == nullptr) {
        return {};
    }

    auto group = make<ast::GroupExpr>(ctx);

    auto make_association = [this](auto *elem) -> ast::Expr {
        if (auto *choices = elem->choices()) {
            auto assoc = make<ast::BinaryExpr>(elem);
            assoc.op = "=>";
            assoc.left = std::make_unique<ast::Expr>(makeChoices(choices));

            if (auto *expr = elem->expression()) {
                assoc.right = std::make_unique<ast::Expr>(makeExpr(expr));
            }

            return ast::Expr{ std::move(assoc) };
        }

        if (auto *expr = elem->expression()) {
            return makeExpr(expr);
        }

        return makeToken(elem, elem->getText());
    };

    group.children = ctx->element_association()
                   | std::views::transform(make_association)
                   | std::ranges::to<std::vector>();

    return group;
}

auto Translator::makeChoices(vhdlParser::ChoicesContext *ctx) -> ast::Expr
{
    if (ctx == nullptr) {
        return {};
    }

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
    if (ctx == nullptr) {
        return {};
    }

    // Handle OTHERS keyword
    if (ctx->OTHERS() != nullptr) {
        return makeToken(ctx, "others");
    }

    // Handle identifier
    if (auto *id = ctx->identifier()) {
        return makeToken(ctx, id->getText());
    }

    // Handle simple expression
    if (auto *simple_expr = ctx->simple_expression()) {
        return makeSimpleExpr(simple_expr);
    }

    // Handle range
    auto *discrete = ctx->discrete_range();
    if (discrete == nullptr) {
        return makeToken(ctx, ctx->getText());
    }

    auto *range_decl = discrete->range_decl();
    if (range_decl == nullptr) {
        return makeToken(ctx, ctx->getText());
    }

    if (auto *explicit_r = range_decl->explicit_range()) {
        return makeRange(explicit_r);
    }

    // Fallback to raw text
    return makeToken(ctx, ctx->getText());
}

// ---------------------- Constraints/Ranges ----------------------

auto Translator::makeConstraint(vhdlParser::ConstraintContext *ctx)
  -> std::optional<ast::Constraint>
{
    if (ctx == nullptr) {
        return std::nullopt;
    }

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
    if (ctx == nullptr) {
        return {};
    }

    auto constraint = make<ast::IndexConstraint>(ctx);
    auto group = make<ast::GroupExpr>(ctx);

    // Extract ranges from discrete_range contexts
    auto extract_range = [this](auto *discrete) -> std::optional<ast::Expr> {
        auto *range_decl = discrete->range_decl();
        if (!range_decl) {
            return std::nullopt;
        }

        auto *explicit_r = range_decl->explicit_range();
        if (explicit_r == nullptr) {
            return std::nullopt;
        }

        return makeRange(explicit_r);
    };

    for (auto *discrete : ctx->discrete_range()) {
        if (auto range = extract_range(discrete)) {
            group.children.push_back(std::move(*range));
        }
    }

    constraint.ranges = std::move(group);
    return constraint;
}

auto Translator::makeRangeConstraint(vhdlParser::Range_constraintContext *ctx)
  -> std::optional<ast::RangeConstraint>
{
    if (ctx == nullptr) {
        return std::nullopt;
    }

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
    if (ctx == nullptr) {
        return {};
    }

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
