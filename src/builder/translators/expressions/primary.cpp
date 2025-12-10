#include "ast/nodes/expressions.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

namespace builder {

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

} // namespace builder
