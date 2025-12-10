#include "ast/nodes/declarations/interface.hpp"
#include "builder/translator.hpp"
#include "vhdlParser.h"

namespace builder {

auto Translator::makeGenericClause(vhdlParser::Generic_clauseContext &ctx) -> ast::GenericClause
{
    return build<ast::GenericClause>(ctx)
      .collectFrom(
        &ast::GenericClause::generics,
        ctx.generic_list(),
        [](auto &list) { return list.interface_constant_declaration(); },
        [this](auto *decl) { return makeGenericParam(*decl); })
      .build();
}

auto Translator::makeGenericParam(vhdlParser::Interface_constant_declarationContext &ctx)
  -> ast::GenericParam
{
    return build<ast::GenericParam>(ctx)
      .set(&ast::GenericParam::names, extractNames(ctx.identifier_list()))
      .set(&ast::GenericParam::subtype, makeSubtypeIndication(*ctx.subtype_indication()))
      .maybe(&ast::GenericParam::default_expr,
             ctx.expression(),
             [&](auto &expr) { return makeExpr(expr); })
      .build();
}

} // namespace builder
