#include "ast/nodes/declarations/objects.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

namespace builder {

auto Translator::makeConstantDecl(vhdlParser::Constant_declarationContext &ctx) -> ast::ConstantDecl
{
    return build<ast::ConstantDecl>(ctx)
      .set(&ast::ConstantDecl::names, extractNames(ctx.identifier_list()))
      .set(&ast::ConstantDecl::subtype, makeSubtypeIndication(*ctx.subtype_indication()))
      .maybe(
        &ast::ConstantDecl::init_expr, ctx.expression(), [&](auto &expr) { return makeExpr(expr); })
      .build();
}

} // namespace builder
