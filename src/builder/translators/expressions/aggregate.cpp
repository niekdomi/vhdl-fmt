#include "ast/nodes/expressions.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

namespace builder {

auto Translator::makeAggregate(vhdlParser::AggregateContext &ctx) -> ast::GroupExpr
{
    return build<ast::GroupExpr>(ctx)
      .collect(&ast::GroupExpr::children,
               ctx.element_association(),
               [&](auto *elem) { return makeElementAssociation(*elem); })
      .build();
}

auto Translator::makeElementAssociation(vhdlParser::Element_associationContext &ctx) -> ast::Expr
{
    // element_association: (choices ARROW)? expression
    // If no choices, this is positional notation - return just the expression
    if (ctx.choices() == nullptr) {
        if (auto *expr = ctx.expression()) {
            return makeExpr(*expr);
        }
        return makeToken(ctx);
    }

    // Named association: choices => expression
    return build<ast::BinaryExpr>(ctx)
      .set(&ast::BinaryExpr::op, "=>")
      .maybeBox(
        &ast::BinaryExpr::left, ctx.choices(), [&](auto &child) { return makeChoices(child); })
      .maybeBox(
        &ast::BinaryExpr::right, ctx.expression(), [&](auto &expr) { return makeExpr(expr); })
      .build();
}

auto Translator::makeChoices(vhdlParser::ChoicesContext &ctx) -> ast::Expr
{
    if (ctx.choice().size() == 1) {
        return makeChoice(*ctx.choice(0));
    }

    return build<ast::GroupExpr>(ctx)
      .collect(
        &ast::GroupExpr::children, ctx.choice(), [this](auto *child) { return makeChoice(*child); })
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
        return makeDiscreteRange(*dr);
    }

    return makeToken(ctx);
}

} // namespace builder
