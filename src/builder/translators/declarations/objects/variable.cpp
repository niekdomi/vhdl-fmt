#include "ast/nodes/declarations/objects.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

namespace builder {

auto Translator::makeVariableDecl(vhdlParser::Variable_declarationContext &ctx) -> ast::VariableDecl
{
    return build<ast::VariableDecl>(ctx)
      .set(&ast::VariableDecl::shared, ctx.SHARED() != nullptr)
      .set(&ast::VariableDecl::names, extractNames(ctx.identifier_list()))
      .set(&ast::VariableDecl::subtype, makeSubtypeIndication(*ctx.subtype_indication()))
      .maybe(
        &ast::VariableDecl::init_expr, ctx.expression(), [&](auto &expr) { return makeExpr(expr); })
      .build();
}

} // namespace builder
